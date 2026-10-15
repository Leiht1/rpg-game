extends Node2D

var texture: Texture2D
var display_size := Vector2.ZERO
var kind := 0
var faded := false

func _draw() -> void:
	if texture == null: return
	var shadow_width := 29.0 if kind < 2 else 20.0
	if kind < 4:
		draw_set_transform(Vector2(5,-2),0,Vector2(1,.34))
		draw_circle(Vector2.ZERO,shadow_width,Color(.18,.25,.17,.14))
		draw_set_transform(Vector2.ZERO)
	draw_texture_rect(texture,Rect2(Vector2(-display_size.x*.5,-display_size.y+8),display_size),false,Color(1,1,1,.48 if faded else 1.0))

func update_occlusion(actor_position: Vector2) -> void:
	if kind > 1: return
	var delta := actor_position-global_position
	var next := delta.y < -5 and delta.y > -display_size.y+20 and absf(delta.x)<display_size.x*.38
	if next != faded:
		faded=next
		queue_redraw()
