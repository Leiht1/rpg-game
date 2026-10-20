extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var background:=TextureRect.new()
	background.size=Vector2(1280,720)
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	root.add_child(background)
	var overlay:=TextureRect.new()
	overlay.texture=ImageTexture.create_from_image(Image.load_from_file("res://prototypes/ground-study-v06/scene-overlay.png"))
	overlay.size=Vector2(1280,720)
	root.add_child(overlay)
	for key in ["A","B","C"]:
		background.texture=ImageTexture.create_from_image(Image.load_from_file("res://prototypes/ground-study-v06/ground-"+key+".png"))
		for i in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://prototypes/ground-study-v06/preview-"+key+".png")
	quit()
