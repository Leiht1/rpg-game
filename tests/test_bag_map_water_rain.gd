extends SceneTree
const OUT := "res://reports/bag-map-water-rain/"
var world: Node
var checks: Array = []
var failures: Array[String] = []
var water_results: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: failures.append(label); push_error(label)
func frames(count: int = 2) -> void:
	for i in count: await process_frame
func physics(count: int) -> void:
	for i in count: await physics_frame
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code; event.keycode=code; event.pressed=true
	Input.parse_input_event(event)
	await frames()
	event=InputEventKey.new(); event.physical_keycode=code; event.keycode=code
	Input.parse_input_event(event)
	await frames()
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func walk(action: String, count: int = 12) -> float:
	var before: Vector2=world.player.position
	Input.action_press(action)
	await physics(count)
	Input.action_release(action)
	await physics(2)
	return before.distance_to(world.player.position)
func settle() -> void:
	world.stream.update_target(world.player.position)
	var end := Time.get_ticks_msec()+30000
	while not world.stream.viewport_ready(world.player.position,Vector2(720,430)) and Time.get_ticks_msec()<end: await process_frame
	check(world.stream.viewport_ready(world.player.position,Vector2(720,430)),"camera ground ready")
	await frames(4)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.max_fps=60
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new()
	root.add_child(world)
	if world.player==null: quit(1); return
	while not world.started: await process_frame
	world.environment_view.simulation.set_time(10)
	world.environment_view.simulation.paused=true
	var ui: Control=world.item_ui
	await key(KEY_B)
	check(ui.bag.visible and not world.player.input_blocked,"open bag permits movement")
	for action in ["move_up","move_left","move_down","move_right"]:
		var distance: float=await walk(action)
		check(distance>24 and ui.bag.visible,"WASD movement with bag open: "+action)
	await shot("bag-movement")
	world.item_service.inventory.add("wild_berry",6)
	ui.open_split(8)
	check(world.player.input_blocked,"quantity input pauses movement")
	check(await walk("move_right")==0,"quantity input prevents accidental walking")
	await key(KEY_ESCAPE)
	check(ui.bag.visible and not world.player.input_blocked,"cancel quantity input restores bag movement")
	var debug: Node=world.get_node("ResourceDebug")
	debug.seed_input.grab_focus()
	# Hidden controls cannot take focus; expose the actual debug panel first.
	await key(KEY_F7)
	debug.seed_input.grab_focus(); await frames()
	check(world.player.input_blocked,"debug text field pauses movement")
	debug.seed_input.release_focus(); await frames()
	check(not world.player.input_blocked and ui.bag.visible,"leaving debug text field restores bag movement")
	await key(KEY_F7)
	while world.map_view.row<512: await process_frame
	await key(KEY_M)
	check(world.map_view.visible and not ui.bag.visible,"M opens map and closes bag")
	check(world.map_view.get_parent() is CanvasLayer and world.map_view.get_parent().layer>world.ui.layer and world.map_view.get_parent().layer>3,"map layer above hotbar and clock")
	check(await walk("move_right")==0,"map still pauses movement")
	await frames()
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	var background := Color(.12,.19,.14)
	for pixel in [Vector2i(80,90),Vector2i(450,655)]:
		var actual := image.get_pixelv(pixel)
		check(Vector3(actual.r-background.r,actual.g-background.g,actual.b-background.b).length()<.02,"map visually covers HUD at "+str(pixel))
	await shot("map-topmost")
	var wheel := InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP; wheel.pressed=true; wheel.position=Vector2(640,360)
	root.push_input(wheel,true); await frames()
	check(world.map_view.zoom>1,"map zoom still works")
	# The hidden navigation button must not receive clicks through the map.
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT; click.pressed=pressed; click.position=ui.bag_button.get_global_rect().get_center()
		root.push_input(click,true); await frames()
	check(world.map_view.visible and not ui.bag.visible,"map blocks hidden hotbar button clicks")
	await key(KEY_ESCAPE)
	check(not world.map_view.visible and not world.player.input_blocked,"Escape closes map and restores movement")
	await key(KEY_B)
	check(await walk("move_right")>24,"bag movement still works after map close")
	ui.close_panels()
	# Exercise the actual emitter over non-walkable lake/river water, then render.
	var gen: WildGenerator=world.generator
	check(not gen.lakes.is_empty() and not gen.rivers.is_empty(),"real lake and river available")
	if not gen.lakes.is_empty():
		var lake: Vector4=gen.lakes[0]
		await water_test("lake",Vector2(lake.x,lake.y),Vector2(150,120))
	if not gen.rivers.is_empty():
		var points: PackedVector2Array=gen.rivers[0].points
		await water_test("river",points[points.size()/2],Vector2(45,40))
	FileAccess.open(OUT+"tests.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures,"water":water_results},"\t"))
	print("BAG_MAP_WATER_RAIN ",checks.size()," checks / ",failures.size()," failures")
	world.item_service.dirty=false
	world.queue_free(); await frames()
	quit(0 if failures.is_empty() else 1)

func water_test(label: String, center: Vector2, half_size: Vector2) -> void:
	# Camera-only water inspection; normal player navigation never enters water.
	world.player.set_physics_process(false)
	world.player.camera.position=center-world.player.position
	world.player.camera.position_smoothing_enabled=false
	world.player.camera.reset_smoothing()
	world.stream.update_target(center)
	world.stream.set_process(true)
	var end := Time.get_ticks_msec()+30000
	while not world.stream.viewport_ready(center,Vector2(720,430)) and Time.get_ticks_msec()<end: await process_frame
	check(world.stream.viewport_ready(center,Vector2(720,430)),label+" water chunks loaded")
	world.player.camera.force_update_scroll()
	await frames(4)
	check(not world.generator.can_walk(center),label+" test position is water")
	var view: Node=world.environment_view
	var sim: Node=view.simulation
	sim.force_weather(2); sim.paused=false; sim.advance(25); sim.paused=true
	view._process(0)
	var rain: Node=view.rain_visual
	rain.set_process(false)
	for drop in rain.drops: drop.life=0
	for splash in rain.splashes: splash.life=0
	var hits := 0
	var rect := Rect2(center-half_size,half_size*2)
	for i in 40:
		rain.emit_drop(rect)
		var drop: Dictionary=rain.drops[i]
		if drop.splash and not world.generator.can_walk(drop.ground): hits+=1
	check(hits>0,label+" rain emitter schedules water arcs")
	for drop in rain.drops:
		if drop.life>0: drop.life=.01
	rain._process(.02)
	var arcs := 0
	for splash in rain.splashes:
		if splash.life>0 and not world.generator.can_walk(splash.ground): arcs+=1
	check(arcs>0,label+" falling rain produces live water arcs")
	# Capture normal sparse rain rather than the concentrated emitter test above.
	for drop in rain.drops: drop.life=0
	for splash in rain.splashes: splash.life=0
	rain.set_process(true)
	var visible_water_arcs := 0
	for i in 180:
		await process_frame
		visible_water_arcs=0
		for splash in rain.splashes:
			if splash.life>0 and not world.generator.can_walk(splash.ground): visible_water_arcs+=1
		if i>30 and visible_water_arcs>=3: break
	check(visible_water_arcs>0,label+" normal runtime rain makes visible water arcs")
	await shot(label+"-rain-arcs")
	water_results.append({"surface":label,"scheduled_water_hits":hits,"water_arcs":arcs,"normal_runtime_water_arcs":visible_water_arcs,"pool_rain":rain.drops.size(),"pool_splash":rain.splashes.size()})
	check(rain.drops.size()==256 and rain.splashes.size()==128,label+" fixed pools unchanged")
	rain.set_process(true)
