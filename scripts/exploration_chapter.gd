extends RefCounted
## World-owned chapter, committed with inventory by the original transaction.
const MAP := "predecessor_map"
const NOTE := "predecessor_note"
const BOTTLE := "mysterious_bottle"
const MIN_DAYS := 3
var finale:=preload("res://scripts/exploration_final.gd").new()
var puzzle:=preload("res://scripts/mine_puzzle.gd").new()
var mine:=preload("res://scripts/exploration_mine.gd").new()
var service: Node
var state: Dictionary=initial()
var last_placement_attempt:=-30000
static func initial() -> Dictionary:
	return {"finale":preload("res://scripts/exploration_final.gd").initial(),"mine":preload("res://scripts/mine_rules.gd").initial(),"version":2,"stage":0,"eligible_at":-1.0,"site":{},"shore":{},"lake":-1,"attempts":0,"bottle_claimed":false,"bottle_read":false,"investigated_at":-1.0,"elder_due":-1.0,"elder":{},"river_fish":{},"elder_spawned":false,"dialogue_at":-1.0,"fishing_due":-1.0,"fishing_open":false,"bottle_read_at":-1.0,"mine_due":-1.0}
func now() -> float:
	var clock=service.world.environment_view.simulation
	return (clock.day-1)*1440.0+clock.minute
func migrate(value: Dictionary) -> Dictionary:
	var result:=initial();result.merge(value.duplicate(true),true)
	if not result.mine.has("puzzle"):result.mine.puzzle=puzzle.initial()
	else:result.mine.puzzle=puzzle.migrate(result.mine.puzzle)
	if value.version==1:
		result.version=2
		# No historical timestamp existed. Anchor once to the restored world clock.
		if result.stage>=3:
			result.investigated_at=now();result.elder_due=now()+1440.0*(1+posmod(service.world.world_seed,2))
		if result.stage>=4:
			result.dialogue_at=now();result.fishing_due=now()+(0.0 if result.bottle_claimed else 1440.0)
			result.fishing_open=result.bottle_claimed;result.elder_due=now()
		if result.bottle_read:result.bottle_read_at=now();result.mine_due=now()+1440.0
	return result
func serialize() -> Dictionary:return state.duplicate(true)
func valid(value: Variant) -> bool:
	if value is Dictionary and value.has("finale") and not finale.valid(value.finale):return false
	if value is Dictionary and value.get("finale",{}).get("eligible",false) and not value.get("mine",{}).get("puzzle",{}).get("read",false):return false
	if value is Dictionary and value.has("mine"):
		if not mine.valid(value.mine):return false
		if not value.mine.site.is_empty() and not value.get("bottle_read",false):return false
	if not value is Dictionary or (value.get("version")!=1 and value.get("version")!=2):return false
	for key in ["stage","lake","attempts"]:
		if not (value.get(key) is int or value.get(key) is float) or not is_finite(float(value[key])) or value[key]!=floor(value[key]):return false
	for key in ["bottle_claimed","bottle_read"]:
		if not value.get(key) is bool:return false
	if value.version==2:
		for key in ["investigated_at","elder_due","dialogue_at","fishing_due","bottle_read_at","mine_due"]:
			if not (value.get(key) is int or value.get(key) is float) or not is_finite(float(value[key])) or value[key]<-1:return false
		for key in ["elder_spawned","fishing_open"]:
			if not value.get(key) is bool:return false
		for key in ["elder","river_fish"]:
			if not value.get(key) is Dictionary:return false
			if not value[key].is_empty():
				for axis in ["x","y"]:
					if not (value[key].get(axis) is int or value[key].get(axis) is float) or not is_finite(float(value[key][axis])) or value[key][axis]<0 or value[key][axis]>=service.world.generator.extent:return false
		if value.elder_spawned and (value.elder.is_empty() or value.river_fish.is_empty()):return false
		if value.stage>=3 and (value.investigated_at<0 or value.elder_due<value.investigated_at):return false
		if value.stage>=4 and (value.dialogue_at<0 or value.fishing_due<value.dialogue_at):return false
		if value.fishing_open and value.stage<4:return false
		if value.bottle_read and (value.bottle_read_at<0 or value.mine_due+.000001<value.bottle_read_at+1440):return false
	if value.stage<0 or value.stage>5 or value.lake< -1 or value.lake>=service.world.generator.lakes.size() or value.attempts<0 or value.attempts>2:return false
	if not (value.get("eligible_at") is float or value.get("eligible_at") is int) or not is_finite(float(value.eligible_at)):return false
	for key in ["site","shore"]:
		if not value.get(key) is Dictionary:return false
		var p: Dictionary=value[key]
		if p.is_empty():
			if value.stage>=2:return false
		else:
			for axis in ["x","y"]:
				if not (p.get(axis) is float or p.get(axis) is int) or not is_finite(float(p[axis])) or p[axis]<0 or p[axis]>=service.world.generator.extent:return false
	if value.stage>=2 and value.lake<0:return false
	if value.stage<2 and (not value.site.is_empty() or not value.shore.is_empty() or value.lake!=-1):return false
	if value.stage<4 and (value.bottle_claimed or value.attempts!=0):return false
	if (value.stage>=1)!=(value.eligible_at>=0):return false
	if value.bottle_read and not value.bottle_claimed:return false
	return (value.stage==5)==value.bottle_read
func mine_hook() -> Dictionary:
	if not state.bottle_read:return {}
	return {"version":2,"unlocked":now()>=state.mine_due,"available_at":state.mine_due,"seed":service.world.world_seed,"region":"mountain","entrance":"collapsed","landmark":"three_slashes"}
func point(key: String) -> Vector2:
	var p: Dictionary=state[key];return Vector2(p.get("x",0),p.get("y",0))
func eligible() -> bool:
	if service.world.environment_view.simulation.day<MIN_DAYS+1:return false
	for row in service.builds.states.values():
		if row.kind=="metal_workbench" and not row.get("abandoned",false):return true
	return false
func commit(before: Dictionary, slots: Array=[]) -> bool:
	service.dirty=true
	if service.save_state():return true
	state=before
	if not slots.is_empty():service.inventory.slots.assign(slots);service.inventory.changed.emit()
	return false
func advance() -> void:
	mine.advance()
	finale.advance()
	if not service.writable or service.world.get_meta("network_game",false):return
	if state.stage>=3:
		if (not state.elder_spawned or not elder_on_coast()) and now()>=state.elder_due and Time.get_ticks_msec()-last_placement_attempt>=15000:
			last_placement_attempt=Time.get_ticks_msec();place_elder()
		if state.stage>=4 and not state.fishing_open and now()>=state.fishing_due:
			var before:=serialize();state.fishing_open=true;commit(before)
	if state.stage==0 and eligible():
		var before:=serialize()
		state.stage=1;state.eligible_at=(service.world.environment_view.simulation.day-1)*1440.0+service.world.environment_view.simulation.minute
		commit(before)
		return # Qualification and placement are separate durable transitions.
	if state.stage==1 and Time.get_ticks_msec()-last_placement_attempt>=15000:
		last_placement_attempt=Time.get_ticks_msec();place_site()
func clear_site(at: Vector2, radius: float) -> bool:
	if at.distance_to(service.world.generator.spawn)<1200:return false
	if service.world.generator.sample(at).z>.32:return false
	if not service.ground_clear(at,radius,service.nearby_props(at)) or not service.has_approach(at,service.nearby_props(at)):return false
	for row in service.builds.states.values():
		if at.distance_to(Vector2(row.x,row.y))<radius+180:return false
	for row in service.camps.states.values():
		if at.distance_to(Vector2(row.x,row.y))<radius+100:return false
	for row in service.combat.state.relics.values():
		if at.distance_to(Vector2(row.x,row.y))<radius+100:return false
	if service.merchant.state.has_all(["x","y"]) and at.distance_to(Vector2(service.merchant.state.x,service.merchant.state.y))<radius+120:return false
	for row in service.ore_nodes.values():
		if row.has_all(["x","y"]) and at.distance_to(Vector2(row.x,row.y))<radius+80:return false
	# Resource cells are generated by the existing ecology; don't occupy a deposit.
	var cell:=Vector2i(at/float(service.rules.cell_size))
	for y in range(cell.y-1,cell.y+2):
		for x in range(cell.x-1,cell.x+2):
			for row in service.raw_cell(Vector2i(x,y)):
				if row.reason.is_empty() and at.distance_to(Vector2(row.x,row.y))<radius+60:return false
	return true
func place_site() -> void:
	var candidates: Array=service.fishing_population.candidates.duplicate()
	# Seeded rotation, never reroll persisted locations.
	if candidates.is_empty():return
	var start: int=posmod(service.world.world_seed,candidates.size())
	for i in candidates.size():
		var spot: Dictionary=candidates[(i+start)%candidates.size()]
		if spot.lake<0 or not clear_site(spot.stand,24):continue
		for offset in [Vector2(540,0),Vector2(-540,0),Vector2(0,540),Vector2(0,-540),Vector2(720,360),Vector2(-720,-360)]:
			var at: Vector2=spot.stand+offset
			if not clear_site(at,85):continue
			var before:=serialize()
			state.site={"x":at.x,"y":at.y};state.shore={"x":spot.stand.x,"y":spot.stand.y};state.lake=int(spot.lake);state.stage=2
			commit(before);return
func place_elder() -> void:
	var generator=service.world.generator
	var choices: Array=[]
	# Reuse real outer-continent bank candidates. -1 is the existing coast ID,
	# not an inland lake or river, and the water footprint was already checked.
	for candidate in service.fishing_population.candidates:
		if candidate.lake!=-1:continue
		var stand: Vector2=candidate.stand
		var water: Vector2=candidate.water
		var direction: Vector2=water-stand
		# This approved seated master faces sideways/slightly toward the camera.
		# Select matching banks instead of rotating it into a false back view.
		if absf(direction.x)<80 or direction.y< -12 or direction.y>absf(direction.x)*.8:continue
		if generator.coast_distance(water)>-40 or not clear_site(stand,34):continue
		if not clear_site(stand-direction.normalized()*40,24):continue
		choices.append({"stand":stand,"water":water})
	if choices.is_empty():return
	choices.sort_custom(func(a,b):return a.stand.distance_squared_to(point("site"))<b.stand.distance_squared_to(point("site")))
	var choice: Dictionary=choices[0]
	var before:=serialize()
	state.elder={"x":choice.stand.x,"y":choice.stand.y}
	state.river_fish={"x":choice.water.x,"y":choice.water.y};state.elder_spawned=true
	commit(before)
func elder_on_coast() -> bool:
	if not state.elder_spawned:return false
	var generator=service.world.generator
	return generator.coast_distance(point("river_fish"))< -40 and generator.coast_distance(point("elder"))>0
func interact(kind: String) -> String:
	if preload("res://scripts/network_game_route.gd").send(service,"chapter",[kind]):return ""
	if not service.writable or service.body.down or service.body.sleep_active() or service.combat.personal.phase!="alive" or not service.world.player.action.is_empty():return "当前无法调查"
	if state.stage<2 or kind not in ["remains","belongings","shore"]:return "尚未发现线索"
	if kind=="shore" and (not elder_on_coast() or now()<state.elder_due):return "尚未发现线索"
	var at:=point("elder" if kind=="shore" else "site")
	var target: Node2D=service.chapter_view.props.get(kind) if is_instance_valid(service.chapter_view) else null
	if service.world.player.position.distance_to(at)>110 or not service.world.stream.clear_reach(service.world.player.position,at,target):return "请靠近垂钓老者" if kind=="shore" else "请靠近遗留物"
	var before:=serialize()
	if kind=="shore":
		if state.stage==3:
			state.stage=4;state.dialogue_at=now();state.fishing_due=now()+1440.0
			if not commit(before):return "保存失败，请再试一次"
		return "垂钓老者\n\n同行者留下的瓶内抄录\n"+text(BOTTLE) if state.bottle_read else shore_text()
	if state.stage>=3:return text(MAP)+"\n\n"+text(NOTE)
	var slots: Array=service.inventory.slots.duplicate(true)
	if service.inventory.add(MAP,1)!=0 or service.inventory.add(NOTE,1)!=0:
		service.inventory.slots.assign(slots);service.inventory.changed.emit();return "背包空间不足，地图与残页仍留在遗物中"
	state.stage=3;state.investigated_at=now();state.elder_due=now()+1440.0*(1+posmod(service.world.world_seed,2))
	if not commit(before,slots):return "保存失败，遗物尚未领取"
	service.item_obtained.emit(MAP,1);service.item_obtained.emit(NOTE,1)
	return text(MAP)+"\n\n"+text(NOTE)
func special(lake: int) -> bool:
	return state.stage==4 and state.fishing_open and not state.bottle_claimed and state.dialogue_at>=0 and now()>=state.fishing_due and (lake==state.lake or (lake==-2 and state.elder_spawned))
func reward(lake: int) -> String:
	return BOTTLE if special(lake) and state.attempts>=2 else ""
func caught(lake: int, id: String) -> void:
	if not special(lake):return
	if id==BOTTLE:state.bottle_claimed=true
	else:state.attempts=mini(2,int(state.attempts)+1)
func read(id: String) -> bool:
	if id==puzzle.RECORD:return puzzle.read_record()
	if id not in [MAP,NOTE,BOTTLE]:return false
	if id==BOTTLE and not state.bottle_claimed:return false
	if id==BOTTLE and not state.bottle_read:
		var before:=serialize();state.bottle_read=true;state.stage=5;state.bottle_read_at=now();state.mine_due=now()+1440.0
		if not commit(before):return false
	return true
func use_item(id: String) -> bool:
	if id in [finale.LETTER,finale.BLUEPRINT]:
		if preload("res://scripts/network_game_route.gd").send(service,"chapter_read",[id]):return true
		var used: bool=finale.use_item(id)
		if used and id==finale.LETTER and not service.world.get_meta("network_rules_host",false):service.chapter_view.show_page("海彼岸的记录")
		return used
	if id=="miner_blast_pack":
		var result: String=mine.interact("place")
		if not result.is_empty():service.notice.emit(result)
		return result.is_empty()
	if not service.writable or service.body.down or service.body.sleep_active():return false
	var owned:=false
	for slot in service.inventory.slots:
		if slot.get("item_id","")==id:owned=true;break
	if not owned or id not in [MAP,NOTE,BOTTLE,puzzle.RECORD]:return false
	if preload("res://scripts/network_game_route.gd").send(service,"chapter_read",[id]):
		service.chapter_view.open_item(id);return true
	if not read(id):return false
	if not service.world.get_meta("network_rules_host",false) and is_instance_valid(service.chapter_view):service.chapter_view.open_item(id)
	return true
func text(id: String) -> String:
	if id==puzzle.RECORD:return puzzle.RECORD_TEXT
	if id==NOTE:return "残缺文字\n听说群山深处藏着一个传说。我决定去找那件东西。水边有人见过相同的刻记……今天山路塌了，腿也……"
	if id==MAP:
		return "模糊地图\n纸上大部分墨迹已散开，只能辨出陆地边缘的一段岸线。水边留着一个模糊的人影，路线到这里就断了。"
	return "瓶内残页\n他沿矿车留下的旧辙进入群山。废弃矿洞的入口旁，石壁刻着三道斜痕；塌落的石块挡住了前路。\n（废弃矿洞线索已保留。）"
func shore_text() -> String:return "垂钓老者\n“当年我要是帮他钓到了那样东西就好了……”\n\n他看着水面，轻轻叹了口气。"
