extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps=60
	Engine.set_meta("integration_seed",271828)
	var world: Node=load("res://tests/world_v06_formal_fixture.gd").new()
	root.add_child(world)
	world.player.automated=true
	world.player.camera.position_smoothing_enabled=false
	world.player.position=Vector2(11240,16270)
	world.player.reset_physics_interpolation()
	world.stream.update_target(world.player.position)
	world.environment_view.simulation.set_time(10)
	world.environment_view.simulation.paused=true
	while not world.started or not world.stream.viewport_ready(world.player.position,Vector2(720,430)): await process_frame
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/item-actions-v031/formal-resource-art.png")
	world.item_service.dirty=false
	world.queue_free()
	await process_frame
	quit()
