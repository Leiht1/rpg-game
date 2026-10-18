extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/tools-held-v04/references"))
	var view := SubViewport.new()
	view.size=Vector2i(1024,512)
	view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	for i in 2:
		var character: Node2D=load("res://assets/hero/cartoon/character.tscn").instantiate()
		character.position=Vector2(i*512,0)
		character.scale=Vector2.ONE*4
		view.add_child(character)
		var animation: AnimationPlayer=character.get_node("AnimationPlayer")
		animation.play("front_breathe" if i==0 else "side_breathe")
		animation.seek(0,true)
		animation.pause()
		character.get_node("Visual/Pelvis/ArmR/Grip/Axe").hide()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://art/tools-held-v04/references/approved-character-front-side.png")
	view.queue_free()
	for i in 3: await process_frame
	quit()
