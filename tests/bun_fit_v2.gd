extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	var variant:=OS.get_cmdline_user_args().has("bun-v3")
	if variant:
		var catalog=preload("res://scripts/character_catalog.gd").rules()
		for view in ["front","back","side"]:catalog.hair.unisex_bun[view].front="res://prototypes/bun-exact-fit-v3/"+view+".png"
	variant=preload("res://scripts/character_catalog.gd").rules().hair.unisex_bun.front.front.begins_with("res://prototypes/bun-exact-fit-v3/")
	if OS.get_cmdline_user_args().has("forehead-v4"):
		preload("res://scripts/character_catalog.gd").rules().hair.unisex_bun.side.front="res://prototypes/bun-forehead-v4/side.png"
	if OS.get_cmdline_user_args().has("contour-v5"):
		preload("res://scripts/character_catalog.gd").rules().hair.unisex_bun.side.front="res://prototypes/bun-contour-v5/side.png"
	var contour_variant: bool=preload("res://scripts/character_catalog.gd").rules().hair.unisex_bun.side.front.begins_with("res://prototypes/bun-contour-v5/")
	var forehead_variant: bool=preload("res://scripts/character_catalog.gd").rules().hair.unisex_bun.side.front.begins_with("res://prototypes/bun-forehead-v4/")
	var creation=load("res://scripts/character_creation.gd").new();creation.selection_only=true;root.add_child(creation)
	await process_frame
	var layer:=CanvasLayer.new();layer.layer=100;root.add_child(layer)
	var bg:=ColorRect.new();bg.color=Color("d6dbc4");bg.size=Vector2(1280,720);layer.add_child(bg)
	var labels: Array=["正面","背面","右侧","左侧"]
	for col in 4:
		var title:=Label.new();title.text=labels[col];title.position=Vector2(180+col*285,25);title.add_theme_color_override("font_color",Color("394332"));title.add_theme_font_size_override("font_size",24);layer.add_child(title)
	var checks: Array=[]
	if variant:
		var qa: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/hair-night-local-v1/bun-exact-fit-qa.json"))
		for key in ["ear_outer_arcs_visible","side_ear_fully_visible","rear_skull_fully_covered"]:
			checks.append({"pass":qa[key],"name":key})
	if forehead_variant:
		var forehead_qa: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/hair-night-local-v1/forehead-fit-qa.json"))
		checks.append({"pass":forehead_qa.pass,"name":"actual head forehead continuous with hair; ear/rear preserved"})
	if contour_variant:
		var contour_qa: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://art/hair-night-local-v1/forehead-contour-v5.json"))
		checks.append({"pass":contour_qa.pass,"name":"lower forehead silhouette preserves attached hairline, ear and rear"})
	for row in 2:
		creation.look.hair_id="unisex_bun";creation.select_gender(row)
		checks.append({"pass":creation.hair_ids.has("unisex_bun") and creation.look.hair_id=="unisex_bun","name":"gender selection retains bun "+str(row)})
		for col in 4:
			creation.preview_facing=["front","back","right","left"][col];creation.refresh_preview()
			var source: Sprite2D=creation.preview.get_node("Visual/Pelvis/Head/Sprite")
			var head: Sprite2D=source.duplicate();layer.add_child(head);head.position=Vector2(210+col*285,200+row*320);head.scale=Vector2(-.85 if col==3 else .85,.85)
			checks.append({"pass":head.get_node("CharacterHairfront").texture!=null,"name":"native bun head "+str(row)+str(col)})
		var label:=Label.new();label.text="男" if row==0 else "女";label.position=Vector2(30,180+row*320);label.add_theme_color_override("font_color",Color("394332"));label.add_theme_font_size_override("font_size",24);layer.add_child(label)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/home-local-v1/bun-head-fit-v5.png" if contour_variant else "res://reports/home-local-v1/bun-head-fit-v4.png" if forehead_variant else "res://reports/home-local-v1/bun-head-fit-v3.png" if variant else "res://reports/home-local-v1/bun-head-fit-v2.png")
	for child in layer.get_children():
		if child!=bg:child.queue_free()
	await process_frame
	for row in 4:
		var id: String="unisex_mohawk" if row<2 else "unisex_bun"
		creation.look.hair_id=id;creation.select_gender(row%2)
		for col in 4:
			creation.preview_facing=["front","back","right","left"][col];creation.refresh_preview()
			var rig=creation.preview.duplicate();layer.add_child(rig);rig.position=Vector2(230+col*250,20+row*170);rig.scale=Vector2.ONE*1.45;rig.get_node("AnimationPlayer").active=false
		var label:=Label.new();label.text=("莫西干" if row<2 else "丸子头")+(" 男" if row%2==0 else " 女");label.position=Vector2(20,65+row*170);label.add_theme_color_override("font_color",Color("394332"));layer.add_child(label)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/home-local-v1/hair-four-views-v5.png" if contour_variant else "res://reports/home-local-v1/hair-four-views-v4.png" if forehead_variant else "res://reports/home-local-v1/hair-four-views-v3.png" if variant else "res://reports/home-local-v1/hair-four-views-v2.png")
	FileAccess.open("res://reports/home-local-v1/bun-fit-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	var failed:=checks.filter(func(x):return not x.pass).size();print("BUN_FIT ",checks.size()," FAILED ",failed)
	creation.queue_free();await process_frame;quit(1 if failed else 0)
