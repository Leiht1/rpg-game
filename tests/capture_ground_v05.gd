extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=load("res://scenes/ground_preview.tscn").instantiate()
	root.add_child(w)
	w.player.automated=true
	while not w.started:await process_frame
	w.player.input_override=Vector2.ZERO
	w.player.camera.position_smoothing_enabled=false
	w.stream.set_candidate(1)
	w.update_comparison()
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	var tag:="after" if OS.get_cmdline_user_args().has("--after") else "before"
	root.get_texture().get_image().save_png("res://reports/ground-v05-"+tag+".png")
	if tag=="after":
		var checks:={"static_layers":true,"clearing_clean":true,"original_prop_positions":true,"deterministic_decoration":true}
		var count:=0
		for coord in w.stream.loaded:
			var layer=w.stream.loaded[coord].candidate
			checks.static_layers=checks.static_layers and not layer.has_method("_process")
			var original=w.generator.props_for_chunk(coord)
			var copy=load("res://scripts/ground_candidate.gd").new()
			copy.configure(w.generator,coord,original)
			checks.deterministic_decoration=checks.deterministic_decoration and copy.tufts==layer.tufts
			copy.free()
			for tuft in layer.tufts:
				count+=1
				var at:Vector2=layer.position+tuft.p
				checks.clearing_clean=checks.clearing_clean and at.distance_to(w.generator.spawn)>=210
				checks.original_prop_positions=checks.original_prop_positions and original.any(func(prop):return prop.kind>=4 and prop.position==at)
		var f=FileAccess.open("res://reports/ground-v05-checks.json",FileAccess.WRITE)
		f.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"loaded_static_tufts":count,"scope":"spawn preview only; render distribution checks"},"  "))
		for entry in w.stream.loaded.values():entry.candidate.visible=false
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/ground-v05-no-grass.png")
	quit()
