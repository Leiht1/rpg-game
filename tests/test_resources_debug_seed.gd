extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var identity_path := "user://world-continent-v06.json"
	var before := FileAccess.get_file_as_bytes(identity_path) if FileAccess.file_exists(identity_path) else PackedByteArray()
	var world: Node=load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	var debug: Node=world.get_node("ResourceDebug")
	debug.seed_input.text="447349832"
	debug.panel.get_child(0).get_child(2).get_child(1).pressed.emit()
	for i in 8: await process_frame
	world=current_scene
	if world.world_seed!=447349832 or world.persistent_world: failures.append("debug switch must create the requested nonpersistent world")
	var after := FileAccess.get_file_as_bytes(identity_path) if FileAccess.file_exists(identity_path) else PackedByteArray()
	if before!=after: failures.append("formal identity changed during temporary seed switch")
	while not world.started: await process_frame
	var service: Node=world.item_service
	var c: Vector2i=world.stream.chunk_at(world.player.position)
	var resources: Array=service.entries(c)
	var view: Node=world.environment_view
	var sim: Node=view.simulation
	var rain: Node=view.rain_visual
	sim.force_weather(2); sim.paused=false; sim.advance(25); sim.paused=true
	view._process(0)
	var small_light: Dictionary=sim.light_parameters()
	var start: int=rain.emitted
	for i in 120: rain._process(1.0/60)
	var small: int=rain.emitted-start
	if small<=0: failures.append("light rain stopped after resource integration")
	sim.force_weather(3); sim.paused=false; sim.advance(25); sim.paused=true
	view._process(0)
	start=rain.emitted
	for i in 120: rain._process(1.0/60)
	var storm: int=rain.emitted-start
	if storm<=small*2 or sim.light_parameters().brightness>=small_light.brightness: failures.append("storm intensity or grading changed")
	if resources!=service.entries(c): failures.append("weather modified resource positions")
	world.item_service.dirty=false
	world.queue_free()
	await process_frame
	FileAccess.open("res://reports/resources-v031/debug-seed.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":5,"failures":failures,"small_rain_emitted":small,"storm_emitted":storm,"weather_method":"real world nodes, explicit 120 steps of 1/60 seconds per weather; scoped dependency smoke"}))
	print("DEBUG_SEED_WEATHER 5 checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
