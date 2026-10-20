extends SceneTree
func _initialize() -> void:call_deferred("capture")
func capture() -> void:
	var preview=load("res://preview.tscn").instantiate()
	root.add_child(preview)
	preview.stopped=true
	preview.sync_speed()
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/preview.png")
	var vp:=SubViewport.new()
	vp.size=Vector2i(576,512)
	vp.transparent_bg=true
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var rig=load("res://character.tscn").instantiate()
	rig.scale=Vector2.ONE*4
	vp.add_child(rig)
	var ap:AnimationPlayer=rig.get_node("AnimationPlayer")
	for d in ["back"]:
		for action in ["breathe","walk","run","wave","chop","pickup"]:
			var name_:String=d+"_"+action
			DirAccess.make_dir_recursive_absolute("res://evidence/"+name_)
			ap.play(name_)
			ap.pause()
			for k in 48:
				ap.seek(float(k)/48*ap.get_animation(name_).length,true)
				await process_frame
				await RenderingServer.frame_post_draw
				vp.get_texture().get_image().save_png("res://evidence/"+name_+"/%02d.png"%k)
	preview.set_direction("back")
	preview.set_action("wave")
	preview.joints=true
	for r in preview.rigs:
		var player:AnimationPlayer=r.get_node("AnimationPlayer")
		player.advance(.2)
		player.seek(.8,true)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/back_wave_pivots.png")
	print("CAPTURE completed requested clips + preview GPU render")
	quit()
