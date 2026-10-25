extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1280,720)
	var bg:=ColorRect.new();bg.size=Vector2(1280,720);bg.color=Color("373c36");root.add_child(bg)
	var flames: Array=[]
	var torches: Array=[]
	var title:=Label.new();title.text="满燃料                         半燃料                         接近燃尽";title.position=Vector2(170,40);title.add_theme_font_size_override("font_size",26);root.add_child(title)
	var def=JSON.parse_string(FileAccess.get_file_as_string("res://data/campfire_rules.json"))
	var flame_texture: Texture2D=load("res://assets/campfire/v1/flame.png")
	var art=preload("res://scripts/candidate_art.gd")
	var torch_texture: Texture2D=art.texture("res://prototypes/torch-separated-v1/body.png")
	var torch_flame_texture: Texture2D=art.texture("res://prototypes/torch-separated-v1/flame.png")
	for col in 3:
		var fraction: float=[1.0,.5,.001][col]
		var size_factor:=lerpf(float(def.flame_scale_min),float(def.flame_scale_max),fraction)
		var x:=200+col*420
		var base:=Sprite2D.new();base.texture=load("res://assets/campfire/v1/base.png");base.scale=Vector2.ONE*.65;base.position=Vector2(x,310);root.add_child(base)
		var flame:=Sprite2D.new();flame.texture=flame_texture;flame.scale=Vector2.ONE*.5*size_factor
		var bottom: float=(flame_texture.get_image().get_used_rect().end.y-flame_texture.get_height()*.5)*.5
		flame.position=Vector2(x,250+bottom*(1-size_factor));var mat:=ShaderMaterial.new();mat.shader=load("res://scripts/campfire_flame.gdshader");flame.material=mat;root.add_child(flame);flames.append(flame)
		var torch:=Sprite2D.new();torch.texture=torch_texture;torch.scale=Vector2.ONE*190/torch_texture.get_height();torch.position=Vector2(x,550)
		root.add_child(torch);torches.append(torch)
		var tf:=Sprite2D.new();tf.texture=torch_flame_texture;tf.centered=false;tf.offset=Vector2(-torch_flame_texture.get_width()*.5,-torch_flame_texture.get_height());tf.position=Vector2(x,464);tf.scale=Vector2.ONE*84/torch_flame_texture.get_height()*size_factor
		var tm:=ShaderMaterial.new();tm.shader=load("res://scripts/camp_torch_flame.gdshader");tm.set_shader_parameter("source_height",float(torch_flame_texture.get_height()));tf.material=tm;root.add_child(tf)
		var label:=Label.new();label.text="光照半径 ×%.3f · 火焰 ×%.3f"%[lerpf(.5,2,fraction),size_factor];label.position=Vector2(x-145,660);root.add_child(label)
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/home-local-v1/fuel-comparison.png")
	print("FIRE_VISUAL rendered default window without shader errors")
	quit()
