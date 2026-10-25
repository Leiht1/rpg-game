extends Control
const Rules=preload("res://scripts/season_rules.gd")
const INK=Color("514b3d")
var simulation: Node
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if not is_instance_valid(simulation):return
	var center := Vector2(49,49)
	var radius: float=Rules.data.visual.dial_radius
	var date: Dictionary=simulation.season_date()
	draw_circle(center+Vector2(0,3),radius+4,Color(0,0,0,.16))
	draw_circle(center,radius+4,INK)
	draw_circle(center,radius+2,Color("d7cba8"))
	var font := ThemeDB.fallback_font
	for i in 4:
		var row: Dictionary=Rules.data.seasons[i]
		var points := PackedVector2Array([center])
		for j in 25:points.append(center+Vector2.from_angle(-PI/2+(float(i)+float(j)/24)*PI/2)*radius)
		draw_colored_polygon(points,Color(row.color))
		draw_line(center,points[1],INK,1.3,true)
		var at := center+Vector2.from_angle(-PI/4+float(i)*PI/2)*27
		draw_string(font,at+Vector2(-8,6),str(row.name),HORIZONTAL_ALIGNMENT_LEFT,-1,17,INK)
		if i==int(date.index):draw_arc(center,radius-3,-PI/2+i*PI/2+.08,-PI/2+(i+1)*PI/2-.08,28,Color("fff4d6"),3,true)
	draw_circle(center,7,INK)
	var direction := Vector2.from_angle(-PI/4+float(date.index)*PI/2)
	draw_line(center,center+direction*15,Color("fff4d6"),3,true)
	var label := "%s · 第%d天" %[Rules.data.seasons[date.index].name,date.day]
	var width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	draw_string(font,Vector2(center.x-width/2,109),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,INK)
