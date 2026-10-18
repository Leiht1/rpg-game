extends Node2D
## Explicit development marker, never a substitute approved plant illustration.
var caption := ""
var growing := false
var tint := Color("ead791")

func _ready() -> void:
	var label := Label.new()
	label.text = "临·" + caption
	label.position = Vector2(-44,-34)
	label.size.x = 88
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",12)
	label.add_theme_color_override("font_color",Color("fff6d9"))
	label.add_theme_color_override("font_shadow_color",Color("443e30"))
	label.add_theme_constant_override("shadow_outline_size",4)
	add_child(label)

func _draw() -> void:
	# Abstract location symbol, anchored to the walkable ground without a black disc.
	var shape := PackedVector2Array([Vector2(-9,-5),Vector2(0,-11),Vector2(9,-5),Vector2(0,1),Vector2(-9,-5)])
	draw_colored_polygon(shape,tint)
	draw_polyline(shape,Color("756349"),1.5,true)
	if growing: draw_line(Vector2(0,-5),Vector2(0,-18),Color("f7edc3"),2,true)
