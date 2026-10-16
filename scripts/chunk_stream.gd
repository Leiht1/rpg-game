class_name WildStream
extends Node2D

const Gen = preload("res://scripts/world_generator.gd")
const Ground = preload("res://scripts/ground_decals.gd")
const Prop = preload("res://scripts/nature_prop.gd")
const TERRAIN_SHADER = preload("res://scripts/terrain.gdshader")
const ART_VERSION := "scene-view-0.2.0"
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
var ground_atlas: Texture2D
var shared_material := ShaderMaterial.new()
var target_center := Vector2i(-999,-999)
var keep_radius := 2
var object_count := 0
var total_loaded := 0
var total_unloaded := 0
var last_build_ms := 0.0
var last_install_ms := 0.0
var max_install_ms := 0.0
var quitting := false
var harvested := {}
var tree_hits := {}
var drops: Array[Node2D]=[]
var collected_wood := 0

func configure(gen: WildGenerator, sort_root: Node2D) -> void:
	generator=gen
	ground_atlas=load("res://assets/environment/ground_v03/ground_atlas.png")
	object_root=sort_root
	for file in FILES:
		var folder := "view_v01" if file.begins_with("tree_") or file.begins_with("rock_") else "stylized_v3"
		textures.append(load("res://assets/environment/%s/%s.png"%[folder,file]))
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
	var empty_stamps:Array[Dictionary]=[] # Approved surface replaces legacy stamps.
	packet["ground_stamps"]=empty_stamps
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
		prop.texture=textures[entry.kind]
		prop.position=entry.position
		prop.display_size=Vector2(prop.texture.get_size())*entry.scale
		object_root.add_child(prop)
		props.append(prop)
		if entry.kind<4:
			prop.add_to_group("trees" if entry.kind<2 else "rocks")
			var obstacle := StaticBody2D.new()
			obstacle.name="FootprintBody"
			prop.add_child(obstacle)
			var shape := CollisionPolygon2D.new()
			shape.name="Footprint"
			var points: PackedVector2Array
			if entry.kind<2:
				points=PackedVector2Array([Vector2(-18,-3),Vector2(-14,-14),Vector2(13,-14),Vector2(19,-4),Vector2(14,5),Vector2(-12,6)])
			else:
				var w: float=prop.display_size.x*.46
				var h: float=prop.display_size.y*.27
				points=PackedVector2Array([Vector2(-w*.95,-h*.3),Vector2(-w*.7,-h),Vector2(w*.55,-h*1.1),Vector2(w,-h*.25),Vector2(w*.75,4),Vector2(-w*.55,7)])
			if entry.kind<2:
				for i in points.size(): points[i]*=entry.scale
			shape.polygon=points
			obstacle.add_child(shape)
	loaded[coord]={"terrain":terrain,"ground":ground,"body":body,"props":props}
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
	total_loaded+=1
	last_build_ms=packet.build_ms
	last_install_ms=(Time.get_ticks_usec()-start)/1000.0
	max_install_ms=maxf(max_install_ms,last_install_ms)

func unload_chunk(coord: Vector2i) -> void:
	var entry: Dictionary=loaded[coord]
	object_count-=entry.props.size()
	if entry.has("candidate"): entry.candidate.queue_free()
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

func interaction_target(at: Vector2) -> Node2D:
	var best: Node2D
	var distance := INF
	for drop in drops:
		if not is_instance_valid(drop) or drop.get_meta("collected",false): continue
		var offset := drop.position-at
		if offset.length()<42 and absf(offset.y)<30 and offset.length()<distance and clear_reach(at,drop.position):
			best=drop
			distance=offset.length()
	if best!=null: return best
	for tree in get_tree().get_nodes_in_group("trees"):
		var offset: Vector2=tree.position-at
		if tree_in_reach(at,tree) and offset.length()<distance:
			best=tree
			distance=offset.length()
	return best

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
	var id: String=tree.get_meta("prop_id")
	if harvested.has(id): return
	tree_hits[id]=int(tree_hits.get(id,0))+1
	var tween:=create_tween()
	tween.tween_property(tree,"rotation",.025,.07)
	tween.tween_property(tree,"rotation",0.0,.12)
	# tree_0 is the broad large tree; tree_1 is the smaller slender tree.
	var required := 4 if tree.kind==0 else 2
	var hits := int(tree_hits[id])
	if hits%2==0:
		spawn_drop(tree.position+Vector2(-28 if hits==2 else 28,18),id+":hit%d"%hits)
	if hits<required: return
	harvested[id]=true
	tree.remove_from_group("trees")
	tree.get_node("FootprintBody").queue_free()
	tween.tween_property(tree,"modulate:a",0.0,.3)
	# Hide but retain the streamed node until chunk unload; no stale array references.
	tween.tween_callback(tree.hide)

func spawn_drop(at: Vector2,id: String) -> Node2D:
	var drop := Sprite2D.new()
	drop.name="DropWood_"+id.replace(":","_")
	drop.texture=load("res://assets/environment/cartoon_v2/wood.png")
	drop.position=at
	drop.offset=Vector2(0,-5)
	drop.add_to_group("drops")
	object_root.add_child(drop)
	drops.append(drop)
	return drop

func pickup_drop(drop: Node2D) -> void:
	if not is_instance_valid(drop) or drop.get_meta("collected",false): return
	drop.set_meta("collected",true)
	drops.erase(drop)
	collected_wood+=1
	drop.queue_free()

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



