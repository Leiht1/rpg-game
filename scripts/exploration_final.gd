extends RefCounted
## World state and rewards share the chapter's atomic inventory transaction.
const CORE="ancient_lord_core"
const LETTER="ocean_islands_record"
const BLUEPRINT="dock_blueprint"
var s: Node
var retry_at:=-30000
var harvest_cache: Dictionary={}
static var geometry_config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/final_chapter.json"))
var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/final_chapter.json"))
var state: Dictionary:
	get:return s.chapter.state.finale
static func initial() -> Dictionary:
	return {"version":1,"eligible":false,"site":{},"discovered":false,"triggered":false,"defeated":false,"core_claimed":false,"chest_open":false,"letter_claimed":false,"blueprint_claimed":false,"dock_unlocked":false,"boss":{}}
func valid(v: Variant) -> bool:
	if not v is Dictionary or not v.has_all(initial().keys()) or v.version!=1:return false
	for key in ["eligible","discovered","triggered","defeated","core_claimed","chest_open","letter_claimed","blueprint_claimed","dock_unlocked"]:
		if not v[key] is bool:return false
	if not v.site is Dictionary or not v.boss is Dictionary:return false
	if not v.site.is_empty():
		for axis in ["x","y"]:
			if not s.chapter.puzzle.number(v.site.get(axis),0,s.world.generator.extent):return false
		if not v.eligible:return false
	if v.discovered and v.site.is_empty() or v.triggered and not v.discovered or v.defeated and not v.triggered:return false
	if v.core_claimed and not v.defeated or v.chest_open and not v.defeated:return false
	if v.letter_claimed!=v.chest_open or v.blueprint_claimed!=v.chest_open or v.dock_unlocked and not v.blueprint_claimed:return false
	if not v.boss.is_empty():
		if not v.boss.has_all(["x","y","health","mode","clock","attack","sequence","direction","hits"]):return false
		for key in ["x","y","health","clock","sequence"]:
			if not s.chapter.puzzle.number(v.boss[key],0,1e15):return false
		if v.boss.health>float(config.health) or v.boss.mode not in ["idle","chase","windup","active","recover","dead"]:return false
		if v.boss.attack not in ["","slam","charge","quake","core"] or not v.boss.hits is Dictionary:return false
		if not v.boss.direction is Dictionary or not v.boss.direction.has_all(["x","y"]):return false
		for axis in ["x","y"]:
			if not s.chapter.puzzle.number(v.boss.direction[axis],-1,1):return false
		if v.defeated!=(v.boss.health==0) or v.defeated!=(v.boss.mode=="dead"):return false
	elif not v.site.is_empty():return false
	return true
func at() -> Vector2:return Vector2(state.site.get("x",0),state.site.get("y",0))
func boss_at() -> Vector2:return Vector2(state.boss.get("x",0),state.boss.get("y",0))
func chest_at() -> Vector2:return at()+Vector2(0,-270)
func sync_recipe() -> void:
	if s.camps.build_book!=null and s.camps.build_book.recipes.has("build_dock"):s.camps.build_book.recipes.build_dock.default_unlocked=state.dock_unlocked
func safe_site(p: Vector2) -> bool:
	var gen=s.world.generator
	if p.distance_to(gen.spawn)<1500 or p.distance_to(s.chapter.mine.at())<1600:return false
	# Full arena, approach and rewards need real walkable land, not a centre-only check.
	for ring in [0,240,480]:
		for i in 16:
			var q: Vector2=p+Vector2.from_angle(i*TAU/16)*float(ring)
			if not gen.can_walk(q,24) or gen.sample(q).z>.12:return false
			if not s.ground_clear(q,75,s.nearby_props(q)):return false
	for rows in [s.builds.states,s.camps.states,s.combat.state.relics]:
		for row in rows.values():
			if p.distance_to(Vector2(row.x,row.y))<float(config.radius)+220:return false
	for row in s.ore_nodes.values():
		if row.has_all(["x","y"]) and p.distance_to(Vector2(row.x,row.y))<530:return false
	# Include deterministic minerals in unloaded chunks; loaded ore_nodes alone misses them.
	var chunks: Dictionary={}
	for offset in [Vector2(-300,-300),Vector2(300,-300),Vector2(-300,300),Vector2(300,300),Vector2.ZERO]:chunks[s.world.stream.chunk_at(p+offset)]=true
	for coord in chunks:
		if not harvest_cache.has(coord):harvest_cache[coord]=preload("res://scripts/harvest_distribution.gd").build(s,coord)
		for row in harvest_cache[coord]:
			if p.distance_to(Vector2(row.x,row.y))<300:return false
	if p.distance_to(s.chapter.point("site"))<900 or p.distance_to(s.chapter.mine.record_at())<800:return false
	for y in range(-5,6):
		for x in range(-5,6):
			var q:=p+Vector2(x,y)*96
			if q.distance_to(p)>500:continue
			if not s.ground_clear(q,80,s.nearby_props(q)):return false
			for row in s.raw_cell(Vector2i(q/float(s.rules.cell_size))):
				if row.reason.is_empty() and p.distance_to(Vector2(row.x,row.y))<520:return false
	return s.has_approach(p,s.nearby_props(p))
func advance() -> void:
	sync_recipe()
	if not s.writable or s.world.get_meta("network_game",false):return
	var puzzle=s.chapter.puzzle.state
	if not puzzle.read or s.chapter.now()<puzzle.next_due:return
	if not state.eligible:
		var old: Dictionary=s.chapter.serialize();state.eligible=true
		if not s.chapter.commit(old):return
	if not state.site.is_empty() or Time.get_ticks_msec()-retry_at<15000:return
	retry_at=Time.get_ticks_msec()
	var hint: Dictionary=s.chapter.puzzle.route_hint.resolve(s)
	for candidate in hint.get("placement_candidates",[]):
		var p:=Vector2(candidate.x,candidate.y)
		if not safe_site(p):continue
		var old: Dictionary=s.chapter.serialize();state.site={"x":p.x,"y":p.y};reset_boss()
		s.chapter.commit(old);return
func reset_boss() -> void:
	state.boss={"x":at().x,"y":at().y,"health":float(config.health),"mode":"idle","clock":0.0,"attack":"","sequence":0,"direction":{"x":0.0,"y":1.0},"hits":{}}
func participants() -> Array:
	var result: Array=[]
	if s.combat.personal.phase=="alive" and s.body.health>0 and not s.chapter.mine.travel.inside:
		result.append({"id":"","x":s.world.player.position.x,"y":s.world.player.position.y})
	for peer in s.combat.peers:
		if peer.get("phase","alive")=="alive" and Vector2(peer.x,peer.y).distance_to(at())<float(config.leash):result.append(peer)
	return result.filter(func(p):return Vector2(p.x,p.y).distance_to(at())<float(config.leash))
func tick(delta: float) -> void:
	if not s.writable or s.world.get_meta("network_game",false) or state.site.is_empty() or state.defeated:return
	var old: Dictionary=s.chapter.serialize();var targets:=participants();var b: Dictionary=state.boss
	if targets.is_empty():
		if b.mode!="idle" or b.health!=float(config.health):reset_boss();s.chapter.commit(old)
		return
	targets.sort_custom(func(a,c):return boss_at().distance_squared_to(Vector2(a.x,a.y))<boss_at().distance_squared_to(Vector2(c.x,c.y)))
	var target:=Vector2(targets[0].x,targets[0].y)
	if not state.discovered:state.discovered=true
	if not state.triggered:
		if target.distance_to(at())>float(config.trigger):
			if old.finale.discovered!=state.discovered:s.chapter.commit(old)
			return
		state.triggered=true
	if b.mode=="idle":b.mode="chase"
	# Bounded substeps keep the warning, active window and charge path intact on host catch-up.
	var remaining:=minf(delta,5)
	while remaining>0:
		var dt:=minf(remaining,.04);remaining-=dt;b.clock+=dt
		if b.mode=="chase":
			var toward: Vector2=target-boss_at()
			if toward.length()>85:move_boss(toward.normalized()*float(config.speed)*dt)
			if b.clock>=1.0:
				var pattern: Array=["slam","charge","quake"] if b.health>float(config.health)*.5 else ["core","charge","quake","slam"]
				b.attack=pattern[int(b.sequence)%pattern.size()];b.sequence=int(b.sequence)+1;b.mode="windup";b.clock=0.0;b.hits={}
				var dir: Vector2=(target-boss_at()).normalized();b.direction={"x":dir.x,"y":dir.y}
		elif b.mode=="windup" and b.clock>=float(config.windup[b.attack]):b.mode="active";b.clock=0.0
		elif b.mode=="active":
			var previous:=boss_at()
			if b.attack=="charge":move_boss(Vector2(b.direction.x,b.direction.y)*float(config.charge_speed)*dt)
			for p in targets:
				var id: String=str(p.id);var pos:=Vector2(p.x,p.y)
				if b.hits.has(id):continue
				var distance:=pos.distance_to(boss_at());var hit:=false
				if b.attack=="charge":hit=pos.distance_to(Geometry2D.get_closest_point_to_segment(pos,previous,boss_at()))<58
				elif b.attack=="slam":hit=distance<float(config.range.slam) and (pos-boss_at()).normalized().dot(Vector2(b.direction.x,b.direction.y))>.15
				else:hit=distance<float(config.range[b.attack])
				if hit and clear_path(boss_at(),pos):
					b.hits[id]=true
					if id.is_empty():s.combat.damage(float(config.damage),boss_at())
					else:s.combat.damage_events.append({"target":id,"amount":config.damage,"source":{"x":boss_at().x,"y":boss_at().y},"duel":false})
			if b.clock>=float(config.active[b.attack]):b.mode="recover";b.clock=0.0
		elif b.mode=="recover" and b.clock>=float(config.recovery[b.attack]):b.mode="chase";b.clock=0.0
	if old.finale.discovered!=state.discovered or old.finale.triggered!=state.triggered:s.chapter.commit(old)
	else:s.dirty=true
func move_boss(step: Vector2) -> void:
	var next:=boss_at()+step
	for spec in config.scenery:
		if next.distance_to(at()+Vector2(spec.at[0],spec.at[1]))<float(spec.radius)+35:return
	if next.distance_to(at())<float(config.radius)-65 and s.world.generator.can_walk(next,40):state.boss.x=next.x;state.boss.y=next.y
func clear_path(from: Vector2, to: Vector2) -> bool:
	if from.is_equal_approx(to):return true
	var query:=PhysicsRayQueryParameters2D.create(from,to);var excluded: Array[RID]=[s.world.player.get_rid()]
	var view: Node=s.chapter_view.get_node_or_null("FinaleView") if is_instance_valid(s.chapter_view) else null
	if view!=null and is_instance_valid(view.guardian):
		var volume: StaticBody2D=view.guardian.get_node_or_null("Volume")
		if volume!=null:excluded.append(volume.get_rid())
	query.exclude=excluded
	return s.world.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
static func blocks(pos: Vector2, finale: Dictionary) -> bool:
	if finale.get("site",{}).is_empty():return false
	var site:=Vector2(finale.site.x,finale.site.y)
	for spec in geometry_config.scenery:
		if pos.distance_to(site+Vector2(spec.at[0],spec.at[1]))<float(spec.radius)+9.8:return true
	var boss: Dictionary=finale.get("boss",{})
	return not finale.get("defeated",false) and not boss.is_empty() and pos.distance_to(Vector2(boss.x,boss.y))<44.8
func hit(a: Dictionary) -> void:
	if state.site.is_empty() or state.defeated or a.targets.has("ancient_lord"):return
	var p: Vector2=s.world.player.position;var direction:=Vector2(a.direction.x,a.direction.y)
	if not preload("res://scripts/combat_rules.gd").can_hit(p,direction,boss_at(),float(a.weapon.range),42) or not clear_path(p,boss_at()):return
	var old: Dictionary=s.chapter.serialize();a.targets.ancient_lord=true
	state.discovered=true;state.triggered=true
	var exposed: bool=state.boss.mode=="recover" and state.boss.attack=="core"
	state.boss.health=maxf(0,state.boss.health-float(a.weapon.damage)*(1.5 if exposed else 1.0))
	if state.boss.health<=0:state.defeated=true;state.boss.mode="dead";state.boss.clock=0.0
	if not s.chapter.commit(old):a.targets.erase("ancient_lord")
func ready() -> bool:
	return s.writable and s.combat.personal.phase=="alive" and s.body.health>0 and not s.body.sleep_active() and s.world.player.action.is_empty() and s.craft_job.is_empty() and not s.chapter.mine.travel.inside
func interact(kind: String) -> String:
	if not ready() or state.site.is_empty():return "当前无法操作"
	var target: Vector2=chest_at() if kind=="chest" else boss_at()
	if s.world.player.position.distance_to(target)>100:return "请靠近再操作"
	if not state.defeated:return "古老的封印仍在。"
	if kind=="core" and state.core_claimed or kind=="chest" and state.chest_open:return ""
	if kind not in ["core","chest"]:return "无效操作"
	var old: Dictionary=s.chapter.serialize();var slots: Array=s.inventory.slots.duplicate(true)
	var items: Array=[CORE] if kind=="core" else [LETTER,BLUEPRINT]
	for id in items:
		if s.inventory.add(id,1)!=0:
			s.inventory.slots.assign(slots);s.inventory.changed.emit();return "背包空间不足"
	if kind=="core":state.core_claimed=true
	else:state.chest_open=true;state.letter_claimed=true;state.blueprint_claimed=true
	if not s.chapter.commit(old,slots):return "保存失败，请重试"
	s.inventory.changed.emit()
	for id in items:s.item_obtained.emit(id,1)
	return ""
func use_item(id: String) -> bool:
	if not ready() or s.inventory.count_item(id)<1:return false
	if id==LETTER:return state.letter_claimed
	if id!=BLUEPRINT or not state.blueprint_claimed or state.dock_unlocked:return false
	var old: Dictionary=s.chapter.serialize();var slots: Array=s.inventory.slots.duplicate(true)
	for i in s.inventory.slots.size():
		if s.inventory.slots[i].get("item_id","")==BLUEPRINT:s.inventory.slots[i]={};break
	state.dock_unlocked=true
	if not s.chapter.commit(old,slots):return false
	sync_recipe();s.inventory.changed.emit();return true
