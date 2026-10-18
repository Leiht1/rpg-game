extends Control
## Native UI debug symbols: no unapproved bitmap art and no item names in slots.
var symbol := 0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var center := size * .5
	var colors := [Color("bf6d60"),Color("9b7855"),Color("c38c50"),Color("b66b4d"),Color("9a7956"),Color("a78a63"),Color("8e9891"),Color("859a65"),Color("737d83"),Color("6d986a"),Color("91714d"),Color("c2a666")]
	draw_circle(center,12,colors[symbol % colors.size()])
	draw_arc(center,12,0,TAU,24,Color("68583e"),1.5,true)
	for i in 1 + symbol % 4:
		draw_line(center+Vector2(-6+i*4,-5),center+Vector2(-6+i*4,5),Color("fff2d0"),2,true)
	if symbol >= 4: draw_line(center+Vector2(-6,0),center+Vector2(6,0),Color("fff2d0"),2,true)
	if symbol >= 8: draw_circle(center+Vector2(0,-8),2,Color("fff2d0"))
