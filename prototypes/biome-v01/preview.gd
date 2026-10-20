extends Node2D
const Layout=preload("res://prototypes/biome-v01/layout.gd")
const Prop=preload("res://scripts/nature_prop.gd")
var camera:Camera2D
var labels:Array[Label]=[]
func _ready()->void:
	var ground:=ColorRect.new()
	ground.size=Layout.SIZE
	var mat:=ShaderMaterial.new()
	mat.shader=load("res://prototypes/biome-v01/ground.gdshader")
	mat.set_shader_parameter("ground_tex",load("res://assets/environment/stylized_v3/grass.png"))
	ground.material=mat
	add_child(ground)
	var sorting:=Node2D.new()
	sorting.y_sort_enabled=true
	add_child(sorting)
	for entry in Layout.objects(271828):
		var prop:=Prop.new()
		var file:String=entry.kind+"_"+str(entry.variant)
		if entry.kind=="flowers":file="tuft_0"
		if entry.kind=="leaves":file="tuft_1"
		prop.texture=load("res://assets/environment/stylized_v3/"+file+".png")
		prop.position=entry.p
		prop.candidate_mode=1
		prop.kind=0 if entry.kind=="tree" else (2 if entry.kind=="rock" else 4)
		prop.display_size=Vector2(prop.texture.get_size())
		sorting.add_child(prop)
	for i in 5:
		var label:=Label.new()
		label.text=Layout.NAMES[i]
		label.position=Layout.CENTERS[i]-Vector2(90,35)
		label.add_theme_font_size_override("font_size",30)
		label.add_theme_color_override("font_color",Color("f9f7df"))
		label.add_theme_color_override("font_outline_color",Color("344d3d"))
		label.add_theme_constant_override("outline_size",8)
		add_child(label)
		labels.append(label)
	camera=Camera2D.new()
	add_child(camera)
	focus(-1)
	var ui:=CanvasLayer.new()
	add_child(ui)
	var text:=Label.new()
	text.text="风栖原野 · 五区布局样例 V0.1   |   0 总览 · 1–5 区域近景 · L 区域名称\nSeed 271828 · 静态美术规划候选 · 复用已确认素材 / 水岸为色面示意"
	text.position=Vector2(20,12)
	text.add_theme_color_override("font_outline_color",Color("293b30"))
	text.add_theme_constant_override("outline_size",6)
	ui.add_child(text)
func focus(index:int)->void:
	camera.position=Layout.SIZE*.5 if index<0 else Layout.CENTERS[index]
	camera.zoom=Vector2.ONE*(.51 if index<0 else 1.0)
	if index>=0:camera.position=camera.position.clamp(Vector2(640,360),Layout.SIZE-Vector2(640,360))
func _unhandled_key_input(event:InputEvent)->void:
	if not event.is_pressed():return
	for i in 6:
		if event.keycode==KEY_0+i:focus(i-1)
	if event.keycode==KEY_L:
		for label in labels:label.visible=not label.visible


