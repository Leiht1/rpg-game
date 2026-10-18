extends Button
## Native interface glyphs, drawn at display size without raster asset generation.
const ItemSkin = preload("res://scripts/item_ui_style.gd")
var symbol := "bag"

func _ready() -> void:
	custom_minimum_size=Vector2(52,52)
	size_flags_vertical=Control.SIZE_SHRINK_CENTER
	for state in ["normal","hover","pressed","hover_pressed","focus"]:
		var style := ItemSkin.button_style("pressed" if state in ["pressed","hover_pressed"] else state,true)
		add_theme_stylebox_override(state,style)

func _draw() -> void:
	var c := size*.5
	var ink := Color("65563b")
	if symbol=="bag":
		var body := ItemSkin.slot(false,false)
		draw_style_box(body,Rect2(c+Vector2(-12,-9),Vector2(24,25)))
		draw_polyline(PackedVector2Array([c+Vector2(-6,-9),c+Vector2(-6,-14),c+Vector2(6,-14),c+Vector2(6,-9)]),ink,2,true)
		draw_line(c+Vector2(-10,-2),c+Vector2(10,-2),ink,2,true)
		draw_style_box(body,Rect2(c+Vector2(-8,3),Vector2(16,9)))
		draw_line(c+Vector2(-2,3),c+Vector2(2,3),Color("f6e6b7"),2,true)
	else:
		var points := PackedVector2Array([c+Vector2(-15,-10),c+Vector2(-5,-14),c+Vector2(5,-10),c+Vector2(15,-14),c+Vector2(15,10),c+Vector2(5,14),c+Vector2(-5,10),c+Vector2(-15,14)])
		draw_colored_polygon(points,Color("dacba4"))
		draw_colored_polygon(PackedVector2Array([points[1],points[2],points[5],points[6]]),Color("a6b68b"))
		var outline := points.duplicate();outline.append(points[0])
		draw_polyline(outline,ink,2,true)
		draw_line(points[1],points[6],ink,1.5,true)
		draw_line(points[2],points[5],ink,1.5,true)
		draw_polyline(PackedVector2Array([c+Vector2(-11,7),c+Vector2(-3,0),c+Vector2(7,3),c+Vector2(11,-5)]),Color("fff5d5"),2,true)

func _make_custom_tooltip(text_value: String) -> Object:
	var panel := PanelContainer.new()
	panel.theme=ItemSkin.theme()
	panel.add_theme_stylebox_override("panel",ItemSkin.tooltip(18))
	var label := Label.new()
	label.text=text_value
	panel.add_child(label)
	return panel
