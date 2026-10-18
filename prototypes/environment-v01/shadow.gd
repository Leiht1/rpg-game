extends Node2D
var prop:Node2D
func _draw()->void:
	if not is_instance_valid(prop) or not prop.visible or not prop.upper.visible:return
	var opacity:float=.08*prop.modulate.a
	var center:Vector2=prop.position+Vector2(20,12)
	for i in 24:
		var a:=i*TAU/24.;var b:=(i+1)*TAU/24.
		var radius:=Vector2(65,24)
		var ra:=1.+.10*sin(a*3+.7);var rb:=1.+.10*sin(b*3+.7)
		draw_polygon(PackedVector2Array([center,center+Vector2(cos(a),sin(a))*radius*ra,center+Vector2(cos(b),sin(b))*radius*rb]),PackedColorArray([Color(.24,.32,.23,opacity),Color(.24,.32,.23,0),Color(.24,.32,.23,0)]))
