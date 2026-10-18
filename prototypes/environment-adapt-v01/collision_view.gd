extends Node2D
var lab:Node2D
func _draw()->void:
	if not is_instance_valid(lab) or not lab.show_collisions:return
	for p in lab.samples:
		if not p.visible:continue
		var points:=PackedVector2Array()
		for v in p.collision.polygon:points.append(p.position+v)
		points.append(points[0]);draw_polyline(points,Color(.96,.48,.21,.9),1.5,true)
