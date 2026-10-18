extends Control
var screen: Control
func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return screen.can_drop_on_ground(screen.drag_pointer,data)
func _drop_data(_at: Vector2, data: Variant) -> void:
	screen.drop_on_ground(data,screen.drag_pointer)
