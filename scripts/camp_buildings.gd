extends RefCounted
const Grid = preload("res://scripts/camp_grid.gd")
var service: Node
var states: Dictionary={}
var visuals: Dictionary={}
var busy := false
var textures: Dictionary={}
var abandoned_version := 0
var definitions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/camp_buildings.json"))

var volume_profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/camp_volume_v2.json"))

func volume_profile(kind: String) -> Dictionary:
	return volume_profiles.get(kind,{})

func footprint(row: Dictionary) -> Vector2:
	return footprint_rect(row).size

func footprint_rect(row: Dictionary) -> Rect2:
	var spec: Dictionary=preload("res://scripts/sleep_rules.gd").facility(row.kind)
	var bounds: Array=spec.get("vertical_collision_rect" if row.get("vertical",false) else "collision_rect",[])
	if bounds.size()==4: return Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
	var volume: Dictionary=volume_profile(str(row.kind))
	if volume.has("collision") and volume.collision.size()==4:
		var b: Array=volume.collision
		return Rect2(b[0],b[1],b[2],b[3])
	var size_value := Vector2(42,22)
	if not spec.is_empty():
		var extent: Array=spec.get("vertical_footprint",spec.footprint) if row.get("vertical",false) else spec.footprint
		size_value=Vector2(extent[0],extent[1])
	return Rect2(-size_value*.5,size_value)

static func valid_sign_text(value: Variant) -> bool:
	if not value is String or value!=value.strip_edges() or value.is_empty() or value.length()>6:return false
	for i in value.length():
		if value.unicode_at(i)<32 or value.unicode_at(i)==127:return false
	return true

func map_signposts() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for id in states:
		var row: Dictionary=states[id]
		if row.kind=="signpost":result.append(row)
	return result

func serialize() -> Dictionary:
	return {"version":1,"grid_version":1,"objects":states.duplicate(true),"abandoned_version":abandoned_version}

func validate(data: Variant, seen: Dictionary) -> bool:
	if not data is Dictionary or data.get("version")!=1 or data.get("grid_version")!=1 or not data.get("objects") is Dictionary: return false
	var version = data.get("abandoned_version",0)
	if not (version is int or version is float) or not is_finite(float(version)) or (version!=0 and version!=1): return false
	var occupied := {}
	for id in data.objects:
		var row = data.objects[id]
		if not id is String or id.is_empty() or not row is Dictionary or not definitions.has(row.get("kind","")): return false
		var d: Dictionary=definitions[row.kind]
		if row.has("abandoned") and not row.abandoned is bool: return false
		if row.get("abandoned",false) and (row.kind not in ["wood_fence","wood_floor","stone_path","wood_chest","workbench","straw_mat","wood_bed"] or row.open): return false
		if row.kind=="signpost" and not valid_sign_text(row.get("text")):return false
		if row.kind=="tilled_soil" and not service.planting.valid(row): return false
		if d.get("sleep",false):
			if row.get("sleep_state","PLACED") not in ["PLACED","RESERVED","IN_USE"] or row.get("facing",-1)!=0: return false
			if row.kind=="sleeping_bag" and row.get("vertical",false): return false
		for key in ["x","y","gx","gy","hits","facing"]:
			var n = row.get(key)
			if not (n is int or n is float) or not is_finite(float(n)): return false
		if row.x<0 or row.y<0 or row.x>service.world.generator.extent or row.y>service.world.generator.extent: return false
		if row.gx!=floor(row.gx) or row.gy!=floor(row.gy) or row.hits<0 or row.hits>=d.hits or row.hits!=floor(row.hits) or row.facing<0 or row.facing>3 or row.facing!=floor(row.facing): return false
		if row.get("layer")!=d.layer or not row.get("vertical") is bool or not row.get("open") is bool or not row.get("inward") is bool: return false
		var direction = row.get("swing",1)
		if not (direction is int or direction is float) or not is_finite(float(direction)) or absf(float(direction))!=1: return false
		if row.has("swing"): row.swing=int(direction)
		var hinge_value = row.get("hinge_end",0)
		if not (hinge_value is int or hinge_value is float) or not is_finite(float(hinge_value)) or float(hinge_value)<0 or float(hinge_value)>1 or float(hinge_value)!=floor(float(hinge_value)): return false
		if row.has("hinge_end"): row.hinge_end=int(hinge_value)
		if row.get("layer") in ["edge","ground","overlay"]:
			var k := str(d.layer)+":"+Grid.key(row,d.layer=="edge")
			if occupied.has(k): return false
			occupied[k]=true
			var p := Grid.snap(Vector2(row.x,row.y),d.layer=="edge",row.vertical)
			if p.gx!=row.gx or p.gy!=row.gy or not is_equal_approx(p.x,row.x) or not is_equal_approx(p.y,row.y): return false
		if not row.get("contents") is Array or row.contents.size()!=int(d.get("storage_slots",12)): return false
		if row.kind!="wood_chest" and not d.has("storage_slots") and row.contents.any(func(v): return not v is Dictionary or not v.is_empty()): return false
		if not service.industry.valid(row) or not service.expansion.valid(row):return false
		if row.has("machine"):
			for job in row.machine.jobs+row.machine.queue+row.machine.completed+row.machine.legacy_queue:
				if job.is_empty() or not job.output.has("instance_id"):continue
				var instance_id: String=str(job.output.instance_id)
				if seen.has(instance_id):return false
				seen[instance_id]=true
		if row.open and row.kind!="wood_chest" and not d.has("storage_slots") and not d.get("door",false): return false
		var inv := ItemInventory.new(service.database)
		var slots: Array=[]
		for i in 40: slots.append(row.contents[i] if i<row.contents.size() else {})
		if not inv.restore(slots): return false
		for v in inv.slots:
			if v.has("instance_id"):
				if seen.has(str(v.instance_id)): return false
				seen[str(v.instance_id)]=true
		for i in row.contents.size(): row.contents[i]=inv.slots[i]
		for key in ["gx","gy","hits","facing"]: row[key]=int(row[key])
	return true

func candidate(kind: String, at: Vector2, vertical: bool, inward: bool, facing: int) -> Dictionary:
	var d: Dictionary=definitions[kind]
	var row := Grid.snap(at,d.layer=="edge",vertical)
	if d.layer=="free": row.x=at.x;row.y=at.y
	row.merge({"kind":kind,"layer":d.layer,"open":false,"inward":inward,"facing":facing,"hits":0,"contents":[]})
	if d.get("sleep",false): row.facing=0;row.vertical=vertical if kind!="sleeping_bag" else false;row.sleep_state="PLACED"
	if kind=="tilled_soil": row.merge({"crop":"","growth_minutes":0.0,"roots":false});row.vertical=false
	for i in int(d.get("storage_slots",12)): row.contents.append({})
	if service.industry.machine(kind):row.machine=service.industry.initial(kind)
	if kind in service.expansion.KINDS:row.expansion=service.expansion.initial()
	return row

func occupant(row: Dictionary) -> String:
	if row.layer=="free": return ""
	var key := Grid.key(row,row.layer=="edge")
	for id in states:
		if states[id].layer==row.layer and Grid.key(states[id],row.layer=="edge")==key: return id
	return ""

func replacement(row: Dictionary) -> String:
	var id := occupant(row)
	if not id.is_empty() and definitions[row.kind].get("replaces","")==states[id].kind: return id
	return ""

func cost(row: Dictionary) -> Dictionary:
	var result: Dictionary=definitions[row.kind].cost.duplicate(true)
	var old := replacement(row)
	if not old.is_empty():
		for key in result.keys():
			result[key]=maxi(0,int(result[key])-int(definitions[states[old].kind].cost.get(key,0)))
			if result[key]==0: result.erase(key)
	return result

func paving_can_cover(node: Node) -> bool:
	# Only registered facilities are exempt; resources and unrelated colliders stay protected.
	var id := str(node.get_meta("building_id",""))
	if states.has(id):
		var existing: Dictionary=states[id]
		return existing.layer not in ["ground","edge"] or definitions[existing.kind].get("door",false)
	return service.camps.visuals.get(str(node.get_meta("prop_id","")))==node

func reason(row: Dictionary) -> String:
	if not definitions.has(row.get("kind","")) or not row.has_all(["x","y","layer","vertical"]): return "无效建造位置"
	if not service.writable: return "存档受保护，不能建造"
	if row.kind=="wool_carpet":
		var floor_found := false
		for base in states.values():
			if base.kind in ["wood_floor","stone_path"] and Grid.key(base,false)==Grid.key(row,false):floor_found=true;break
		if not floor_found:return "需要已有地板"
	if row.kind=="tilled_soil":
		if not service.inventory.has_capability("mine"): return "需要装备石镐开垦"
		if not service.body.can_labor("mine"): return "精力或体力不足，不能开垦"
	var at := Vector2(row.x,row.y)
	var world: Node=service.world
	if world.player.position.distance_to(at)>220: return "请靠近建造位置"
	if at.x<96 or at.y<96 or at.x>world.generator.extent-96 or at.y>world.generator.extent-96: return "请远离地图边界"
	if not world.stream.has_ground(at): return "请等待地面加载"
	if world.generator.corridor_distance(at)<24: return "请保留主要通道"
	var occupied := occupant(row)
	var replace_id := replacement(row)
	if not occupied.is_empty() and replace_id.is_empty(): return "此位置已有建筑"
	var paving: bool=row.kind in ["wood_floor","stone_path"]
	var offsets: Array=[Vector2.ZERO]
	if definitions[row.kind].get("sleep",false) or (row.layer=="free" and not volume_profile(str(row.kind)).is_empty()):
		var bounds := footprint_rect(row)
		var half := bounds.size*.5
		for xx in [-half.x,0,half.x]:
			for yy in [-half.y,0,half.y]: offsets.append(bounds.get_center()+Vector2(xx,yy))
	if row.layer in ["ground","overlay"]: offsets=[Vector2(-42,-26),Vector2(42,-26),Vector2(-42,26),Vector2(42,26),Vector2.ZERO]
	elif row.layer=="edge": offsets=[Vector2(0,-28),Vector2(0,28),Vector2.ZERO] if row.vertical else [Vector2(-44,0),Vector2(44,0),Vector2.ZERO]
	for offset in offsets:
		var p: Vector2=at+offset
		if not world.generator.can_walk(p,10) or world.generator.sample(p).z>.03: return "需要干燥陆地"
		if row.layer not in ["ground","overlay"] and world.player.position.distance_to(p)<22: return "请避开角色"
		for node in world.get_tree().get_nodes_in_group("world_interactables")+world.get_tree().get_nodes_in_group("trees"):
			if paving and paving_can_cover(node): continue
			if node.get_meta("building_id","")==replace_id and not replace_id.is_empty(): continue
			if node.get_meta("camp_layer","")=="ground": continue
			if definitions[row.kind].get("sleep",false) or (row.layer=="free" and not volume_profile(str(row.kind)).is_empty()):
				# Buildings use their real collider below, not a 40-unit halo at
				# each footprint sample (which rejected clear enclosed rooms).
				if not str(node.get_meta("building_id","")).is_empty(): continue
				var bounds := footprint_rect(row).grow(12)
				bounds.position+=at
				if bounds.has_point(node.position): return "请避开资源与设施"
				continue
			if p.distance_to(node.position)<(34 if row.layer=="ground" else 40 if row.layer=="free" else 24) and not (row.layer=="edge" and node.get_meta("camp_layer","")=="edge"): return "请避开资源与设施"
		var query := PhysicsPointQueryParameters2D.new();query.position=p;query.collision_mask=1
		for hit in world.get_world_2d().direct_space_state.intersect_point(query):
			var parent: Node=hit.collider.get_parent()
			if paving and paving_can_cover(parent): continue
			if parent.get_meta("camp_layer","")=="edge" and row.layer=="edge": continue
			if parent.get_meta("building_id","")==replace_id and not replace_id.is_empty(): continue
			return "附近有障碍"
	var footprint := RectangleShape2D.new()
	footprint.size=Vector2(84,52) if row.layer in ["ground","overlay"] else (Vector2(8,64) if row.vertical else Vector2(96,8)) if row.layer=="edge" else footprint(row)
	var area := PhysicsShapeQueryParameters2D.new();area.shape=footprint;area.transform=Transform2D(0,at)
	if row.layer=="free": area.transform.origin+=footprint_rect(row).get_center()
	for hit in world.get_world_2d().direct_space_state.intersect_shape(area,32):
		var parent: Node=hit.collider.get_parent()
		if paving and paving_can_cover(parent): continue
		if row.layer in ["ground","overlay"] and hit.collider is CharacterBody2D: continue
		if parent.get_meta("camp_layer","")=="edge" and row.layer in ["edge","ground","overlay"] and not paving: continue
		if not replace_id.is_empty() and parent.get_meta("building_id","")==replace_id: continue
		return "建筑占地与障碍重叠"
	for key in cost(row):
		if service.inventory.count_item(key)<int(cost(row)[key]): return "材料不足："+str(service.database.item(key).name)
	return ""

func place(row: Dictionary, expected: Array) -> String:
	if preload("res://scripts/network_game_route.gd").send(self,"building_place",[row,expected]):return ""
	if busy or service.body.sleep_active(): return "正在处理"
	if not preload("res://scripts/food_freshness.gd").matches_slots(service.inventory.slots,expected): return "背包已变化，请重新建造"
	var error := reason(row)
	if not error.is_empty(): return error
	if row.kind=="signpost" and not valid_sign_text(row.get("text")):return "请填写1至6个字的路标文字"
	busy=true
	var before := states.duplicate(true)
	var slots: Array=service.inventory.slots.duplicate(true)
	var paid: Dictionary=cost(row)
	var staged: ItemInventory=service.camps.consume(paid)
	if staged==null: busy=false;return "材料不足"
	var equip_before: Dictionary= service.inventory.equipment.duplicate(true)
	var links_before: Dictionary= service.inventory.hotbar_equipment.duplicate(true)
	var body_before: Dictionary=service.body.serialize()
	if row.kind=="tilled_soil":
		service.body.spend_labor("mine")
		service.inventory.wear_held(str(service.inventory.equipment.main_hand.instance_id),"mine")
	var old := replacement(row)
	var id := old if not old.is_empty() else "build:"+str(ResourceUID.create_id())
	states[id]=row.duplicate(true);service.inventory.slots=staged.slots;service.dirty=true
	if definitions[row.kind].get("door",false): states[id].swing=Grid.swing(states,states[id])
	if not service.save_state():
		states=before;service.inventory.slots=slots;service.inventory.equipment=equip_before;service.inventory.hotbar_equipment=links_before;service.body.restore(body_before);busy=false;return "保存失败，建造已回滚"
	refresh_around(row);service.inventory.changed.emit();busy=false
	AudioFX.build_placed(str(row.kind),Vector2(row.x,row.y))
	service.notify_build_cost(paid)
	return ""

func place_bag(row: Dictionary, index: int, expected: Dictionary) -> String:
	if preload("res://scripts/network_game_route.gd").send(self,"building_bag",[row,index,expected]):return ""
	if busy or service.body.sleep_active(): return "正在处理"
	if row.get("kind","")!="sleeping_bag": return "睡袋放置数据无效"
	if index<0 or index>=40 or service.inventory.slots[index]!=expected or expected.get("item_id")!="sleeping_bag": return "原物品已变化"
	var error := reason(row)
	if not error.is_empty(): return error
	busy=true
	var slots: Array=service.inventory.slots.duplicate(true)
	service.inventory.slots[index].count-=1
	if service.inventory.slots[index].count==0: service.inventory.slots[index]={}
	var id := "build:"+str(ResourceUID.create_id())
	states[id]=row.duplicate(true);service.dirty=true
	if not service.save_state():
		states.erase(id);service.inventory.slots=slots;busy=false;return "保存失败，放置已回滚"
	refresh_around(row);service.inventory.changed.emit();busy=false
	service.notify_build_cost({"sleeping_bag":1})
	return ""

func install(coord: Vector2i) -> void:
	for id in states:
		if service.world.stream.chunk_at(Vector2(states[id].x,states[id].y))!=coord or visuals.has(id): continue
		var node := preload("res://scripts/camp_building.gd").new()
		node.manager=self;node.building_id=id;node.position=Vector2(states[id].x,states[id].y)
		visuals[id]=node;service.world.object_root.add_child(node)

func unload(coord: Vector2i) -> void:
	for id in visuals.keys():
		if service.world.stream.chunk_at(visuals[id].position)==coord:
			visuals[id].queue_free();visuals.erase(id)

func refresh_all() -> void:
	for node in visuals.values():
		node.set_meta("spent",true);node.remove_from_group("world_interactables");node.queue_free()
	visuals.clear()
	for coord in service.world.stream.loaded: install(coord)

func refresh_around(row: Dictionary) -> void:
	var at := Vector2(row.x,row.y)
	var coords := {}
	coords[service.world.stream.chunk_at(at)]=true
	for id in visuals.keys():
		var node: Node2D=visuals[id]
		if node.position.distance_to(at)>160: continue
		coords[service.world.stream.chunk_at(node.position)]=true
		node.set_meta("spent",true);node.remove_from_group("world_interactables");node.queue_free();visuals.erase(id)
	for coord in coords:
		if service.world.stream.loaded.has(coord): install(coord)

func toggle(id: String) -> String:
	if preload("res://scripts/network_game_route.gd").send(self,"building_toggle",[id]):return ""
	if states.get(id,{}).get("abandoned",false): return "废弃设施无法使用"
	if busy or not service.writable or not states.has(id): return "暂不能操作"
	var row: Dictionary=states[id]
	if not definitions[row.kind].get("door",false): return "这不是门"
	var at := Vector2(row.x,row.y)
	if service.world.player.position.distance_to(at)>100: return "请靠近门"
	if visuals.has(id) and visuals[id].gate_tween and visuals[id].gate_tween.is_running(): return "门正在转动，请稍候"
	var old_swing: int=int(row.get("swing",1))
	var had_hinge := row.has("hinge_end")
	var old_hinge: int=int(row.get("hinge_end",0))
	if not row.open:
		var delta: Vector2=service.world.player.position-at
		var side: float=delta.x if row.vertical else -delta.y
		var preferred := (1 if side>=0 else -1) if absf(side)>.001 else old_swing*(1 if old_hinge==0 else -1)
		var found := false
		# Keep the existing hinge when clear. A vertical corner can use the opposite
		# fixed frame post before considering an opening toward the person.
		for desired_side in [preferred,-preferred]:
			for endpoint in ([old_hinge,1-old_hinge] if row.vertical else [old_hinge]):
				var swing_value: int=desired_side*(1 if endpoint==0 else -1)
				if not gate_blocked(id,swing_value,endpoint):
					row.swing=swing_value;row.hinge_end=endpoint;found=true;break
			if found: break
		if not found: return "门两侧都被挡住，请让开后再开门"
	elif gate_blocked(id): return "门板路径被挡住，请让开后再操作"
	row.open=not row.open;service.dirty=true
	if not service.save_state():
		row.open=not row.open;row.swing=old_swing
		if had_hinge: row.hinge_end=old_hinge
		else: row.erase("hinge_end")
		return "保存失败，门状态已回滚"
	AudioFX.play_sfx("sfx_door_open" if row.open else "sfx_door_close",at)
	if visuals.has(id): visuals[id].update_gate()
	return ""

func protected_reason(id: String) -> String:
	if states.has(id):
		if states[id].get("sleep_state","PLACED")!="PLACED": return "设施正在使用"
		if states[id].kind in ["wood_floor","stone_path"]:
			for over in states.values():
				if over.kind=="wool_carpet" and Grid.key(over,false)==Grid.key(states[id],false):return "请先拆除地毯"
		var expansion_reason: String=service.expansion.protected_reason(states[id])
		if not expansion_reason.is_empty():return expansion_reason
		if states[id].has("machine"):
			var m: Dictionary=states[id].machine
			if not m.feed.is_empty() or not m.queue.is_empty() or not m.completed.is_empty() or not m.legacy_queue.is_empty() or m.jobs.any(func(j):return not j.is_empty()):return "设施内还有物品"
		if not states[id].get("abandoned",false) and states[id].contents.any(func(v): return not v.is_empty()): return "请先清空木箱"
		return ""
	if service.camps.states.has(id):
		var row: Dictionary=service.camps.states[id]
		if row.fuel>0 or not row.recipe.is_empty() or row.ready: return "篝火中还有燃料或烹饪内容"
		return ""
	return "建筑不存在"

func strike(id: String, target: Node2D) -> bool:
	if busy or not service.writable or not service.inventory.has_capability("demolish"): return false
	var error := protected_reason(id)
	if not error.is_empty(): service.notice.emit(error);return false
	if not is_instance_valid(target) or str(target.get_meta("building_id",target.get("camp_id")))!=id: return false
	if not preload("res://scripts/world_interaction.gd").in_reach(service.world.stream,service.world.player.position,target): return false
	if target.get_meta("interaction_action","")!="sleep" and service.world.player.position.distance_to(target.position)>100: return false
	busy=true
	var camp: bool=service.camps.states.has(id)
	var row: Dictionary=service.camps.states[id] if camp else states[id]
	var d: Dictionary={"hits":3,"cost":{"wood":4,"stone":6,"flint":1}} if camp else definitions[row.kind]
	var before := row.duplicate(true)
	var inv: ItemInventory=service.inventory
	var equipment := inv.equipment.duplicate(true);var links := inv.hotbar_equipment.duplicate(true)
	var loose: Dictionary=service.loose.duplicate(true)
	var rewards: Array[Dictionary]=[]
	var hits := int(row.get("hits",0))+1
	if hits>=int(d.hits):
		for material in d.cost:
			var amount := floori(float(d.cost[material])*.5)
			if amount<1: continue
			var landing := Vector2.INF
			for i in 33:
				# The persisted root is the original building center; rings are safety fallbacks only.
				var p: Vector2=Vector2(row.x,row.y) if i==0 else Vector2(row.x,row.y)+Vector2.from_angle(TAU*(i-1)/16)*(48+32*((i-1)/16))
				if service.world.generator.can_walk(p,10) and service.world.stream.clear_reach(service.world.player.position,p,target): landing=p;break
			if landing==Vector2.INF: busy=false;service.notice.emit("附近没有安全的返料落点");return false
			var entry := {"id":id+":refund:"+str(material),"item_id":material,"count":amount,"x":landing.x,"y":landing.y,"mode":"pickup","origin":"demolition"}
			rewards.append(entry)
	if hits>=int(d.hits) and row.get("abandoned",false):
		for i in row.contents.size():
			var value: Dictionary=row.contents[i]
			if value.is_empty(): continue
			if rewards.is_empty(): busy=false;return false
			var landing: Dictionary=rewards[0]
			rewards.append({"id":id+":contents:"+str(i),"item_id":value.item_id,"count":value.count,"instance":value.duplicate(true),"x":landing.x,"y":landing.y,"mode":"pickup","origin":"abandoned_storage"})
	row.hits=hits
	var held: Dictionary=inv.equipment.main_hand
	inv.wear_held(str(held.instance_id),"demolish")
	if hits>=int(d.hits):
		if camp: service.camps.states.erase(id)
		else: states.erase(id)
		for entry in rewards: service.loose[entry.id]=entry
	service.dirty=true
	if not service.save_state():
		if camp: service.camps.states[id]=before
		else: states[id]=before
		inv.equipment=equipment;inv.hotbar_equipment=links;service.loose=loose
		inv.changed.emit();busy=false;return false
	if hits>=int(d.hits):
		if camp:
			service.camps.visuals.erase(id);service.camps.rebuild();target.queue_free()
		else: refresh_around(before)
		for entry in rewards:
			# Animation is transient: reloads restore settled drops without replaying it.
			var animated: Dictionary=entry.duplicate(true)
			animated["drop_animation"]=true
			service.world.stream.create_item_drop(animated)
	else:
		if target.has_method("update_damage"): target.update_damage()
		target.modulate=Color(.84,.78,.68);target.create_tween().tween_property(target,"modulate",Color.WHITE,.18)
	AudioFX.play_sfx("sfx_demolish_hit",Vector2(before.x,before.y))
	inv.changed.emit();busy=false;return true

func set_chest_open(id: String, opened: bool) -> String:
	if preload("res://scripts/network_game_route.gd").send(self,"building_open",[id,opened]):return ""
	if states.get(id,{}).get("abandoned",false): return "废弃设施无法使用"
	if busy or not service.writable or not states.has(id) or not storage_kind(str(states[id].kind)): return "木箱不可用"
	if opened and service.world.player.position.distance_to(Vector2(states[id].x,states[id].y))>100: return "请靠近木箱"
	var before: Dictionary={}
	for key in states:
		if storage_kind(str(states[key].kind)):
			before[key]=states[key].open
			if opened: states[key].open=key==id
	states[id].open=opened
	busy=true;service.dirty=true
	if not service.save_state():
		for key in before: states[key].open=before[key]
		busy=false;return "保存失败，木箱状态已回滚"
	for key in before:
		if before[key]!=states[key].open:
			var prefix := "sfx_fridge_" if states[key].kind=="refrigerator" else "sfx_chest_"
			AudioFX.play_sfx(prefix+("open" if states[key].open else "close"),Vector2(states[key].x,states[key].y))
		if is_instance_valid(visuals.get(key)): visuals[key].queue_redraw()
	busy=false;return ""

func transfer(id: String, chest_index: int, player_index: int, expected_chest: Dictionary, expected_player: Dictionary) -> String:
	if preload("res://scripts/network_game_route.gd").send(self,"building_transfer",[id,chest_index,player_index,expected_chest,expected_player]):return ""
	if states.get(id,{}).get("abandoned",false): return "废弃设施无法使用"
	if busy or not service.writable or not states.has(id): return "木箱不可用"
	if not storage_kind(str(states[id].kind)) or chest_index<0 or chest_index>=states[id].contents.size() or player_index<0 or player_index>=43: return "物品格无效"
	if service.world.player.position.distance_to(Vector2(states[id].x,states[id].y))>100: return "请靠近木箱"
	var inv: ItemInventory=service.inventory
	var contents: Array=states[id].contents
	if not preload("res://scripts/food_freshness.gd").matches(contents[chest_index],expected_chest) or not preload("res://scripts/food_freshness.gd").matches(inv.get_slot(player_index),expected_player): return "物品已变化，请重新拖动"
	if states[id].kind=="wood_chest" and chest_index>=9 and not expected_player.is_empty(): return "旧箱附加格仅供取回物品"
	if player_index<40 and inv.hotbar_equipment.has(str(player_index)):
		for i in range(40,43):
			if inv.get_slot(i).get("instance_id","")==expected_player.get("instance_id",""): player_index=i;break
	if states[id].kind=="refrigerator" and not expected_player.is_empty() and service.database.item(str(expected_player.item_id)).get("food_kind","") not in ["raw","raw_fish","cooked"]:return "冰箱只能存放食物"
	if not inv.accepts(player_index,expected_chest): return "这个装备槽不能放入箱内物品"
	busy=true
	var a: Dictionary=contents[chest_index].duplicate(true)
	var b: Dictionary=inv.get_slot(player_index).duplicate(true)
	var old_equipment := inv.equipment.duplicate(true);var old_links := inv.hotbar_equipment.duplicate(true)
	if not a.is_empty() and not b.is_empty() and preload("res://scripts/food_freshness.gd").same(a,b):
		var take := mini(int(b.count),int(service.database.item(a.item_id).max_stack)-int(a.count))
		if take==0: busy=false;return "这一格已满"
		contents[chest_index].count+=take;inv.slots[player_index].count-=take
		if inv.slots[player_index].count==0: inv.slots[player_index]={}
	else:
		contents[chest_index]=b;inv.set_slot(player_index,a)
		if player_index>=40:
			if a.is_empty(): inv.equipment.erase(inv.slot_key(player_index))
			for key in inv.hotbar_equipment.keys():
				if inv.hotbar_equipment[key]==b.get("instance_id",""): inv.hotbar_equipment.erase(key)
	service.dirty=true
	if not service.save_state():
		contents[chest_index]=a;inv.set_slot(player_index,b);inv.equipment=old_equipment;inv.hotbar_equipment=old_links
		busy=false;return "保存失败，转移已回滚"
	AudioFX.play_sfx("sfx_equip" if player_index>=40 else "sfx_item_move")
	inv.changed.emit();busy=false;return ""

func chest_edit(id: String, source: int, expected: Dictionary, action: String, target: int = -1, quantity: int = 0) -> String:
	if preload("res://scripts/network_game_route.gd").send(self,"building_edit",[id,source,expected,action,target,quantity]):return ""
	if states.get(id,{}).get("abandoned",false): return "废弃设施无法使用"
	if busy or not service.writable or not states.has(id) or not storage_kind(str(states[id].kind)) or source<0 or source>=states[id].contents.size(): return "木箱不可用"
	if service.world.player.position.distance_to(Vector2(states[id].x,states[id].y))>100: return "请靠近木箱"
	var contents: Array=states[id].contents
	if not preload("res://scripts/food_freshness.gd").matches(contents[source],expected) or expected.is_empty(): return "原物品已变化"
	expected=contents[source].duplicate(true)
	var before: Array=contents.duplicate(true)
	var body: Dictionary=service.body.serialize()
	var old_slots: Array=service.inventory.slots.duplicate(true)
	var definition: Dictionary=service.database.item(expected.item_id)
	if action=="use" and definition.get("equippable",false):
		var equip_index := -1
		for i in range(40,43):
			if service.inventory.slot_key(i)==definition.get("equip_slot",""): equip_index=i;break
		if equip_index<0: return "装备槽无效"
		return transfer(id,source,equip_index,expected,service.inventory.get_slot(equip_index).duplicate(true))
	match action:
		"destroy": contents[source]={}
		"split":
			if quantity<1 or quantity>=int(expected.count): return "拆分数量须小于原数量"
			var empty := -1
			for i in storage_capacity(id):
				if contents[i].is_empty(): empty=i;break
			if empty<0: return "木箱已满，无法拆分"
			contents[empty]=expected.duplicate(true);contents[empty].count=quantity;contents[source].count-=quantity
		"move":
			if target<0 or target>=storage_capacity(id) or target==source: return ""
			var other: Dictionary=contents[target]
			if source>=storage_capacity(id) and not other.is_empty(): return "请将旧箱物品拖到空格取回"
			if not other.is_empty() and preload("res://scripts/food_freshness.gd").same(other,expected):
				var amount := mini(int(expected.count),int(definition.max_stack)-int(other.count))
				if amount<=0: return "物品格已满"
				other.count+=amount;contents[source].count-=amount
				if contents[source].count==0: contents[source]={}
			else: contents[target]=contents[source];contents[source]=other
		"use":
			if definition.get("use_action","")=="unpack":
				var staged := ItemInventory.new(service.database);staged.slots=old_slots.duplicate(true)
				for reward in definition.get("contents",{}):
					if staged.add(reward,int(definition.contents[reward]))>0: return "背包空间不足，补给包保留在箱内"
				service.inventory.slots=staged.slots
			elif definition.get("use_action","")=="eat":
				if not service.body.can_eat(preload("res://scripts/food_freshness.gd").effects(service.database,expected)): return "现在无法食用"
				service.body.eat(preload("res://scripts/food_freshness.gd").effects(service.database,expected))
			else: return "请取出到背包后使用"
			contents[source].count-=1
			if contents[source].count==0: contents[source]={}
		_: return "操作无效"
	busy=true;service.dirty=true
	if not service.save_state():
		states[id].contents=before;service.body.restore(body);service.inventory.slots=old_slots;busy=false;return "保存失败，操作已回滚"
	if action=="use" and definition.get("use_action","")=="eat":AudioFX.play_sfx("sfx_eat")
	elif action in ["move","split"]:AudioFX.play_sfx("sfx_item_move")
	service.inventory.changed.emit();busy=false;return ""

# Sample the projected leaf swept polygon, separately from the 100-unit interaction reach.
# 90 one-degree steps and a one-unit margin cover the sub-pixel angular gaps.
func gate_blocked(id: String, swing_override: int=0, hinge_override: int=-1) -> bool:
	var row: Dictionary=states[id].duplicate(true)
	if swing_override!=0: row.swing=swing_override
	if hinge_override>=0: row.hinge_end=hinge_override
	var origin := Vector2(row.x,row.y)
	var hinge := Grid.gate_hinge(row)
	var base := Grid.gate_base(row)
	var current := base+(PI*.5*int(row.get("swing",1)) if row.open else 0.0)
	var goal := base if row.open else base+PI*.5*int(row.get("swing",1))
	for i in 91:
		var angle := lerpf(current,goal,i/90.0)
		var tip := hinge+Vector2(cos(angle)*96,sin(angle)*64)
		var normal := (tip-hinge).normalized().orthogonal()*5
		var polygon := ConvexPolygonShape2D.new()
		# The hinge socket is fixed frame, not swept leaf area. Only exempt this 12-unit socket,
		# never exempt a complete adjoining wall which may actually block the open leaf.
		var start := hinge.move_toward(tip,12)
		var end := tip.move_toward(hinge,6)
		polygon.points=PackedVector2Array([start-normal,end-normal,end+normal,start+normal])
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape=polygon;query.transform=Transform2D(0,origin);query.collision_mask=1
		query.exclude=[service.world.player.get_rid()]
		if visuals.has(id): query.exclude=[service.world.player.get_rid(),visuals[id].body.get_rid()]
		# Explicit feet check also works immediately after an actor teleport, before physics sync.
		var feet: Vector2=service.world.player.position-origin
		if Geometry2D.get_closest_point_to_segment(feet,hinge,tip).distance_to(feet)<14: return true
		for hit in service.world.get_world_2d().direct_space_state.intersect_shape(query,64):
			var parent: Node=hit.collider.get_parent()
			var other_id: String=parent.get_meta("building_id","")
			# A leaf may fold onto directly joined fixed walls/fences (H / T layouts).
			# Keep every actor, facility, other door and non-joined barrier blocking.
			if states.has(other_id):
				var other: Dictionary=states[other_id]
				if other.kind in ["stone_wall","wood_fence"] and Grid.ends(other).any(func(v): return Grid.ends(row).has(v)): continue
			return true
	return false


func storage_kind(kind: String) -> bool:
	return kind=="wood_chest" or definitions.get(kind,{}).has("storage_slots")

func storage_capacity(id: String) -> int:
	return 9 if states[id].kind=="wood_chest" else int(definitions[states[id].kind].get("storage_slots",12))
