extends Node2D
var rigs: Array = []
var facing := "front"
var action := "breathe"
var rate := 1.0
var stopped := false
var joints := false
var phase := 0.0
var status: Label
var debug_overlay:Node2D
func _ready() -> void:
	for s in [1.0,4.0]:
		var r = load("res://character.tscn").instantiate()
		r.position = Vector2(190,410) if s == 1.0 else Vector2(600,95)
		r.scale = Vector2.ONE * s
		add_child(r)
		rigs.append(r)
	debug_overlay=Node2D.new()
	debug_overlay.z_index=100
	add_child(debug_overlay)
	debug_overlay.draw.connect(draw_pivots)
	var ui := CanvasLayer.new()
	add_child(ui)
	var box := VBoxContainer.new()
	box.position = Vector2(28,22)
	ui.add_child(box)
	box.add_theme_color_override("font_color",Color(0.19,0.25,0.2))
	var title := Label.new()
	title.add_theme_color_override("font_color",Color(0.19,0.25,0.2))
	title.text = "简化卡通角色动画实验 V1 · 独立预览"
	title.add_theme_font_size_override("font_size",26)
	box.add_child(title)
	var dirs := HBoxContainer.new()
	box.add_child(dirs)
	for item in [["正面","front"],["右侧","side"],["左侧","left"]]:
		button(dirs,item[0],func(): set_direction(item[1]))
	var acts := HBoxContainer.new()
	box.add_child(acts)
	for item in [["呼吸","breathe"],["行走","walk"],["奔跑","run"],["挥手","wave"]]:
		button(acts,item[0],func(): set_action(item[1]))
	var controls := HBoxContainer.new()
	box.add_child(controls)
	button(controls,"正常速度",func(): rate=1.0; stopped=false; sync_speed())
	button(controls,"半速",func(): rate=0.5; stopped=false; sync_speed())
	button(controls,"暂停 / 继续",func(): stopped=not stopped; sync_speed())
	button(controls,"关节 / 支点",func(): joints=not joints; queue_redraw())
	status=Label.new()
	status.add_theme_color_override("font_color",Color(0.19,0.25,0.2))
	box.add_child(status)
	var note:=Label.new()
	note.add_theme_color_override("font_color",Color(0.19,0.25,0.2))
	note.text="左：128×128 原始尺寸    右：4 倍放大\n同一套部件 / 原生 AnimationPlayer / 脚底参考 (64,112)\n切换动作以 0.14 秒混合；方向切换保留周期相位。"
	note.position=Vector2(32,590)
	ui.add_child(note)
	set_action(action)
func button(parent: Node, text: String, callback: Callable) -> void:
	var b:=Button.new()
	b.text=text
	b.pressed.connect(callback)
	parent.add_child(b)
func set_direction(d: String) -> void:
	var p: AnimationPlayer=rigs[0].get_node("AnimationPlayer")
	phase=p.current_animation_position/p.current_animation_length if p.current_animation_length>0 else 0.0
	facing=d
	for r in rigs:
		r.get_node("Visual").scale.x=-1.0 if d=="left" else 1.0
		var v: Node2D=r.get_node("Visual")
		v.position.x=128.0 if d=="left" else 0.0
		var ap:AnimationPlayer=r.get_node("AnimationPlayer")
		var n=("front" if d=="front" else "side")+"_"+action
		ap.play(n,0.0)
		ap.seek(phase*ap.get_animation(n).length,true)
	sync_speed()
func set_action(a: String) -> void:
	action=a
	for r in rigs:
		var ap:AnimationPlayer=r.get_node("AnimationPlayer")
		ap.play(("front" if facing=="front" else "side")+"_"+a,0.0 if stopped else 0.14)
		if stopped:ap.seek(0,true)
	sync_speed()
func sync_speed() -> void:
	for r in rigs:
		r.get_node("AnimationPlayer").speed_scale=0.0 if stopped else rate
func _process(_dt: float) -> void:
	debug_overlay.queue_redraw()
	status.text="%s · %s · %s" % [facing,action,"暂停" if stopped else str(rate)+"×"]
	queue_redraw()
func _draw() -> void:
	for r in rigs:
		var origin:Vector2=r.position
		var s:float=r.scale.x
		draw_line(origin+Vector2(8,112)*s,origin+Vector2(120,112)*s,Color(0.45,0.55,0.43),1.0)
func draw_pivots() -> void:
	if not joints:return
	for r in rigs:
		for n in ["Pelvis","Pelvis/Head","Pelvis/ArmL","Pelvis/ArmR","LegL","LegR"]:
			var joint:Node2D=r.get_node("Visual/"+n)
			var pt:=to_local(joint.global_position)
			debug_overlay.draw_circle(pt,3.5,Color(1,.3,.15))
			debug_overlay.draw_line(pt-Vector2(7,0),pt+Vector2(7,0),Color(1,.3,.15),1)
