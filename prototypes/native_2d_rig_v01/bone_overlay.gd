@tool
extends Node2D

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	var skeleton := get_parent().get_node_or_null("Skeleton2D")
	if skeleton == null:
		return
	for bone in skeleton.find_children("*", "Bone2D", true, false):
		var point: Vector2 = to_local(bone.global_position)
		var color := Color("157b81") if str(bone.name).begins_with("Near") else Color("b36a20")
		if bone.get_parent() is Bone2D:
			var start: Vector2 = to_local(bone.get_parent().global_position)
			draw_line(start, point, Color(1, 1, 1, .9), 1.0, true)
			draw_line(start, point, color, .45, true)
		draw_circle(point, .85, color, true, -1.0, true)
		draw_circle(point, .4, Color.WHITE, true, -1.0, true)
