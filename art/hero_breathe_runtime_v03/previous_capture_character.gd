extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world=load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	world.player.automated=true
	while not world.started: await process_frame
	world.player.set_physics_process(false)
	world.player.camera.zoom=Vector2.ONE*1.65
	world.player.camera.reset_smoothing()
	world.debug_on=false
	world.debug_label.hide()
	for i in 8: await process_frame
	var walk_count: int=world.player.sprite.sprite_frames.get_frame_count("front_walk")
	var sheet := Image.create((walk_count+1)*176,4*208,false,Image.FORMAT_RGBA8)
	for row in 4:
		world.player.facing=["front","back","right","left"][row]
		for col in range(walk_count+1):
			world.player.moving=col>0
			world.player.gait_distance=(col-1)*float(world.player.actor.stride_world_units)/float(walk_count)+0.001 if col>0 else 0.0
			world.player.idle_clock=0
			world.player.update_animation()
			await process_frame
			await RenderingServer.frame_post_draw
			var capture: Image=root.get_texture().get_image()
			var screen_position: Vector2=world.player.get_global_transform_with_canvas().origin
			var region := Rect2i(Vector2i(screen_position)-Vector2i(88,166),Vector2i(176,208))
			sheet.blit_rect(capture,region,Vector2i(col*176,row*208))
			if row==0 and col==0: capture.save_png("res://reports/character-world.png")
	sheet.save_png("res://reports/character-godot-poses.png")
	world.queue_free()
	await process_frame
	print("CHARACTER_RENDER captured 4 directions x (idle + ",walk_count," walk poses)")
	quit()
