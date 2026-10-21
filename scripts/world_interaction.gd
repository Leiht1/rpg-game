extends RefCounted
## One contract for selection, hints and execution. Names never grant abilities.
const BASIC := ["fertilize","animal","sow","cook","pickup","open","talk","inspect","sleep"]
const VERBS := {"sow":"播种","sleep":"睡觉","cook":"烹饪","pickup":"拾取","open":"打开","talk":"交谈","inspect":"查看","chop":"砍伐","mine":"开采","dig":"挖掘"}
const NEEDS := {"chop":"斧头","mine":"镐子","dig":"铲子"}

static func action_for(target: Node2D) -> String:
	if not is_instance_valid(target): return ""
	if target.has_meta("animal_id"): return target.manager.action(target.animal_id)
	if target.get_meta("building_id","")!="" or target.get("camp_id")!=null:
		var manager: RefCounted=target.manager
		if manager.service.inventory.has_capability("demolish"): return "demolish"
		if target.get_meta("building_id","")!="":
			var row: Dictionary=manager.states.get(target.building_id,{})
			if row.get("abandoned",false): return ""
			if row.get("kind","")=="tilled_soil": return manager.service.planting.action(target.building_id)
			if not row.is_empty() and (row.layer in ["ground","overlay"] or row.kind in ["stone_wall","wood_fence","camp_torch"]): return ""
	if target.is_in_group("drops"): return "pickup"
	if target.is_in_group("trees"): return "chop"
	return str(target.get_meta("interaction_action","inspect"))

static func allowed(inventory: ItemInventory, action: String) -> bool:
	return action in BASIC or (inventory!=null and inventory.has_capability(action))

static func in_reach(stream: Node, at: Vector2, target: Node2D) -> bool:
	if not is_instance_valid(target) or target.get_meta("collected",false) or target.get_meta("airborne",false) or target.get_meta("spent",false): return false
	var action := action_for(target)
	if action.is_empty(): return false
	if action=="chop": return stream.tree_in_reach(at,target)
	var distance := 42.0 if action=="pickup" else float(target.get_meta("interaction_range",62.0))
	var point := reach_point(at,target)
	if target.get_meta("interaction_action","")=="sleep":
		return at.distance_to(point)<distance and target.manager.service.sleep.path_clear(at,point,target.building_id)
	return at.distance_to(point)<distance and stream.clear_reach(at,point,target)

static func reach_point(at: Vector2, target: Node2D) -> Vector2:
	if target.get_meta("building_id","")!="" and not target.manager.volume_profile(str(target.manager.states.get(target.building_id,{}).get("kind",""))).is_empty():
		var row: Dictionary=target.manager.states[target.building_id]
		var bounds: Rect2=target.manager.footprint_rect(row)
		return target.to_global(target.to_local(at).clamp(bounds.position,bounds.end))
	if target.get_meta("interaction_action","")=="sleep":
		var row: Dictionary=target.manager.states.get(target.building_id,{})
		if not row.is_empty():
			var bounds: Rect2=target.manager.footprint_rect(row)
			return target.to_global(target.to_local(at).clamp(bounds.position,bounds.end))
	return target.position

static func target(stream: Node, at: Vector2, facing: String, pointer: Vector2) -> Node2D:
	var candidates: Array=[]
	candidates.append_array(stream.drops)
	candidates.append_array(stream.get_tree().get_nodes_in_group("trees"))
	candidates.append_array(stream.get_tree().get_nodes_in_group("world_interactables"))
	var direction: Vector2={"front":Vector2.DOWN,"back":Vector2.UP,"left":Vector2.LEFT,"right":Vector2.RIGHT}.get(facing,Vector2.DOWN)
	var best: Node2D
	var best_rank := INF
	var best_distance := INF
	var best_id := ""
	for node in candidates:
		if node.get_meta("camp_layer","")=="ground" and not node.get_meta("planting_soil",false) and (stream.items==null or not stream.items.inventory.has_capability("demolish")): continue
		if not in_reach(stream,at,node): continue
		var action := action_for(node)
		var region := Rect2(node.position-Vector2(18,28),Vector2(36,36))
		if action=="chop": region=Rect2(node.position-Vector2(node.display_size.x*.4,node.display_size.y-8),Vector2(node.display_size.x*.8,node.display_size.y))
		var pointed := pointer!=Vector2.INF and region.has_point(pointer)
		var front: bool = (node.position-at).normalized().dot(direction)>.35
		var basic := action in BASIC
		var capable := allowed(stream.items.inventory if stream.items else null,action)
		var rank := 0.0 if pointed else (1.0 if front and (basic or capable) else (2.0 if basic else 3.0))
		var distance: float = node.position.distance_to(pointer) if pointed else node.position.distance_to(at)-(18.0 if basic else 0.0)
		var id := str(node.get_meta("drop_id",node.get_meta("prop_id",node.name)))
		if rank<best_rank or (rank==best_rank and (distance<best_distance or (is_equal_approx(distance,best_distance) and id<best_id))):
			best=node; best_rank=rank; best_distance=distance; best_id=id
	return best

static func caption(target: Node2D, inventory: ItemInventory) -> String:
	if target.has_meta("animal_id"):return target.manager.caption(target.animal_id)
	var action := action_for(target)
	if action.is_empty(): return ""
	if not allowed(inventory,action): return "需要"+str(NEEDS.get(action,action))
	if action=="demolish": return "E 敲击拆除"
	if target.get_meta("planting_soil",false):
		if action=="fertilize":return "E 施肥"
		return "E 清除残根" if action=="dig" else "E 采集成熟作物" if action=="pickup" else "E 选择种子"
	if action=="open" and target.get_meta("building_id","")!="":
		var row: Dictionary=target.manager.states.get(target.building_id,{})
		if row.is_empty(): return ""
		if row.kind=="copper_lamp":return "E 关闭" if row.machine.enabled else "E 开启"
		if row.kind=="workbench": return "E 制作"
		if row.kind=="wood_chest": return "E "+("关闭木箱" if row.open else "打开木箱")
		if target.manager.definitions[row.kind].get("door",false): return "E "+("关门" if row.open else "开门")
	return "E "+str(VERBS.get(action,action))

static func execute(stream: Node, player: Node2D, target: Node2D) -> bool:
	if not in_reach(stream,player.position,target): return false
	var action := action_for(target)
	if action in ["chop","mine","dig","demolish","pickup","shear","animal","fertilize"] and preload("res://scripts/network_game_route.gd").send(stream.items,"interact",[target]):return true
	if player.action=="fertilize" and action!="fertilize":return false
	if not allowed(stream.items.inventory if stream.items else null,action): return false
	var body = player.get("body")
	if body!=null and (body.down or body.sleep_active() or (action in ["chop","mine","dig","demolish"] and not body.can_labor(action,player.action==action))): return false
	if target.get_meta("building_id","")!="" and stream.items.builds.states.get(target.building_id,{}).get("kind","")=="tilled_soil" and action!="demolish":
		if action=="fertilize":return stream.items.planting.fertilize(target.building_id,target)
		if action=="sow":return stream.items.planting_ui.open(target.building_id)
		return stream.items.planting.interact(target.building_id,target)
	var success := false
	match action:
		"demolish": return stream.items.builds.strike(str(target.get_meta("building_id",target.get("camp_id"))),target)
		"pickup": return stream.pickup_drop(target)
		"chop": stream.chop_tree(target); success=true
		"mine": success=stream.items.mine(target)
		_:
			if target.has_method("perform_interaction"): success=bool(target.perform_interaction(action,player))
	return success
