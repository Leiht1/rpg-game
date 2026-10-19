extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=load("res://scenes/ground_preview.tscn").instantiate();root.add_child(w)
	w.player.automated=true
	while not w.started:await process_frame
	w.player.camera.position_smoothing_enabled=false
	w.stream.set_candidate(2);w.update_comparison()
	var start:Vector2=w.generator.spawn+Vector2(-60,-65)
	w.player.set_physics_process(true)
	w.player.input_blocked=false
	w.player.position=start;w.player.camera.zoom=Vector2.ONE*2
	for i in 40:
		w.player.input_override=Vector2.DOWN if i<12 else Vector2.ZERO
		w.player.run_override=i<12
		for f in 3:await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/ground-v04-motion-%02d.png"%i)
	print("MOTION END ",w.player.position," input ",w.player.input_override," moving ",w.player.moving)
	w.player.camera.zoom=Vector2.ONE
	for key in [KEY_4,KEY_5,KEY_6]:
		var event:=InputEventKey.new();event.physical_keycode=key;event.pressed=true
		w._unhandled_input(event)
		while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
		for i in 5:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/ground-v04-biome-%d.png"%key)
	print("BIOME AND ACTUAL MOTION CAPTURE OK");quit()
