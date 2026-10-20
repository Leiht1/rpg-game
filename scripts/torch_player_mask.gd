extends Node2D
var player: Node2D
func _draw() -> void:
	if is_instance_valid(player):paint(player.character,player.get_viewport().get_canvas_transform())
func paint(node: Node, canvas: Transform2D) -> void:
	if node is Sprite2D and node.is_visible_in_tree() and node.texture and not node.has_meta("item_id"):
		var sprite: Sprite2D=node
		draw_set_transform_matrix(canvas*sprite.global_transform)
		var rect := sprite.get_rect()
		if sprite.flip_h:rect.position.x+=rect.size.x;rect.size.x=-rect.size.x
		if sprite.flip_v:rect.position.y+=rect.size.y;rect.size.y=-rect.size.y
		draw_texture_rect(sprite.texture,rect,false)
	for child in node.get_children():paint(child,canvas)
