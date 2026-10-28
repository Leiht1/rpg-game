extends RefCounted
## Persisted with the original item transaction. Network clients only send intent.
const Rules=preload("res://scripts/combat_rules.gd")
var service: Node
var rules: Dictionary=Rules.load_rules()
static func initial_world() -> Dictionary:return {"version":1,"relics":{},"boars":{},"population_initialized":false,"spawn":{},"duels":{}}
static func initial_personal() -> Dictionary:return {"phase":"alive","clock":0.0,"attack":{},"serial":0,"entry":{},"hit_serial":0}
var state: Dictionary=initial_world()
var personal: Dictionary=initial_personal()
var busy:=false
var peers: Array=[] # Authenticated server projection, never populated by client arguments.
var damage_events: Array=[]
var attack_preview: Dictionary={}
var attack_preview_started:=0
var attack_preview_confirmed:=false

# Immediate local pose only. Damage, stamina and inventory remain authoritative.
func attack_state() -> Dictionary:
	if attack_preview.is_empty():return personal.attack
	if personal.phase!="alive" or service.body.down or service.body.sleep_active() or int(personal.get("hit_serial",0))!=int(attack_preview.hit_serial) or (attack_preview_confirmed and personal.attack.is_empty()):
		attack_preview={};return personal.attack
	var elapsed:=maxf(0,(Time.get_ticks_msec()-attack_preview_started)/1000.0)
	var spec: Dictionary=attack_preview.weapon
	var duration: float=spec.windup+spec.active+spec.recovery
	# Keep movement fenced until rejection or authoritative completion.
	# Pending confirmation must not unlock and then relock the same attack.
	var result: Dictionary=(personal.attack if not personal.attack.is_empty() else attack_preview).duplicate(true)
	result.elapsed=minf(duration,maxf(elapsed,float(result.get("elapsed",0))))
	return result

func confirm_attack_preview(accepted: bool) -> void:
	if not accepted:attack_preview={}
	attack_preview_confirmed=accepted

func begin_attack_preview(direction: Vector2) -> void:
	attack_preview={"elapsed":0.0,"direction":{"x":direction.normalized().x,"y":direction.normalized().y},"weapon":weapon().duplicate(true),"targets":{},"hit_serial":int(personal.get("hit_serial",0))}
	attack_preview_started=Time.get_ticks_msec();attack_preview_confirmed=false

func duel(_target: String, _accept: bool) -> String:
	return "切磋功能已移除"

func duel_allowed(target: String) -> bool:
	var pair: Array=[str(service.world.get_meta("network_player_id","local")),target];pair.sort()
	return bool(state.get("duels",{}).get(":".join(pair),{}).get("accepted",false))

func serialize() -> Dictionary:return state.duplicate(true)
func valid(value: Variant, individual: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not value.get("relics") is Dictionary or not value.get("boars") is Dictionary:return false
	if not individual is Dictionary or individual.get("phase") not in ["alive","dying","entering"]:return false
	if not individual.get("clock") is float and not individual.get("clock") is int:return false
	if not is_finite(float(individual.clock)) or individual.clock<0:return false
	for key in ["attack","entry"]:
		if not individual.get(key) is Dictionary:return false
	for key in ["serial","hit_serial"]:
		if not number(individual.get(key),0,1000000000) or individual[key]!=floor(individual[key]):return false
	if not value.get("population_initialized") is bool or not value.get("spawn",{}) is Dictionary or not value.get("duels",{}) is Dictionary:return false
	if not value.get("spawn",{}).is_empty() and not point_valid(value.spawn):return false
	var attack_value: Dictionary=individual.attack
	if not attack_value.is_empty():
		if not attack_value.get("weapon") is Dictionary or not attack_value.get("direction") is Dictionary or not attack_value.get("targets") is Dictionary:return false
		if not number(attack_value.get("elapsed"),0,5):return false
		for key in ["x","y"]:
			if not number(attack_value.direction.get(key),-1,1):return false
		if not rules.weapons.values().any(func(w):return JSON.stringify(w)==JSON.stringify(attack_value.weapon)):return false
	for row in value.boars.values():
		if not row is Dictionary or not point_valid(row):return false
		if not number(row.get("home_x"),0,service.world.generator.extent) or not number(row.get("home_y"),0,service.world.generator.extent):return false
		if not number(row.get("health"),0,rules.boar.health) or not number(row.get("clock"),0,1000000000) or not number(row.get("hit"),0,6):return false
		if row.get("mode") not in ["patrol","alert","chase","return","attack","hurt","dead"]:return false
		if row.health<=0 and not number(row.get("respawn"),0,rules.boar.respawn_seconds):return false
	for row in value.relics.values():
		if not row is Dictionary or not row.get("contents") is Array:return false
		if not row.get("owner") is String or row.contents.size()>40:return false
		if not point_valid(row):return false
		for item in row.contents:
			var inv:=ItemInventory.new(service.database)
			var slots: Array=[]
			for i in 40:slots.append(item if i==0 else {})
			if not inv.restore(slots):return false
	return true

func number(n: Variant, lower: float, upper: float) -> bool:
	return (n is int or n is float) and is_finite(float(n)) and n>=lower and n<=upper

func point_valid(row: Dictionary) -> bool:
	for k in ["x","y"]:
		if not (row.get(k) is float or row.get(k) is int) or not is_finite(float(row[k])) or row[k]<0 or row[k]>service.world.generator.extent:return false
	return true

func weapon() -> Dictionary:
	var held: Dictionary=service.inventory.equipment.get("main_hand",{})
	if held.is_empty():return rules.weapons.unarmed
	return rules.weapons.get(service.database.item(str(held.item_id)).get("combat_weapon",""),{})

func attack(direction: Vector2) -> String:
	if not personal.attack.is_empty() or not attack_preview.is_empty():return ""
	if busy or personal.phase!="alive" or not personal.attack.is_empty() or service.body.down or service.body.health<=0 or service.body.sleep_active() or service.body.energy<=0 or not service.craft_job.is_empty():return "当前无法攻击"
	if not direction.is_finite() or direction.length_squared()<.01:return "方向无效"
	var spec:=weapon()
	if spec.is_empty():return "采集工具不能攻击"
	if service.body.stamina<float(spec.stamina):return "体力不足"
	if preload("res://scripts/network_game_route.gd").send(self,"combat_attack",[direction]):
		return ""
	var old:=personal.duplicate(true);var stamina: float=service.body.stamina
	personal.attack={"elapsed":0.0,"direction":{"x":direction.normalized().x,"y":direction.normalized().y},"weapon":spec.duplicate(true),"targets":{}}
	personal.attack.held=service.inventory.equipment.get("main_hand",{}).get("instance_id","")
	service.body.stamina-=float(spec.stamina);service.body.rest_clock=0
	if not service.save_state():personal=old;service.body.stamina=stamina;return "存档失败"
	return ""

func damage(amount: float, source: Vector2, duel: bool=false) -> bool:
	if personal.phase!="alive" or service.body.health<=0 or busy:return false
	var result:=Rules.damage_result(service.body.health,amount,duel,float(rules.duel_health_floor))
	if not result.accepted:return false
	var old: Dictionary=service.body.serialize();var previous:=personal.duplicate(true)
	var old_position: Vector2=service.world.player.position
	service.body.health=result.health;personal.hit_serial=int(personal.get("hit_serial",0))+1
	personal.attack={}
	personal.hit_source={"x":source.x,"y":source.y}
	if result.lethal:
		if not die():service.body.restore(old);personal=previous;return false
	else:
		var next: Vector2=old_position+(old_position-source).normalized()*float(rules.get("knockback",12))
		if service.world.generator.can_walk(next) and service.world.stream.clear_reach(old_position,next,null):service.world.player.position=next
		if not service.save_state():service.body.restore(old);personal=previous;service.world.player.position=old_position;return false
	service.body.changed.emit()
	service.world.player.cancel_action()
	return true

func die() -> bool:
	if personal.phase!="alive" or busy:return false
	busy=true
	var slots: Array[Dictionary]=service.inventory.slots.duplicate(true)
	var previous:=personal.duplicate(true)
	var previous_body: Dictionary=service.body.serialize()
	var previous_buildings: Dictionary=service.builds.states.duplicate(true)
	var sleep_row: Dictionary={}
	if not service.body.sleep_session.is_empty():
		var bed_id:=str(service.body.sleep_session.id)
		sleep_row=service.builds.states.get(bed_id,{})
		if not sleep_row.is_empty():
			if sleep_row.kind=="sleeping_bag" and sleep_row.get("sleep_state")=="IN_USE":service.builds.states.erase(bed_id)
			else:sleep_row.sleep_state="PLACED";sleep_row.erase("network_sleep_owner")
	service.body.sleep_session={};service.body.sleeping=false;service.body.sleep_forced=false
	var contents: Array=[]
	for i in 40:
		var value: Dictionary=service.inventory.slots[i]
		if not value.is_empty() and Rules.transfers_on_death(service.database.item(str(value.item_id))):
			contents.append(value.duplicate(true));service.inventory.slots[i]={}
	var id:=Crypto.new().generate_random_bytes(16).hex_encode()
	var at: Vector2=service.world.player.position
	state.relics[id]={"x":at.x,"y":at.y,"owner":str(service.world.get_meta("network_player_id","local")),"contents":contents}
	personal.phase="dying";personal.clock=0.0;personal.attack={};personal.serial=int(personal.serial)+1
	service.body.down=true
	if not service.save_state():
		service.inventory.slots=slots;state.relics.erase(id);personal=previous;service.body.restore(previous_body);service.builds.states=previous_buildings;busy=false;return false
	if not sleep_row.is_empty():service.builds.refresh_around(sleep_row)
	if is_instance_valid(service.sleep.symbols):service.sleep.symbols.hide()
	service.world.player.cancel_action();service.cancel_craft();service.inventory.changed.emit()
	busy=false
	return true

func claim(id: String, index: int, expected: Dictionary) -> String:
	if preload("res://scripts/network_game_route.gd").send(self,"relic_claim",[id,index,expected]):return ""
	if busy or personal.phase!="alive" or not state.relics.has(id):return "遗物无法领取"
	var row: Dictionary=state.relics[id]
	if service.world.player.position.distance_to(Vector2(row.x,row.y))>78:return "请靠近遗物"
	if not service.world.stream.clear_reach(service.world.player.position,Vector2(row.x,row.y),null):return "遗物被挡住了"
	if index<0 or index>=row.contents.size() or not preload("res://scripts/food_freshness.gd").matches(row.contents[index],expected):return "遗物内容已变化"
	var old: Array[Dictionary]=service.inventory.slots.duplicate(true);var original: Dictionary=row.contents[index].duplicate(true)
	var left: int=service.inventory.add_value(original)
	if left==int(original.count):return "背包已满"
	if left==0:row.contents.remove_at(index)
	else:row.contents[index].count=left
	if not service.save_state():
		service.inventory.slots=old
		if left==0:row.contents.insert(index,original)
		else:row.contents[index]=original
		return "存档失败，领取已撤回"
	service.inventory.changed.emit();return ""

func advance(delta: float, shared: bool=true) -> void:
	if not is_finite(delta) or delta<=0:return
	if shared:service.chapter.finale.tick(delta)
	if service.body.health<=0 and personal.phase=="alive":die()
	if personal.phase!="alive":
		personal.clock+=delta
		if personal.phase=="dying" and personal.clock>=float(rules.death_seconds):
			var previous:=personal.duplicate(true);var old: Dictionary=service.body.serialize();var at: Vector2=service.world.player.position
			personal.phase="entering";personal.clock=0.0;service.body.health=100;service.body.down=false
			service.world.player.position=spawn_point()
			if not service.save_state():personal=previous;service.body.restore(old);service.world.player.position=at
			else:
				service.world.player.reset_physics_interpolation();service.world.player.camera.reset_smoothing()
				service.world.stream.update_target(service.world.player.position)
		elif personal.phase=="entering" and personal.clock>=float(rules.entry_seconds) and service.world.stream.viewport_ready(service.world.player.position,Vector2(640,360)):
			personal.phase="alive";personal.clock=0.0
			if not service.save_state():personal.phase="entering"
		return
	if not personal.attack.is_empty():
		if service.body.sleep_active() or personal.attack.get("held","")!=service.inventory.equipment.get("main_hand",{}).get("instance_id",""):
			personal.attack={};return
		var a: Dictionary=personal.attack;var before: float=a.elapsed;a.elapsed+=delta
		var w: Dictionary=a.weapon
		if before<float(w.windup)+float(w.active) and a.elapsed>=float(w.windup):resolve_hits(a)
		if a.elapsed>=float(w.windup)+float(w.active)+float(w.recovery):personal.attack={}
	if shared:
		advance_boars(delta)

func spawn_point() -> Vector2:
	if state.get("spawn",{}).is_empty():
		var at: Vector2=service.world.choose_entry_point()
		state.spawn={"x":at.x,"y":at.y}
	return Vector2(state.spawn.x,state.spawn.y)

func resolve_hits(a: Dictionary) -> void:
	service.chapter.finale.hit(a)
	var origin: Vector2=service.world.player.position
	var direction:=Vector2(a.direction.x,a.direction.y)
	var old_world:=state.duplicate(true);var old_loose: Dictionary=service.loose.duplicate(true)
	var changed:=false
	for id in service.animals.states:
		var animal: Dictionary=service.animals.states[id]
		if animal.get("departed",false) or a.targets.has("animal:"+str(id)):continue
		var at:=Vector2(animal.x,animal.y)
		var target: Node2D=service.animals.visuals.get(id)
		if Rules.can_hit(origin,direction,at,float(a.weapon.range),10) and service.world.stream.clear_reach(origin,at,target):
			a.targets["animal:"+str(id)]=true
			service.notice.emit("小鸡这么可爱，怎么能打它呢？" if animal.species=="chicken" else "小羊这么可爱，怎么能打它呢？")
	for peer in peers:
		var id:=str(peer.id)
		if a.targets.has(id) or peer.get("phase","alive")!="alive":continue
		var at:=Vector2(peer.x,peer.y)
		if Rules.can_hit(origin,direction,at,float(a.weapon.range),10) and service.world.stream.clear_reach(origin,at,null):
			a.targets[id]=true;damage_events.append({"target":id,"amount":a.weapon.damage,"source":{"x":origin.x,"y":origin.y},"duel":false})
	for id in state.boars:
		var row: Dictionary=state.boars[id]
		if row.health<=0 or a.targets.has(id):continue
		var at:=Vector2(row.x,row.y)
		var target: Node2D=service.combat_view.boars.get(id) if is_instance_valid(service.combat_view) else null
		if Rules.can_hit(origin,direction,at,float(a.weapon.range),14) and service.world.stream.clear_reach(origin,at,target):
			a.targets[id]=true;row.health=maxf(0,row.health-float(a.weapon.damage));row.hit=6.0;changed=true
			row.mode="hurt";row.clock=0.0
			var next:=at+(at-origin).normalized()*8
			if boar_clear(at,next,target):row.x=next.x;row.y=next.y
			if row.health<=0:boar_drop(id,row)
	if changed and not service.save_state():state=old_world;service.loose=old_loose;personal.attack={}

func boar_drop(id: String, row: Dictionary) -> void:
	if row.get("dropped",false):return
	row.dropped=true;row.respawn=float(rules.boar.respawn_seconds)
	row.mode="dead"
	for item in rules.boar.drops:
		var key: String="boar:"+id+":"+str(row.get("generation",0))+":"+str(item)
		service.loose[key]={"id":key,"x":row.x,"y":row.y,"item_id":item,"count":int(rules.boar.drops[item]),"mode":"pickup"}
	service.dirty=true

func advance_boars(delta: float) -> void:
	if not state.population_initialized or int(state.get("population_revision",0))<int(rules.boar.population_revision):
		state.population_revision=int(rules.boar.population_revision)
		state.population_initialized=true
		var rng:=RandomNumberGenerator.new();rng.seed=service.world.world_seed^811927
		for n in 2400:
			if state.boars.size()>=int(rules.boar.population):break
			var at:=Vector2(rng.randf_range(100,service.world.generator.extent-100),rng.randf_range(100,service.world.generator.extent-100))
			if at.distance_to(spawn_point())<float(rules.boar.safe_radius) or not service.world.generator.can_walk(at):continue
			if state.boars.values().any(func(b):return Vector2(b.home_x,b.home_y).distance_to(at)<float(rules.boar.min_spacing)):continue
			var ecology: Dictionary=service.ecology(at)
			if maxf(float(ecology.forest),float(ecology.rocky))<.5:continue
			if not service.ground_clear(at,25,service.nearby_props(at)):continue
			if service.builds.states.values().any(func(b):return Vector2(b.x,b.y).distance_to(at)<float(rules.boar.get("camp_clearance",240))):continue
			var id: String="boar:%d:%d"%[service.world.world_seed,n]
			state.boars[id]={"x":at.x,"y":at.y,"home_x":at.x,"home_y":at.y,"health":float(rules.boar.health),"mode":"patrol","clock":0.0,"hit":0.0,"generation":0}
	var minute: float=service.world.environment_view.simulation.minute
	var night: bool=minute>=float(rules.boar.night_start_minute) or minute<float(rules.boar.night_end_minute)
	if night: advance_night_encounter(delta,minute)
	for id in state.boars:
		var row: Dictionary=state.boars[id]
		row.hit=maxf(0,float(row.get("hit",0))-delta)
		if row.health<=0:
			row.respawn=maxf(0,float(row.get("respawn",rules.boar.respawn_seconds))-delta)
			if row.respawn<=0:
				row.health=float(rules.boar.health);row.dropped=false;row.generation=int(row.generation)+1;row.x=row.home_x;row.y=row.home_y;row.mode="patrol";row.clock=0.0;row.hit=0.0
			continue
		var at:=Vector2(row.x,row.y);var home:=Vector2(row.home_x,row.home_y);var player: Vector2=service.world.player.position
		var target_id:=""
		var nearest: float=at.distance_to(player) if personal.phase=="alive" else INF
		for peer in peers:
			if peer.get("phase","alive")!="alive":continue
			var peer_at:=Vector2(peer.x,peer.y)
			if at.distance_to(peer_at)<nearest:nearest=at.distance_to(peer_at);player=peer_at;target_id=str(peer.id)
		var distance:=at.distance_to(player)
		row.clock=float(row.clock)+delta
		if row.mode=="hurt":
			if row.clock<float(rules.boar.get("hit_stun",.18)):continue
			row.mode="chase"
		var weapon: Dictionary=rules.weapons.boar
		var duration: float=weapon.windup+weapon.active+weapon.recovery
		# Once committed, finish this attack independently of detection/leash checks.
		if row.mode=="attack":
			var victim: String=str(row.get("attack_target",""))
			if victim.begins_with("crop:"):
				var plot_id:=victim.trim_prefix("crop:")
				var plot: Dictionary=service.builds.states.get(plot_id,{})
				if row.clock>=float(weapon.windup) and row.clock<=duration and not row.get("struck",false) and not plot.is_empty() and not str(plot.get("crop","")).is_empty():
					var center:=Vector2(plot.x,plot.y)
					if at.distance_to(center)<float(weapon.range) and attack_path_clear(at,center,id):
						row.struck=true;destroy_crop(plot_id)
				if row.clock>=duration:row.mode="chase";row.clock=0.0
				continue
			var victim_alive: bool=personal.phase=="alive" if victim.is_empty() else false
			var victim_at: Vector2=service.world.player.position
			for peer in peers:
				if str(peer.id)==victim:
					victim_alive=peer.get("phase","alive")=="alive";victim_at=Vector2(peer.x,peer.y);break
			if row.clock>=float(weapon.windup) and row.clock<=duration and not row.get("struck",false) and victim_alive and at.distance_to(victim_at)<float(weapon.range) and attack_path_clear(at,victim_at,id):
				row.struck=true
				if victim.is_empty():damage(float(weapon.damage),at)
				else:damage_events.append({"target":victim,"amount":weapon.damage,"source":{"x":at.x,"y":at.y},"duel":false})
			if row.clock>=duration:row.mode="chase";row.clock=0.0
			continue
		var target:=home
		var following: bool=row.mode in ["alert","chase","hurt"]
		var detection: float=rules.boar.get("chase_range",600) if following else rules.boar.notice_range
		if night and row.get("night_hunter",false):detection=float(rules.boar.night_hunt_range)
		if nearest<INF and distance<detection and player.distance_to(home)<(float(rules.boar.night_hunt_range) if night and row.get("night_hunter",false) else float(rules.boar.leash)):
			if row.mode in ["patrol","return"]:row.mode="alert";row.clock=0.0
			if row.mode=="alert" and row.clock<.7:continue
			if distance<float(weapon.range) and (not night or crop_on_path(at,player,id).is_empty()):
				row.mode="attack";row.clock=0.0;row.struck=false;row.attack_target=target_id
				if absf(player.x-at.x)>8:row.facing_x=1.0 if player.x>at.x else -1.0
				continue
			row.mode="chase";target=player
		else:
			row.mode="return" if at.distance_to(home)>30 else "patrol"
			if night:
				row.mode="patrol"
				var phase: float=float(str(id).hash()%628)/100.0
				target=home+Vector2(cos(row.clock*.025+phase),sin(row.clock*.019+phase))*float(rules.boar.night_roam_radius)
			elif row.mode=="patrol":target=home+Vector2(cos(row.clock*.2),sin(row.clock*.17))*45
		if night:
			var crop_id:=crop_on_path(at,player,id)
			if not crop_id.is_empty():
				var plot: Dictionary=service.builds.states[crop_id]
				target=Vector2(plot.x,plot.y);row.mode="chase"
				if at.distance_to(target)<float(weapon.range):
					row.mode="attack";row.clock=0.0;row.struck=false;row.attack_target="crop:"+crop_id
					continue
		var travel: Vector2=target-at
		# Ignore tiny sideways corrections; knockback never changes this heading.
		var desired_facing: float=1.0 if travel.x>0 else -1.0
		row.turn_clock=maxf(0,float(row.get("turn_clock",0))-delta)
		if absf(travel.x)>maxf(24,absf(travel.y)*.35) and float(row.turn_clock)<=0 and desired_facing!=float(row.get("facing_x",1)):
			row.facing_x=desired_facing;row.turn_clock=.5
		var next:=at.move_toward(target,float(rules.boar.speed)*(float(rules.boar.night_speed_multiplier) if night else 1.0)*delta*(1.0 if row.mode=="chase" else .4))
		var target_node: Node2D=service.combat_view.boars.get(id) if is_instance_valid(service.combat_view) else null
		if boar_clear(at,next,target_node):
			row.x=next.x;row.y=next.y

func destroy_crop(id: String) -> void:
	var plot: Dictionary=service.builds.states[id]
	plot.crop="";plot.growth_minutes=0.0;plot.roots=true;plot.erase("fertilized")
	service.dirty=true
	if service.builds.visuals.has(id):service.builds.visuals[id].queue_redraw()

func crop_on_path(at: Vector2, player: Vector2, boar_id: String) -> String:
	var selected:=""
	var nearest: float=float(rules.boar.crop_notice_range)
	for id in service.builds.states:
		var plot: Dictionary=service.builds.states[id]
		if plot.kind!="tilled_soil" or str(plot.get("crop","")).is_empty():continue
		var center:=Vector2(plot.x,plot.y)
		var distance:=at.distance_to(center)
		if distance<nearest and center.distance_to(Geometry2D.get_closest_point_to_segment(center,at,player))<float(rules.boar.crop_path_width) and attack_path_clear(at,center,boar_id):
			nearest=distance;selected=str(id)
	return selected

func advance_night_encounter(delta: float, minute: float) -> void:
	var observers: Array[Vector2]=[]
	if personal.phase=="alive":observers.append(service.world.player.position)
	for peer in peers:
		if peer.get("phase","alive")=="alive":observers.append(Vector2(peer.x,peer.y))
	if observers.is_empty():return
	var night_day: int=int(service.world.environment_view.simulation.day)-(1 if minute<float(rules.boar.night_end_minute) else 0)
	if int(state.get("encounter_night",-999))==night_day:return
	state.encounter_wait=float(state.get("encounter_wait",0))+delta
	if state.encounter_wait<float(rules.boar.night_encounter_delay):return
	state.encounter_wait=0.0
	var rng:=RandomNumberGenerator.new();rng.seed=service.world.world_seed^night_day*7919
	if rng.randf()>float(rules.boar.night_encounter_chance):
		state.encounter_night=night_day;service.dirty=true;return
	# Select from all authenticated participants, independent of polling order.
	observers.sort_custom(func(a: Vector2,b: Vector2):return a.x<b.x or (a.x==b.x and a.y<b.y))
	var player: Vector2=observers[posmod(night_day,observers.size())]
	# Reuse a distant living animal: no population inflation or visible teleport.
	var selected:=""
	for id in state.boars:
		var row: Dictionary=state.boars[id]
		var distant:=true
		for observer in observers:
			if Vector2(row.x,row.y).distance_to(observer)<=float(rules.boar.night_spawn_max)*2:distant=false
		if row.health>0 and row.mode in ["patrol","return"] and distant:
			selected=str(id);break
	if selected.is_empty():return
	for attempt in 48:
		var at:=player+Vector2.RIGHT.rotated(rng.randf()*TAU)*rng.randf_range(float(rules.boar.night_spawn_min),float(rules.boar.night_spawn_max))
		if encounter_visible(at,observers):continue
		if not service.world.generator.can_walk(at) or not service.ground_clear(at,25,service.nearby_props(at)) or not boar_clear(at,at+Vector2(.01,0)):continue
		var row: Dictionary=state.boars[selected]
		row.x=at.x;row.y=at.y;row.home_x=at.x;row.home_y=at.y;row.mode="chase";row.clock=0.0;row.night_hunter=true
		row.facing_x=1.0 if player.x>at.x else -1.0
		state.encounter_night=night_day;service.dirty=true;return

func encounter_visible(at: Vector2, observers: Array[Vector2]) -> bool:
	if not service.world.get_meta("network_rules_host",false):
		var screen: Vector2=service.world.get_viewport().get_canvas_transform()*at
		return service.world.get_viewport().get_visible_rect().grow(100).has_point(screen)
	# The headless host's viewport is unrelated to any player's camera. Cover the
	# default window at the widest allowed zoom, with the original offscreen margin.
	var half_view:=Vector2(640,360)/.65+Vector2(100,100)
	for observer in observers:
		if Rect2(observer-half_view,half_view*2).has_point(at):return true
	return false

func trample_crops(at: Vector2, node: CollisionObject2D=null) -> void:
	for id in service.builds.states:
		var plot: Dictionary=service.builds.states[id]
		if plot.kind!="tilled_soil" or str(plot.get("crop","")).is_empty():continue
		var center:=Vector2(plot.x,plot.y)
		if not preload("res://scripts/planting.gd").soil_rect().has_point(at-center):continue
		if not boar_clear(at,center,node):continue
		plot.crop="";plot.growth_minutes=0.0;plot.roots=true;plot.erase("fertilized")
		service.dirty=true
		if service.builds.visuals.has(id):service.builds.visuals[id].queue_redraw()

func attack_path_clear(at: Vector2, target: Vector2, id: String) -> bool:
	var node: CollisionObject2D=service.combat_view.boars.get(id) if is_instance_valid(service.combat_view) else null
	var query:=PhysicsRayQueryParameters2D.create(at,target)
	query.exclude=[service.world.player.get_rid()]
	if node!=null:query.exclude.append(node.get_rid())
	return service.world.stream.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func boar_clear(at: Vector2, next: Vector2, node: CollisionObject2D=null) -> bool:
	if not service.world.generator.can_walk(next):return false
	for row in service.builds.states.values():
		if row.layer in ["ground","overlay"] or Geometry2D.get_closest_point_to_segment(Vector2(row.x,row.y),at,next).distance_to(Vector2(row.x,row.y))>160:continue
		var polygon: PackedVector2Array=service.animals.barrier_polygon(row)
		if Geometry2D.is_point_in_polygon(next,polygon):return false
		for n in polygon.size():
			if Geometry2D.segment_intersects_segment(at,next,polygon[n],polygon[(n+1)%polygon.size()])!=null:return false
			if next.distance_to(Geometry2D.get_closest_point_to_segment(next,polygon[n],polygon[(n+1)%polygon.size()]))<14:return false
	var query:=PhysicsRayQueryParameters2D.create(at,next)
	query.exclude=[service.world.player.get_rid()]
	if node!=null:query.exclude.append(node.get_rid())
	return service.world.stream.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func debug_spawn_near() -> bool:
	if not OS.has_feature("debug") or not service.writable or busy or Engine.has_meta("network_game_controller"):return false
	var origin: Vector2=service.world.player.position
	for i in 24:
		var at:=origin+Vector2.RIGHT.rotated(i*TAU/24)*120
		if not service.world.stream.has_ground(at) or not boar_clear(origin,at) or at.distance_to(spawn_point())<85:continue
		var id: String="debug_"+str(Time.get_ticks_usec())
		state.boars[id]={"x":at.x,"y":at.y,"home_x":at.x,"home_y":at.y,"health":float(rules.boar.health),"mode":"patrol","clock":0.0,"hit":0.0,"generation":0}
		if not service.save_state():state.boars.erase(id);return false
		return true
	service.notice.emit("附近没有合适的野猪位置")
	return false
