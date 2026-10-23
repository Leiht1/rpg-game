extends RefCounted
## Persistent placement/cooking lives in the original item snapshot; visuals are disposable.
var service: Node
var states: Dictionary = {}
var bins: Dictionary = {}
var burning: Dictionary = {}
var visuals: Dictionary = {}
var busy := false
var discovered: Dictionary = {}
var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campfire_rules.json"))

# Torches keep their fuel in the original building snapshot, sharing fuel transactions.
func fuel_state(id: String) -> Dictionary:
	if states.has(id): return states[id]
	var row: Dictionary=service.builds.states.get(id,{})
	return row if row.get("kind","")=="camp_torch" else {}

func fuel_visual(id: String) -> Node2D:
	return visuals.get(id,service.builds.visuals.get(id))

func fuel_lit(id: String) -> bool:
	var row := fuel_state(id)
	return bool(row.get("lit",false)) and float(row.get("fuel",0))>0

func rebuild() -> void:
	bins.clear(); burning.clear()
	for id in states:
		var row: Dictionary=states[id]
		var coord: Vector2i=service.world.stream.chunk_at(Vector2(row.x,row.y))
		if not bins.has(coord): bins[coord]=[]
		bins[coord].append(id)
		if row.lit: burning[id]=true

func serialize() -> Dictionary:
	return {"version":1,"objects":states.duplicate(true),"discovery_version":1,"discovered":discovered.duplicate(true)}

func validate(data: Variant) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("objects") is Dictionary: return false
	if data.get("discovery_version",1)!=1 or not data.get("discovered",{}) is Dictionary: return false
	for key in data.get("discovered",{}):
		if not rules.recipes.has(key) or not data.discovered[key] is bool or data.discovered[key]!=true: return false
	for id in data.objects:
		var row = data.objects[id]
		if not id is String or id.is_empty() or not row is Dictionary: return false
		for key in ["x","y","fuel","elapsed"]:
			var v = row.get(key)
			if not (v is int or v is float) or not is_finite(float(v)): return false
		if row.x<0 or row.y<0 or row.x>service.world.generator.extent or row.y>service.world.generator.extent: return false
		if row.fuel<0 or row.fuel>float(rules.max_fuel) or not row.get("lit") is bool or (row.lit and row.fuel<=0): return false
		if not row.get("recipe") is String or not row.get("ready") is bool: return false
		var damage = row.get("hits",0)
		if not (damage is int or damage is float) or damage<0 or damage>2 or damage!=floor(damage): return false
		if row.has("output"):
			if not row.output is Dictionary or row.output.get("item_id")!=rules.recipes.get(row.recipe,{}).get("output","") or row.output.get("count")!=1 or not preload("res://scripts/food_freshness.gd").normalize(service.database,row.output):return false
		if row.recipe.is_empty():
			if row.elapsed!=0 or row.ready: return false
		else:
			if not rules.recipes.has(row.recipe): return false
			var duration: float=rules.recipes[row.recipe].seconds
			if row.elapsed<0 or row.elapsed>duration or row.ready!=(row.elapsed==duration): return false
	return true

func placement_reason(at: Vector2) -> String:
	var world: Node=service.world
	var gen=world.generator
	if not service.writable: return "存档受保护，不能放置"
	if world.player.position.distance_to(at)>float(rules.place_range): return "请放在身边的地面"
	if world.player.position.distance_to(at)<float(rules.player_clearance): return "离角色太近"
	if at.distance_to(gen.spawn)<float(rules.spawn_clearance): return "请避开出生点"
	if at.distance_to(service.combat.spawn_point())<float(rules.spawn_clearance):return "请避开出生传送门"
	if at.x<96 or at.y<96 or at.x>gen.extent-96 or at.y>gen.extent-96: return "请远离地图边界"
	if not world.stream.has_ground(at): return "请等待附近地面加载"
	if gen.corridor_distance(at)<float(rules.path_clearance): return "请保留主要通行路径"
	var center: Vector4=gen.sample(at)
	for i in 9:
		var p: Vector2=at+(Vector2.ZERO if i==8 else Vector2.from_angle(TAU*i/8)*float(rules.ground_clearance))
		var v: Vector4=gen.sample(p)
		if not gen.can_walk(p,12) or v.z>.03: return "篝火需要干燥、远离水岸的陆地"
		if Vector3(v.x,v.y,v.w).distance_to(Vector3(center.x,center.y,center.w))>.25: return "请避开地形交界"
	# Placement is an occasional local query, never a world/map scan.
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new(); shape.radius=float(rules.obstacle_clearance)
	query.shape=shape;query.transform=Transform2D(0,at)
	if not world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): return "附近有障碍，换个空旷位置"
	for node in world.get_tree().get_nodes_in_group("world_interactables"):
		if node.get_meta("camp_layer","")=="ground": continue
		if at.distance_to(node.position)<float(rules.obstacle_clearance)+18: return "请避开资源与其他篝火"
	# Keep a walkable ring around the small collision footprint.
	for i in 12:
		var p: Vector2=at+Vector2.from_angle(TAU*i/12)*64
		if not gen.can_walk(p,12): return "周围需要留出通行空间"
	return ""

func consume(materials: Dictionary, fresh_food: bool=false) -> ItemInventory:
	var staged := ItemInventory.new(service.database)
	staged.slots=service.inventory.slots.duplicate(true)
	for id in materials:
		var left: int=materials[id]
		if staged.count_item(id)<left: return null
		for i in staged.SLOT_COUNT:
			if staged.slots[i].get("item_id","")!=id: continue
			if fresh_food and preload("res://scripts/food_freshness.gd").rotten(staged.slots[i]):continue
			var take: int=mini(left,int(staged.slots[i].count))
			staged.slots[i].count-=take;left-=take
			if staged.slots[i].count==0: staged.slots[i]={}
			if left==0: break
		if left>0:return null
	return staged

func commit(staged: ItemInventory = null) -> void:
	# Both sides are final before signals can observe/save either side.
	if staged!=null: service.inventory.slots=staged.slots
	service.dirty=true
	if staged!=null: service.inventory.changed.emit()
	service.save_state()

func place(at: Vector2, slot: int, expected: Dictionary) -> String:
	if preload("res://scripts/network_game_route.gd").send(self,"camp_place",[at,slot,expected]):return ""
	if busy: return "正在处理"
	var reason := placement_reason(at)
	if not reason.is_empty(): return reason
	if slot<0 or slot>=40 or service.inventory.slots[slot]!=expected or expected.get("item_id")!="simple_campfire": return "原篝火物品已移动，请重新使用"
	busy=true
	var staged := ItemInventory.new(service.database);staged.slots=service.inventory.slots.duplicate(true)
	staged.slots[slot].count-=1
	if staged.slots[slot].count==0: staged.slots[slot]={}
	var id := "camp:"+str(ResourceUID.create_id())
	states[id]={"x":at.x,"y":at.y,"fuel":0.0,"lit":false,"recipe":"","elapsed":0.0,"ready":false}
	rebuild();commit(staged);install(service.world.stream.chunk_at(at));busy=false
	return ""

func known(recipe: String) -> bool:
	return rules.recipes.has(recipe) and not rules.recipes[recipe].get("legacy_only",false) and (rules.recipes[recipe].get("default_unlocked",true) or discovered.has(recipe))

func match_materials(materials: Dictionary) -> String:
	# JSON numbers are floats; compare exact integral quantities without key order.
	for key in materials:
		var count = materials[key]
		if not count is int or count<1: return ""
	for key in rules.recipes:
		if rules.recipes[key].get("legacy_only",false): continue
		var expected: Dictionary=rules.recipes[key].materials
		if expected.size()!=materials.size(): continue
		var matches := true
		for id in expected:
			if not materials.has(id) or float(materials[id])!=float(expected[id]): matches=false;break
		if matches: return key
	return ""

func act(id: String, action: String, recipe: String = "", materials: Dictionary = {}) -> String:
	if service.body.sleep_active(): return "睡醒了再试试"
	if preload("res://scripts/network_game_route.gd").send(self,"camp_act",[id,action,recipe,materials]):return ""
	if busy: return "正在处理"
	if not service.writable: return "存档受保护，不能操作"
	if not states.has(id): return "篝火不存在"
	var row: Dictionary=states[id]
	if service.world.player.position.distance_to(Vector2(row.x,row.y))>float(rules.interaction_range): return "请靠近篝火"
	busy=true
	var before_states: Dictionary=states.duplicate(true)
	var before_slots: Array=service.inventory.slots.duplicate(true)
	var staged: ItemInventory
	var reason := ""
	var claimed := ""
	match action:
		"cook", "experiment":
			if action=="experiment": recipe=match_materials(materials)
			if not row.recipe.is_empty(): reason="请先完成并领取当前食物"
			elif not rules.recipes.has(recipe): reason="尚无已知料理能使用这组材料"
			elif action=="cook" and not known(recipe): reason="尚未发现"
			elif not row.lit or row.fuel<=0: reason="将背包或快捷栏的可燃物拖到篝火上点燃"
			else:
				staged=consume(rules.recipes[recipe].materials,true)
				if staged==null: reason="食材不足"
				else: row.erase("output");row.recipe=recipe;row.elapsed=0.0;row.ready=false
		"claim":
			if not row.ready: reason="暂无可领取成品"
			else:
				staged=ItemInventory.new(service.database);staged.slots=service.inventory.slots.duplicate(true)
				if staged.add_value(row.get("output",{"item_id":str(rules.recipes[row.recipe].output),"count":1}))>0: reason="背包已满，成品保留在篝火中"
				else: claimed=str(rules.recipes[row.recipe].output);row.erase("output");row.recipe="";row.elapsed=0.0;row.ready=false
		_: reason="未知操作"
	if reason.is_empty():
		if staged!=null: service.inventory.slots=staged.slots
		service.dirty=true
		if not service.save_state():
			states=before_states;service.inventory.slots=before_slots
			reason="保存失败，操作已回滚"
		else:
			if staged!=null: service.inventory.changed.emit()
			if not claimed.is_empty(): service.item_obtained.emit(claimed,1)
	busy=false
	return reason

func feed_check(id: String, slot: int, expected: Dictionary) -> String:
	if busy: return "正在处理"
	if not service.writable: return "存档受保护，不能投入物品"
	if fuel_state(id).is_empty() or not is_instance_valid(fuel_visual(id)): return "火源尚未加载"
	if slot<0 or slot>=40 or service.inventory.slots[slot]!=expected or expected.is_empty(): return "原物品已移动，请重新拖动"
	if not rules.fuel_items.has(str(expected.get("item_id",""))): return "这种物品不能燃烧，物品已保留"
	var row: Dictionary=fuel_state(id)
	var player: Node2D=service.world.player
	if player.position.distance_to(Vector2(row.x,row.y))>float(rules.interaction_range): return "请靠近篝火再投入"
	if not service.world.stream.clear_reach(player.position,Vector2(row.x,row.y),fuel_visual(id)): return "与火源之间有障碍"
	if float(row.get("fuel",0))+float(rules.fuel_items[expected.item_id])>float(rules.max_fuel): return "燃时已足够，物品已保留"
	return ""

func feed_amount(id: String, expected: Dictionary) -> int:
	return mini(int(expected.count),int(floor((float(rules.max_fuel)-float(fuel_state(id).get("fuel",0)))/float(rules.fuel_items[expected.item_id]))))

func feed(id: String, slot: int, expected: Dictionary, count: int) -> String:
	if preload("res://scripts/network_game_route.gd").send(self,"camp_feed",[id,slot,expected,count]):return ""
	var reason := feed_check(id,slot,expected)
	if not reason.is_empty(): return reason
	if count<1 or count>feed_amount(id,expected): return "燃时或物品数量已变化，请重新投入"
	busy=true
	var row: Dictionary=fuel_state(id)
	var before: Dictionary=row.duplicate(true)
	var before_slots: Array=service.inventory.slots.duplicate(true)
	var before_burning := burning.duplicate(true)
	var was_lit: bool=fuel_lit(id)
	var staged := ItemInventory.new(service.database);staged.slots=service.inventory.slots.duplicate(true)
	staged.slots[slot].count-=count
	if staged.slots[slot].count==0: staged.slots[slot]={}
	row.fuel=float(row.get("fuel",0))+float(rules.fuel_items[expected.item_id])*count
	row.lit=true
	if states.has(id): burning[id]=true
	service.inventory.slots=staged.slots;service.dirty=true
	if not service.save_state():
		row.clear();row.merge(before);service.inventory.slots=before_slots;burning=before_burning;busy=false
		return "保存失败，燃料投放已回滚"
	service.inventory.changed.emit()
	if not was_lit:AudioFX.play_sfx("sfx_fire_ignite",Vector2(before.x,before.y))
	busy=false
	return ""

func target_at(at: Vector2) -> String:
	for id in service.builds.visuals:
		if service.builds.states[id].kind!="camp_torch":continue
		var node: Node2D=service.builds.visuals[id]
		if is_instance_valid(node) and Rect2(node.position+Vector2(-40,-84),Vector2(80,96)).has_point(at):return id
	for id in visuals:
		if not is_instance_valid(visuals[id]): continue
		var node: Node2D=visuals[id]
		if Rect2(node.position+Vector2(-46,-66),Vector2(92,78)).has_point(at): return id
	return ""

func burn_multiplier(rain: float, storm: float) -> float:
	var wet := clampf(rain,0,1)
	var thunder := clampf(storm,0,wet)
	return 1.0+wet*(float(rules.rain_burn_multiplier)-1.0)+thunder*(float(rules.storm_burn_multiplier)-float(rules.rain_burn_multiplier))

func advance(dt: float, rain: float = 0.0, storm: float = 0.0) -> void:
	if dt<=0 or not service.writable: return
	var rate := burn_multiplier(rain,storm)
	for row in service.builds.states.values():
		if row.kind!="camp_torch" or not row.get("lit",false):continue
		row.fuel=maxf(0,float(row.get("fuel",0))-dt*rate)
		if row.fuel<=0:row.lit=false
		service.dirty=true
	var completed := false
	for id in burning.keys():
		var row: Dictionary=states[id]
		var used: float=minf(dt,float(row.fuel)/rate)
		row.fuel=maxf(0,float(row.fuel)-used*rate)
		if not row.recipe.is_empty() and not row.ready:
			var duration: float=rules.recipes[row.recipe].seconds
			row.elapsed=minf(duration,float(row.elapsed)+used)
			row.ready=row.elapsed>=duration
			if row.ready:
				discovered[row.recipe]=true
				row.output={"item_id":rules.recipes[row.recipe].output,"count":1,"spoilage":0.0}
				completed=true
		if row.fuel<=0: row.lit=false;burning.erase(id)
		service.dirty=true
	if completed: service.save_state()

func install(coord: Vector2i) -> void:
	for id in bins.get(coord,[]):
		if visuals.has(id) and is_instance_valid(visuals[id]): continue
		var node := preload("res://scripts/campfire.gd").new()
		node.manager=self;node.camp_id=id;node.position=Vector2(states[id].x,states[id].y)
		visuals[id]=node;service.world.object_root.add_child(node)

func unload(coord: Vector2i) -> void:
	for id in bins.get(coord,[]):
		if visuals.has(id):
			if is_instance_valid(visuals[id]): visuals[id].queue_free()
			visuals.erase(id)

var build_book: RefCounted = preload("res://scripts/craft_book.gd").new(ItemDatabase.new(),"res://data/buildings.json")

func build_check(recipe_id: String) -> String:
	if service.body.sleep_active(): return "睡醒了再试试"
	if busy: return "正在处理"
	if not service.writable: return "存档受保护，不能建造"
	var recipe: Dictionary=build_book.recipe(recipe_id)
	if recipe.is_empty() or not recipe.default_unlocked: return "建筑未解锁"
	for id in recipe.materials:
		var need: int=int(recipe.materials[id])
		var d: Dictionary=service.builds.definitions.get(recipe.output_id,{})
		if d.has("replaces"): need=maxi(0,need-int(service.builds.definitions[d.replaces].cost.get(id,0)))
		if service.inventory.count_item(id)<need: return "材料不足："+str(service.database.item(id).name)
	return ""

func build(at: Vector2, recipe_id: String, expected_slots: Array) -> String:
	if preload("res://scripts/network_game_route.gd").send(self,"camp_build",[at,recipe_id,expected_slots]):return ""
	var definition: Dictionary=build_book.recipe(recipe_id)
	if service.builds.definitions.has(definition.get("output_id","")):
		var row: Dictionary=service.builds.candidate(str(definition.output_id),at,false,true,0)
		return service.builds.place(row,expected_slots)
	var reason := build_check(recipe_id)
	if not reason.is_empty(): return reason
	if not preload("res://scripts/food_freshness.gd").matches_slots(service.inventory.slots,expected_slots): return "背包已变化，请重新选择建造"
	reason=placement_reason(at)
	if not reason.is_empty(): return reason
	busy=true
	var staged := consume(build_book.recipe(recipe_id).materials)
	if staged==null: busy=false;return "材料不足"
	var before: Array=service.inventory.slots
	var id := "camp:"+str(ResourceUID.create_id())
	states[id]={"x":at.x,"y":at.y,"fuel":0.0,"lit":false,"recipe":"","elapsed":0.0,"ready":false}
	rebuild();install(service.world.stream.chunk_at(at))
	if not visuals.has(id) or not is_instance_valid(visuals[id]):
		states.erase(id);rebuild();busy=false;return "创建失败，材料未消耗"
	service.inventory.slots=staged.slots;service.dirty=true
	if not service.save_state():
		service.inventory.slots=before
		visuals[id].free();visuals.erase(id);states.erase(id);rebuild()
		busy=false;return "保存失败，建造已回滚，材料未消耗"
	service.inventory.changed.emit()
	busy=false
	AudioFX.build_placed("simple_campfire",at)
	service.notify_build_cost(build_book.recipe(recipe_id).materials)
	return ""
