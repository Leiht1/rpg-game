extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=load("res://scenes/ground_preview.tscn").instantiate()
	root.add_child(w)
	w.player.automated=true
	while not w.started:await process_frame
	w.player.input_override=Vector2.ZERO
	w.player.set_physics_process(false)
	w.player.camera.position_smoothing_enabled=false
	w.player.camera.reset_smoothing()
	w.ui.hide()
	w.stream.set_candidate(1)
	for entry in w.stream.loaded.values():
		entry.terrain.hide()
		entry.ground.hide()
		entry.candidate.hide()
	for prop in w.object_root.get_children():
		if prop.get("kind")!=null and prop.kind>=4:prop.hide()
	root.transparent_bg=true
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://prototypes/ground-study-v06/scene-overlay.png")
	quit()
