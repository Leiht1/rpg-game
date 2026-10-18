class_name WildStream
extends Node2D

const Gen = preload("res://scripts/world_generator.gd")
const Ground = preload("res://scripts/ground_decals.gd")
const Prop = preload("res://scripts/scenery_prop.gd")
const Scenery = preload("res://scripts/scenery_catalog.gd")
const GroundingMask = preload("res://scripts/grounding_mask.gd")
const Canopy = preload("res://scripts/canopy_shadows.gd")
const PROP_SHADER = preload("res://scripts/grounded_prop.gdshader")
const TERRAIN_SHADER = preload("res://scripts/terrain.gdshader")
const ART_VERSION := "scene-contact-1.0.0"
const FILES := ["tree_0","tree_1","rock_0","rock_1","tuft_0","tuft_1","tuft_2"]
var candidate_mode := 0
var preview_enabled := false
var preview_center:=Vector2.ZERO
var generator: WildGenerator
var object_root: Node2D
var loaded := {}
var tasks := {}
var ready_data: Array[Dictionary] = []
var requested: Array[Vector2i] = []
var mutex := Mutex.new()
var textures: Array[Texture2D] = []
var scenery_textures := {}
var ground_atlas: Texture2D
var shared_material := ShaderMaterial.new()
var prop_material := ShaderMaterial.new()
var target_center := Vector2i(-999,-999)
var keep_radius := 2
var object_count := 0
var total_loaded := 0
var total_unloaded := 0
var last_build_ms := 0.0
var last_install_ms := 0.0
var last_grounding_refresh_ms := 0.0
var max_install_ms := 0.0
var quitting := false
var harvested := {}
var tree_hits := {}
var drops: Array[Node2D]=[]
var collected_wood := 0
var items: Node

func configure(gen: WildGenerator, sort_root: Node2D) -> void:
	generator=gen
	ground_atlas=load("res://assets/environment/ground_v03/ground_atlas.png")
	object_root=sort_root
	prop_material.shader=PROP_SHADER
	var ground_copy:=BackBufferCopy.new()
	ground_copy.name="PureGroundColorCopy"
	ground_copy.z_index=-1
	ground_copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(ground_copy)
	for file in FILES:
		var folder := "view_v01" if file.begins_with("tree_") or file.begins_with("rock_") else "stylized_v3"
		textures.append(load("res://assets/environment/%s/%s.png"%[folder,file]))
	for id in Scenery.IDS:
		for surface in ["grass","forest","dirt"]:
			var key:String=id+"_"+surface
			scenery_textures[key]=load("res://assets/environment/contact_v01/"+key+".png")
	shared_material.shader=TERRAIN_SHADER
	shared_material.set_shader_parameter("spawn_tex",load("res://assets/environment/stylized_v3/grass.png"))
	shared_material.set_shader_parameter("ground_origin",generator.spawn)
	for pair in [["forest_tex","forest"],["rock_tex","highland"],["meadow_tex","open_field"],["shore_tex","shore"]]:
		shared_material.set_shader_parameter(pair[0],load("res://assets/environment/biome_v02/"+pair[1]+".png"))

func chunk_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/Gen.CHUNK_PX),floori(p.y/Gen.CHUNK_PX))

func valid_chunk(c: Vector2i) -> bool:
	var side := ceili(float(generator.map_cells)/Gen.CHUNK_CELLS)
	return c.x>=0 and c.y>=0 and c.x<side and c.y<side

func update_target(p: Vector2) -> void:
	var center := chunk_at(p)
	if center==target_center: return
	target_center=center
	requested.clear()
	for y in range(-keep_radius,keep_radius+1):
		for x in range(-keep_radius,keep_radius+1):
			var c := center+Vector2i(x,y)
			if valid_chunk(c) and not loaded.has(c) and not tasks.has(c): requested.append(c)
	requested.sort_custom(func(a,b): return Vector2(a-center).length_squared()<Vector2(b-center).length_squared())
	for c in loaded.keys():
		if absi(c.x-center.x)>keep_radius+1 or absi(c.y-center.y)>keep_radius+1:
			unload_chunk(c)

func _process(_delta: float) -> void:
	if generator==null or quitting: return
	# Reap only completed workers; never wait on unfinished work in a frame.
	for c in tasks.keys():
		if WorkerThreadPool.is_task_completed(tasks[c]):
			WorkerThreadPool.wait_for_task_completion(tasks[c])
			tasks.erase(c)
	while tasks.size()<2 and not requested.is_empty():
		var c: Vector2i=requested.pop_front()
		if not loaded.has(c): tasks[c]=WorkerThreadPool.add_task(_generate.bind(c),false,"原野区块")
	var packet: Dictionary={}
	mutex.lock()
	if not ready_data.is_empty(): packet=ready_data.pop_front()
	mutex.unlock()
	if not packet.is_empty():
		var c: Vector2i=packet.coord
		if absi(c.x-target_center.x)<=keep_radius+1 and absi(c.y-target_center.y)<=keep_radius+1 and not loaded.has(c):
			install_chunk(packet)

func _generate(coord: Vector2i) -> void:
	# Each worker owns its noises; no RenderingServer or scene nodes here.
	var local_gen := Gen.new(generator.world_seed,generator.map_cells,generator.plan_snapshot())
	var packet := local_gen.build_chunk(coord)
	var mask_start:=Time.get_ticks_usec()
	# Worker uses only immutable generator data. Harvested edits are reconciled on install.
	packet["grounding_mask"]=GroundingMask.build(local_gen,coord,{})
	packet["build_ms"]+=(Time.get_ticks_usec()-mask_start)/1000.0
	var empty_stamps:Array[Dictionary]=[] # Approved surface replaces legacy stamps.
	packet["ground_stamps"]=empty_stamps
	if items:
		packet["resource_distribution"]=items.build_distribution(local_gen,items.rules,items.reachable,coord)
	mutex.lock()
	ready_data.append(packet)
	mutex.unlock()

func install_chunk(packet: Dictionary) -> void:
	var start := Time.get_ticks_usec()
	var coord: Vector2i=packet.coord
	var terrain := Sprite2D.new()
	terrain.texture=ImageTexture.create_from_image(packet.image)
	terrain.centered=false
	terrain.z_index=-2
	var padding:float = (packet.image.get_width()-Gen.TEX_RES)/2
	terrain.region_enabled=true
	terrain.region_rect=Rect2(padding,padding,Gen.TEX_RES,Gen.TEX_RES)
	terrain.position=Vector2(coord)*Gen.CHUNK_PX
	terrain.scale=Vector2.ONE*Gen.TEX_STEP
	var material:=shared_material.duplicate() as ShaderMaterial
	material.set_shader_parameter("environment_tex",ImageTexture.create_from_image(packet.environment))
	material.set_shader_parameter("chunk_origin",Vector2(coord)*Gen.CHUNK_PX)
	var mask:Image
	if packet.has("grounding_mask") and harvested.is_empty():mask=packet.grounding_mask
	else:mask=GroundingMask.build(generator,coord,harvested)
	material.set_shader_parameter("grounding_mask",ImageTexture.create_from_image(mask))
	terrain.material=material
	add_child(terrain)
	var ground=Ground.new()
	ground.z_index=-1
	ground.configure(coord,ground_atlas,packet.ground_stamps)
	add_child(ground)
	var body := StaticBody2D.new()
	body.position=Vector2(coord)*Gen.CHUNK_PX
	add_child(body)
	var props: Array[Node2D]=[]
	for entry in packet.props:
		if harvested.has(entry.id): continue
		var prop := Prop.new()
		prop.name=("EnvTree_" if entry.kind<2 else "EnvRock_" if entry.kind<4 else "Decoration_")+entry.id.replace(":","_")
		prop.set_meta("prop_id",entry.id)
		prop.kind=entry.kind
		prop.candidate_mode=1 # Tight contact shadow, no legacy grass blades/soil halo.
		if entry.kind>=4:
			prop.visible=entry.position.distance_to(generator.spawn)>160 and (str(entry.id).begins_with("clearing:") or generator.random_at(roundi(entry.position.x),roundi(entry.position.y),682)<.20)
		prop.detail_seed=generator.random_at(roundi(entry.position.x),roundi(entry.position.y),93)
		if entry.kind<4:
			var appearance:Dictionary=Scenery.appearance(generator,entry)
			prop.variant_id=appearance.id;prop.surface=appearance.surface
			prop.texture=scenery_textures[appearance.id+"_"+appearance.surface]
		else:prop.texture=textures[entry.kind]
		prop.position=entry.position
		prop.display_size=Vector2(prop.texture.get_size())*entry.scale
		if entry.kind<4:
			prop.prepare()
			prop.shadow_changed.connect(_refresh_canopy.bind(1.,coord))
		object_root.add_child(prop)
		props.append(prop)
		if entry.kind<4:
			prop.add_to_group("trees" if entry.kind<2 else "rocks")

	loaded[coord]={"terrain":terrain,"ground":ground,"body":body,"props":props}
	var crown=Canopy.new()
	crown.name="GroundCanopy_%d_%d"%[coord.x,coord.y]
	crown.z_index=-1
	crown.props=props
	add_child(crown)
	loaded[coord]["canopy"]=crown
	if preview_enabled:
		var layer=load("res://scripts/ground_candidate.gd").new()
		layer.z_index=-1
		layer.configure(generator,coord,packet.props,preview_center)
		add_child(layer)
		loaded[coord]["candidate"]=layer
		apply_candidate(coord)
	# Stable compositing order even when worker completion order changes.
	var ordered:=loaded.keys()
	ordered.sort_custom(func(a,b):return a.y<b.y or (a.y==b.y and a.x<b.x))
	for key in ordered:move_child(loaded[key].ground,get_child_count()-1)
	object_count+=props.size()
	if items:
		if packet.has("resource_distribution"):
			items.chunk_cache[coord]=packet.resource_distribution
			items.generation_ms=packet.resource_distribution.ms
		items.install_chunk(coord)
	total_loaded+=1
	last_build_ms=packet.build_ms
	last_install_ms=(Time.get_ticks_usec()-start)/1000.0
	max_install_ms=maxf(max_install_ms,last_install_ms)

func unload_chunk(coord: Vector2i) -> void:
	if items: items.release_cache(coord)
	for drop in drops.duplicate():
		if is_instance_valid(drop) and chunk_at(drop.position)==coord:
			drops.erase(drop)
			drop.queue_free()
	for ore in get_tree().get_nodes_in_group("harvest_visuals"):
		if ore.get_meta("ore_id","")!="" and chunk_at(ore.position)==coord: ore.queue_free()
	var entry: Dictionary=loaded[coord]
	object_count-=entry.props.size()
	if entry.has("candidate"): entry.candidate.queue_free()
	entry.canopy.queue_free()
	entry.terrain.queue_free()
	entry.ground.queue_free()
	entry.body.queue_free()
	for prop in entry.props: prop.queue_free()
	loaded.erase(coord)
	total_unloaded+=1

func has_ground(p: Vector2) -> bool:
	return loaded.has(chunk_at(p))

func viewport_ready(p: Vector2, half_view: Vector2) -> bool:
	var lo := chunk_at(p-half_view-Vector2(180,280))
	var hi := chunk_at(p+half_view+Vector2(180,180))
	for y in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			var c:=Vector2i(x,y)
			if valid_chunk(c) and not loaded.has(c): return false
	return true

func _exit_tree() -> void:
	quitting=true
	for id in tasks.values(): WorkerThreadPool.wait_for_task_completion(id)

func interaction_target(at: Vector2, facing: String = "front", pointer: Vector2 = Vector2.INF) -> Node2D:
	return preload("res://scripts/world_interaction.gd").target(self,at,facing,pointer)

func tree_in_reach(at: Vector2, tree: Node2D) -> bool:
	return is_instance_valid(tree) and tree.is_in_group("trees") and at.distance_to(tree.position)<62 and clear_reach(at,tree.position,tree)

func clear_reach(from: Vector2,to: Vector2,target: Node2D=null) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from,to)
	query.exclude=[]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return true
	# The actor itself is ignored by starting the ray outside its ten-pixel feet.
	query.from=from+(to-from).normalized()*12
	hit=get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (target!=null and hit.collider.get_parent()==target)

func chop_tree(tree: Node2D) -> void:
	if not is_instance_valid(tree) or not tree.is_in_group("trees"): return
	if items and not items.inventory.has_capability("chop"): return
	var id: String=tree.get_meta("prop_id")
	if harvested.has(id): return
	if items and not items.body.can_labor("chop",items.world.player.action=="chop"): return
	if items: items.body.spend_labor("chop")
	tree_hits[id]=int(tree_hits.get(id,0))+1
	tree.hit()
	if items:
		var held: Dictionary=items.inventory.equipment.get("main_hand",{})
		items.inventory.wear_held(str(held.get("instance_id","")),"chop")
	if items: items.dirty=true
	var required:int=tree.required_hits
	var hits := int(tree_hits[id])
	if hits%2==0:
		spawn_drop(tree.position+Vector2(-28 if hits==2 else 28,18),id+":hit%d"%hits)
	if hits<required: return
	harvested[id]=true
	call_deferred("refresh_grounding",tree.position)
	tree.remove_from_group("trees")
	tree.fade_out()
	if items: items.save_state()

func _refresh_canopy(_alpha:float,coord:Vector2i)->void:
	if loaded.has(coord):loaded[coord].canopy.queue_redraw()

func refresh_grounding(at:Vector2)->void:
	var start:=Time.get_ticks_usec()
	var center:=chunk_at(at)
	for y in range(center.y-1,center.y+2):
		for x in range(center.x-1,center.x+2):
			var c:=Vector2i(x,y)
			if loaded.has(c) and Rect2(Vector2(c)*Gen.CHUNK_PX,Vector2.ONE*Gen.CHUNK_PX).grow(124.).has_point(at):
				var mask:=GroundingMask.build(generator,c,harvested)
				loaded[c].terrain.material.set_shader_parameter("grounding_mask",ImageTexture.create_from_image(mask))
	last_grounding_refresh_ms=(Time.get_ticks_usec()-start)/1000.0

func spawn_drop(at: Vector2,id: String) -> Node2D:
	if items:
		if items.consumed.has(id): return null
		var entry := {"id":id,"item_id":"wood","count":4+int(abs(id.hash())%3),"x":at.x,"y":at.y}
		items.loose[id]=entry
		return create_item_drop(entry)
	var entry := {"id":id,"item_id":"wood","count":1,"x":at.x,"y":at.y}
	return create_item_drop(entry)

func create_item_drop(entry: Dictionary) -> Node2D:
	for existing in drops:
		if is_instance_valid(existing) and existing.get_meta("drop_id","")==str(entry.id): return existing
	var gathered: bool = items!=null and not entry.get("natural",false) and items.rules.resources.get(str(entry.item_id),{}).get("mode","")=="harvest"
	# Gathered goods are small loose objects, not a replanted bush or whole plant.
	var tex: Texture2D = items.texture(str(entry.item_id),"loose" if gathered else "world") if items else load("res://assets/environment/cartoon_v2/wood.png")
	var drop: Node2D
	if tex:
		var object := preload("res://scripts/item_drop.gd").new()
		var width := 20.0 if gathered else float(items.database.item(entry.item_id).world_size) if items else float(tex.get_width())
		object.setup(tex,width,8.0 if tex is AtlasTexture else 0.0)
		drop=object
	else:
		var marker := preload("res://scripts/resource_marker.gd").new()
		marker.caption=items.database.item(entry.item_id).name
		marker.growing=entry.get("mode","pickup")=="harvest"
		marker.tint=Color("b5cf90") if marker.growing else Color("e7c48e")
		drop=marker
	drop.name="Resource_"+str(entry.id).replace(":","_")
	drop.position=Vector2(entry.x,entry.y)
	if entry.has("instance"): drop.set_meta("instance",entry.instance.duplicate(true))
	for key in ["item_id","count","natural"]: drop.set_meta(key,entry.get(key,false if key=="natural" else 1))
	drop.set_meta("mode",entry.get("mode","pickup"))
	drop.set_meta("origin",entry.get("origin","natural" if entry.get("natural",false) else "drop"))
	drop.set_meta("drop_id",str(entry.id))
	drop.add_to_group("drops")
	object_root.add_child(drop)
	drops.append(drop)
	if entry.get("drop_animation",false) and drop.has_method("animate_drop"): drop.animate_drop()
	return drop

func pickup_drop(drop: Node2D) -> bool:
	if not is_instance_valid(drop) or drop.get_meta("collected",false): return false
	if items:
		return items.pickup(drop)
	drop.set_meta("collected",true)
	drops.erase(drop)
	collected_wood+=1
	drop.queue_free()
	return true

func set_candidate(mode:int)->void:
	candidate_mode=mode
	shared_material.set_shader_parameter("candidate_mode",mode)
	shared_material.set_shader_parameter("preview_center",preview_center)
	for c in loaded: apply_candidate(c)

func apply_candidate(c:Vector2i)->void:
	var entry:Dictionary=loaded[c]
	if not entry.has("candidate"):return
	entry.candidate.mode=candidate_mode
	entry.candidate.queue_redraw()
	# Keep the legacy map elsewhere and all original art available with key 1.
	entry.ground.preview_mode=candidate_mode
	entry.ground.preview_center=preview_center
	entry.ground.queue_redraw()
	for prop in entry.props:
		if prop.position.distance_to(preview_center)<1350:
			prop.candidate_mode=candidate_mode
			prop.visible=not (candidate_mode>0 and prop.kind>=4)
			prop.queue_redraw()

func move_preview_center(p:Vector2)->void:
	preview_center=p
	for c in loaded:
		var entry:Dictionary=loaded[c]
		entry.candidate.queue_free()
		var layer=load("res://scripts/ground_candidate.gd").new()
		layer.z_index=-1
		layer.configure(generator,c,generator.props_for_chunk(c),p)
		add_child(layer)
		entry.candidate=layer
		for prop in entry.props:
			prop.candidate_mode=0
			prop.visible=true
			prop.queue_redraw()
	set_candidate(candidate_mode)



