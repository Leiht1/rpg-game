extends SceneTree
var world: Node
var results: Array = []
var failures: Array[String] = []
var targets := {}

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	results.append({"name":label,"pass":ok})
	if not ok: failures.append(label); push_error(label)

func settle() -> void:
	world.stream.update_target(world.player.position)
	var end := Time.get_ticks_msec()+45000
	while not world.stream.viewport_ready(world.player.position,Vector2(720,430)) and Time.get_ticks_msec()<end: await process_frame
	check(world.stream.viewport_ready(world.player.position,Vector2(720,430)),"visible streaming ready")
	for i in 12: await process_frame

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/resources-v031/"+label+".png")

func teleport(p: Vector2) -> void:
	world.player.cancel_action()
	world.player.position=p
	world.player.reset_physics_interpolation()
	world.player.camera.reset_smoothing()
	await settle()

func pick_targets() -> void:
	var service: Node = world.item_service
	var gen: WildGenerator = world.generator
	targets.spawn=gen.spawn
	for core in gen.region_cores:
		var category := str(gen.biome(core))
		var key: String = {"森林":"forest","山地":"mountain","草原":"meadow"}.get(category,"")
		if key=="" or targets.has(key): continue
		var c: Vector2i = world.stream.chunk_at(core)
		for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN]:
			for row in service.entries(c+offset):
				var p := Vector2(row.x,row.y)
				if float(row.ecology[key])<.75: continue
				for side in [Vector2(85,65),Vector2(-85,65),Vector2(85,-35),Vector2(-85,-35)]:
					if service.ground_clear(p+side,11,service.nearby_props(p),false): targets[key]=p+side; break
				if targets.has(key): break
			if targets.has(key): break
	# Locate actual coastal land, then find a generated shoreline resource.
	for room in gen.rooms:
		if targets.has("shore"): break
		for direction in 12:
			var vector := Vector2.from_angle(direction*TAU/12)
			var last: Vector2 = room.p
			for distance in range(160,int(maxf(room.r.x,room.r.y)*3),160):
				var p: Vector2 = room.p+vector*distance
				if gen.sample(p).z>.6:
					var c: Vector2i = world.stream.chunk_at(last)
					for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
						for row in service.entries(c+offset):
							if float(row.ecology.shore)>.4:
								var at := Vector2(row.x,row.y)
								for side in [Vector2(85,65),Vector2(-85,65),Vector2(85,-35),Vector2(-85,-35)]:
									if service.ground_clear(at+side,11,service.nearby_props(at),false): targets.shore=at+side; break
								if targets.has("shore"): break
						if targets.has("shore"): break
					break
				last=p
			if targets.has("shore"): break
	check(targets.size()==5,"all five real map locations found")

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code; event.pressed=true
	root.push_input(event,true)
	await process_frame
	event=InputEventKey.new(); event.physical_keycode=code
	root.push_input(event,true)
	await process_frame

func run() -> void:
	Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/resources-v031"))
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new()
	root.add_child(world)
	world.player.automated=true
	world.player.camera.position_smoothing_enabled=false
	world.environment_view.simulation.set_time(10)
	world.environment_view.simulation.paused=true
	await settle()
	pick_targets()
	var locations := {}
	for key_name in targets:
		await teleport(targets[key_name])
		locations[key_name]={"x":world.player.position.x,"y":world.player.position.y,"biome":world.generator.biome(world.player.position),"chunk":str(world.stream.chunk_at(world.player.position))}
		await shot("formal-"+key_name)
	check(world.stream.drops.size()>0,"formal map has visible resources")
	check(world.item_service.texture("wildflower","world")==null,"formal art not implicitly approved")
	await key(KEY_F7)
	for i in 30: await process_frame
	check(world.get_node("ResourceDebug").active,"F7 resource overlay")
	await shot("distribution-debug")
	await key(KEY_F7)
	# Use actual E events on a naturally generated plant.
	var plant: Node2D
	for node in world.stream.drops:
		if node.get_meta("mode")=="harvest":
			var p: Vector2=node.position+Vector2(34,0)
			if world.item_service.ground_clear(p,11,world.item_service.nearby_props(p),false): plant=node; break
	check(plant!=null,"natural plant available for E")
	if plant:
		var id: String=plant.get_meta("drop_id")
		await teleport(plant.position+Vector2(34,0))
		await shot("before-harvest")
		await key(KEY_E)
		check(world.player.action=="pickup" and world.player.harvesting,"E starts differentiated harvest")
		for i in 48: await physics_frame
		check(world.item_service.consumed.has(id),"E harvest commits world edit")
		check(not world.item_service.inventory.slots[8].is_empty(),"E harvest enters bag")
		await key(KEY_B)
		await shot("after-harvest-bag")
		var click := InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_RIGHT; click.pressed=true; click.ctrl_pressed=true
		world.item_ui.cells[8].on_input(click)
		check(world.item_service.inventory.slots[8].is_empty(),"Ctrl right click drops one from bag")
		await key(KEY_B)
		await key(KEY_E)
		for i in 48: await physics_frame
		check(not world.item_service.inventory.slots[8].is_empty(),"E retrieves player discarded item")
		var owner: Vector2i = world.stream.chunk_at(world.player.position)
		world.stream.unload_chunk(owner)
		await process_frame
		var packet: Dictionary=world.generator.build_chunk(owner)
		var empty_stamps: Array[Dictionary]=[]
		packet["ground_stamps"]=empty_stamps
		world.stream.install_chunk(packet)
		var count := 0
		for node in world.stream.drops:
			if node.get_meta("drop_id")==id: count+=1
		check(count==0,"actual unload/reload keeps harvested state")
		# Full bag via actual E commit: no disappearing resource or carry success.
		world.item_service.inventory.slots.assign(ItemInventory.new(world.item_service.database).slots)
		world.item_service.inventory.add("stone",32*99)
		var another: Node2D
		for node in world.stream.drops:
			var at: Vector2=node.position+Vector2(0,25)
			if world.item_service.ground_clear(at,11,world.item_service.nearby_props(at),false): another=node; break
		if another:
			var another_id: String=another.get_meta("drop_id")
			await teleport(another.position+Vector2(0,25))
			await key(KEY_E)
			for i in 33: await physics_frame
			check(is_instance_valid(another) and not another.get_meta("collected",false) and not world.player.action_succeeded and not world.player.carried_wood.visible,"full bag E retains resource and suppresses success feedback")
			check(not world.item_service.consumed.has(another_id),"full bag leaves harvest record untouched")
			await shot("full-bag-retains-resource")
	# Preview swaps only visuals, retaining exactly the same world IDs/positions.
	var formal_resources: Array=world.item_service.entries(world.stream.chunk_at(targets.spawn))
	world.item_service.dirty=false
	world.queue_free()
	await process_frame
	world=load("res://tests/world_v06_formal_fixture.gd").new()
	world.items_preview=true
	root.add_child(world)
	world.player.automated=true
	world.player.camera.position_smoothing_enabled=false
	world.environment_view.simulation.set_time(10)
	world.environment_view.simulation.paused=true
	check(world.item_service.entries(world.stream.chunk_at(targets.spawn))==formal_resources,"preview and formal distributions identical")
	for key_name in targets:
		await teleport(targets[key_name])
		await shot("preview-"+key_name)
	var frames: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 180:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-previous)/1000.0); previous=now
	frames.sort()
	check(world.player.WALK_SPEED==200.0 and world.player.RUN_SPEED==310.0,"movement speeds unchanged")
	check(world.environment_view.simulation.Weather.THUNDERSTORM==3,"storm weather still installed")
	FileAccess.open("res://reports/resources-v031/runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"checks":results,"failures":failures,"locations":locations,"performance":{"frames":180,"median_ms":frames[90],"p95_ms":frames[171],"max_ms":frames[-1],"max_chunk_install_ms":world.stream.max_install_ms,"navigation_ms":world.item_service.navigation_ms,"memory_mib":OS.get_static_memory_usage()/1048576.0,"nodes":get_node_count(),"note":"Settled shoreline, rendered, 60 FPS cap; includes frame waiting, not whole-world stress."}},"\t"))
	print("RESOURCES_RUNTIME ",results.size()," checks / ",failures.size()," failures")
	world.item_service.dirty=false
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
