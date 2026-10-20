extends Node2D
const Layout=preload("res://prototypes/biome-v02/layout.gd")
const Prop=preload("res://scripts/nature_prop.gd")
var layout:RefCounted
var seed_value:int=271828
var player:CharacterBody2D
var camera:Camera2D
var nature:Node2D
var ground:ColorRect
var seed_input:LineEdit
var status:Label
var points:Array[Vector2]=[]
var overview=true
var save_path="user://biome-v02-world.json"
func _ready()->void:
	load_seed()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):seed_value=int(arg.get_slice("=",1))
	var keys={"run":[KEY_SHIFT],"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN]}
	for action in keys:
		if not InputMap.has_action(action):InputMap.add_action(action)
		for key in keys[action]:
			var event=InputEventKey.new();event.physical_keycode=key;InputMap.action_add_event(action,event)
	ground=ColorRect.new();ground.size=Layout.SIZE;ground.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(ground)
	nature=Node2D.new();nature.y_sort_enabled=true;add_child(nature)
	player=load("res://prototypes/biome-v02/player.gd").new()
	player.generator=load("res://scripts/world_generator.gd").new(seed_value,128)
	nature.add_child(player)
	camera=player.camera;camera.limit_right=int(Layout.SIZE.x);camera.limit_bottom=int(Layout.SIZE.y)
	setup_ui()
	regenerate(seed_value,false)
func setup_ui()->void:
	var layer=CanvasLayer.new();add_child(layer)
	var box=HBoxContainer.new();box.position=Vector2(16,12);layer.add_child(box)
	seed_input=LineEdit.new();seed_input.custom_minimum_size.x=160;box.add_child(seed_input)
	seed_input.text_submitted.connect(func(value):regenerate(int(value)))
	for item in [["应用 Seed",func():regenerate(int(seed_input.text))],["新世界",func():regenerate(int(Time.get_unix_time_from_system()*1000)%2147483647)],["读取世界",func():load_seed();regenerate(seed_value,false)],["总览 / 行走",func():focus(-2 if overview else -1)]]:
		var button=Button.new();button.text=item[0];button.pressed.connect(item[1]);box.add_child(button)
	status=Label.new();status.position=Vector2(16,54);status.add_theme_constant_override("outline_size",6);status.add_theme_color_override("font_outline_color",Color("26382e"));layer.add_child(status)
func load_seed()->void:
	seed_value=int(Time.get_unix_time_from_system()*1000)%2147483647
	if FileAccess.file_exists(save_path):
		var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if data is Dictionary and data.get("version")==Layout.VERSION:seed_value=int(data.seed)
func regenerate(value:int,persist:bool=true)->void:
	seed_value=value;layout=Layout.new(value);player.layout=layout
	for node in nature.get_children():
		if node!=player:nature.remove_child(node);node.queue_free()
	var mat=ShaderMaterial.new();mat.shader=load("res://prototypes/biome-v02/ground.gdshader")
	mat.set_shader_parameter("region_field",ImageTexture.create_from_image(layout.field()))
	for pair in [["forest_tex","forest"],["rock_tex","highland"],["meadow_tex","open_field"],["shore_tex","shore"]]:mat.set_shader_parameter(pair[0],ImageTexture.create_from_image(Image.load_from_file("res://prototypes/biome-v02/materials/"+pair[1]+".png")))
	mat.set_shader_parameter("spawn_tex",load("res://assets/environment/stylized_v3/grass.png"));ground.material=mat
	for entry in layout.objects():
		var prop=Prop.new();var file=entry.kind
		if file in ["tree","rock"]:file+="_"+str(entry.variant)
		prop.texture=load("res://assets/environment/stylized_v3/"+file+".png");prop.position=entry.p;prop.candidate_mode=1
		prop.kind=0 if entry.kind=="tree" else (2 if entry.kind=="rock" else 4)
		prop.display_size=Vector2(prop.texture.get_size())*entry.scale;nature.add_child(prop)
		if prop.kind<4:
			var body=StaticBody2D.new();var collision=CollisionShape2D.new();var shape=CircleShape2D.new();shape.radius=15 if prop.kind==0 else 12;collision.shape=shape;body.add_child(collision);prop.add_child(body)
	points=layout.landmarks();player.position=layout.spawn;seed_input.text=str(value);seed_input.release_focus();focus(-1)
	if persist:
		var file=FileAccess.open(save_path,FileAccess.WRITE);file.store_string(JSON.stringify({"seed":value,"version":Layout.VERSION}))
func focus(index:int)->void:
	overview=index==-1;player.input_blocked=overview
	camera.position_smoothing_enabled=false
	if overview:player.position=Layout.SIZE*.5;camera.zoom=Vector2.ONE*.165
	else:
		camera.zoom=Vector2.ONE
		if index>=0:player.position=points[index]
		elif index==-2:player.position=layout.spawn
	camera.reset_smoothing()
	status.text="V0.2 · Seed %s · 候选地表 / 已确认树石角色\n0 总览 · 1森林 2山地 3原野 4水岸 · 5林缘 6山麓 7林山交界 · 8出生点\nWASD / 方向键移动 · Shift 奔跑 · 滚轮缩放"%seed_value
func _unhandled_key_input(event:InputEvent)->void:
	if not event.is_pressed():return
	if event.keycode==KEY_0:focus(-1)
	elif event.keycode>=KEY_1 and event.keycode<=KEY_7:focus(event.keycode-KEY_1)
	elif event.keycode==KEY_8:focus(-2)
func _process(_delta:float)->void:
	for prop in nature.get_children():
		if prop.has_method("update_occlusion"):prop.update_occlusion(player.position)


