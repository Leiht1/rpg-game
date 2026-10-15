extends SceneTree

var world: Node2D

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count: await process_frame

func ready_at(p: Vector2) -> void:
	world.player.position=p
	world.player.camera.reset_smoothing()
	world.stream.update_target(p)
	var attempts := 0
	while not world.stream.viewport_ready(p,Vector2(700,420)) and attempts<2000:
		await process_frame
		attempts+=1
	await frames(8)

func shot(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/%s.png"%name_value)

func run() -> void:
	world=load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	world.player.automated=true
	while not world.started: await process_frame
	# Keep reference screenshots uncluttered; performance uses a separate timed run.
	world.debug_on=false
	world.debug_label.hide()
	await ready_at(world.generator.spawn)
	await shot("final-spawn")
	var best := {}
	var distances := {}
	for y in range(220):
		for x in range(220):
			var p: Vector2 = Vector2(x+.5,y+.5)*world.generator.extent/220
			var biome: String=world.generator.biome(p)
			var distance: float=p.distance_squared_to(world.generator.spawn)
			if not distances.has(biome) or distance<distances[biome]:
				distances[biome]=distance
				best[biome]=p
	for biome in ["森林","山地","河流","湖泊"]:
		var target: Vector2=best[biome]
		if not world.generator.can_walk(target):
			var found := false
			for radius in range(30,900,20):
				for i in 16:
					var point := target+Vector2.from_angle(i*TAU/16)*radius
					if world.generator.can_walk(point):
						target=point
						found=true
						break
				if found: break
		await ready_at(target)
		world.ui_clock=1
		await frames(3)
		var names := {"森林":"forest","山地":"mountain","河流":"river","湖泊":"lake"}
		await shot("final-"+names[biome])
	# V0.1 uses complete frames. Modular body proof belongs to a future stage.
	world.queue_free()
	await process_frame
	quit()
