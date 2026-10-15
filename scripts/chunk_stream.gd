class_name WildStream
extends Node2D

const Gen = preload("res://scripts/world_generator.gd")
const Prop = preload("res://scripts/nature_prop.gd")
const TERRAIN_SHADER = preload("res://scripts/terrain.gdshader")
const FILES := ["tree_0","tree_1","rock_0","rock_1","tuft_0","tuft_1","tuft_2"]
var generator: WildGenerator
var object_root: Node2D
var loaded := {}
var tasks := {}
var ready_data: Array[Dictionary] = []
var requested: Array[Vector2i] = []
var mutex := Mutex.new()
var textures: Array[Texture2D] = []
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

func configure(gen: WildGenerator, sort_root: Node2D) -> void:
	generator=gen
	object_root=sort_root
	for file in FILES:
		textures.append(load("res://assets/environment/%s.png"%file))
	shared_material.shader=TERRAIN_SHADER
	shared_material.set_shader_parameter("brush_texture",load("res://assets/environment/meadow.png"))

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
	var local_gen := Gen.new(generator.world_seed,generator.map_cells)
	var packet := local_gen.build_chunk(coord)
	mutex.lock()
	ready_data.append(packet)
	mutex.unlock()

func install_chunk(packet: Dictionary) -> void:
	var start := Time.get_ticks_usec()
	var coord: Vector2i=packet.coord
	var terrain := Sprite2D.new()
	terrain.texture=ImageTexture.create_from_image(packet.image)
	terrain.centered=false
	terrain.position=Vector2(coord)*Gen.CHUNK_PX-Vector2.ONE*Gen.TEX_STEP
	terrain.scale=Vector2.ONE*Gen.TEX_STEP
	terrain.material=shared_material
	add_child(terrain)
	var body := StaticBody2D.new()
	body.position=Vector2(coord)*Gen.CHUNK_PX
	add_child(body)
	var props: Array[Node2D]=[]
	for entry in packet.props:
		var prop := Prop.new()
		prop.kind=entry.kind
		prop.texture=textures[entry.kind]
		prop.position=entry.position
		prop.display_size=Vector2(prop.texture.get_size())*entry.scale
		object_root.add_child(prop)
		props.append(prop)
		if entry.kind<4:
			var shape := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius=(15.0 if entry.kind<2 else (20.0 if entry.kind==2 else 27.0))*entry.scale
			shape.shape=circle
			shape.position=entry.position-body.position
			body.add_child(shape)
	loaded[coord]={"terrain":terrain,"body":body,"props":props}
	object_count+=props.size()
	total_loaded+=1
	last_build_ms=packet.build_ms
	last_install_ms=(Time.get_ticks_usec()-start)/1000.0
	max_install_ms=maxf(max_install_ms,last_install_ms)

func unload_chunk(coord: Vector2i) -> void:
	var entry: Dictionary=loaded[coord]
	object_count-=entry.props.size()
	entry.terrain.queue_free()
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
