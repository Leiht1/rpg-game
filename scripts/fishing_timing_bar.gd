extends Control
## Fixed-size, lightweight timing UI; colours follow the existing paper/field palette.
var marker := .5
var safe_center := .52
var safe_width := .21
var feedback := 0.0

func _ready() -> void:
	custom_minimum_size=Vector2(316,28)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var bounds := Rect2(0,0,size.x,28)
	var track := StyleBoxFlat.new()
	track.bg_color=Color("b9b596");track.set_corner_radius_all(7)
	draw_style_box(track,bounds)
	var safe := StyleBoxFlat.new()
	safe.bg_color=Color("719865");safe.set_corner_radius_all(5)
	draw_style_box(safe,Rect2((safe_center-safe_width*.5)*size.x,3,safe_width*size.x,22))
	# A single moving circle, with a dark rim readable on both regions.
	var at := Vector2(8+marker*(size.x-16),14)
	draw_circle(at,10,Color("4e5547"),true,-1,true)
	draw_circle(at,7,Color("f6ecd0") if feedback<=0 else Color("eac46b"),true,-1,true)

func is_hit() -> bool:
	# Test the circle centre against the same pixel-space region shown above.
	var displayed := (8+marker*(size.x-16))/maxf(1,size.x)
	return absf(displayed-safe_center)<=safe_width*.5
