extends RefCounted
## Preview renderer: current side head subtree, with the body entirely concealed.
var head_signature := ""
var face: ShaderMaterial

func render(player: Node2D, session: Dictionary, manager: RefCounted) -> Vector2:
	var vertical: bool=session.get("vertical",false)
	var source: String=session.source
	var group: Node2D=player.get_node_or_null("SleepHeadCover")
	if group==null:
		group=Node2D.new();group.name="SleepHeadCover";group.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;player.add_child(group)
	group.show()
	# Resolve the existing appearance pipeline in side view before copying head layers.
	player.animation_player.play("side_breathe");player.animation_player.seek(0,true)
	player.appearance.apply(player.character,player.equipment_inventory,"right")
	preload("res://scripts/body_shape.gd").apply(player.character,player.body.build)
	var original: Node2D=player.character.get_node("Visual/Pelvis/Head")
	var signature := fingerprint(original)
	var pivot: Node2D=group.get_node_or_null("HeadPivot")
	if pivot==null:
		pivot=Node2D.new();pivot.name="HeadPivot";group.add_child(pivot)
	if signature!=head_signature or pivot.get_child_count()==0:
		for child in pivot.get_children(): pivot.remove_child(child);child.queue_free()
		var copy: Node2D=original.duplicate();copy.name="CurrentHead";pivot.add_child(copy)
		copy.position=-original.get_node("Sprite").position;copy.rotation=0;copy.scale=Vector2.ONE
		var sprite: Sprite2D=copy.get_node("Sprite")
		face=ShaderMaterial.new();face.shader=preload("res://scripts/sleep_face.gdshader")
		face.set_shader_parameter("closure",1.0);face.set_shader_parameter("front_view",false)
		face.set_shader_parameter("side_eye_center",original.get_meta("sleep_eye_center",Vector2(.714,.622)))
		sprite.material=face
		head_signature=signature
	# Body width evolves continuously. Update it in place instead of destroying
	# and recreating the displayed head whenever a tiny scale value changes.
	var displayed: Sprite2D=pivot.get_node("CurrentHead/Sprite")
	displayed.scale=original.get_node("Sprite").scale
	var anchor := Vector2(0,-67) if vertical else Vector2(-34,-36 if source=="wood_bed" else -13)
	if source=="straw_mat": anchor=Vector2(0,-59) if vertical else Vector2(-35,-15)
	if source=="sleeping_bag": anchor=Vector2(-36,-15)
	anchor/= .64
	pivot.position=anchor;pivot.rotation=0 if vertical else -PI/2
	pivot.scale=Vector2.ONE
	var cover: Sprite2D=group.get_node_or_null("Quilt")
	if cover==null:
		cover=Sprite2D.new();cover.name="Quilt";group.add_child(cover)
	var name_value := source+("-vertical" if vertical else "")
	var path := "res://assets/sleep/occupied-v9/"+name_value+".png"
	if source=="forced" or not ResourceLoader.exists(path): path=""
	if path.is_empty():
		group.hide();player.character.show();return Vector2(0,-60)
	cover.show();cover.texture=load(path);cover.region_enabled=false;cover.centered=true
	cover.position=Vector2(0,-36 if source=="wood_bed" else -28) if vertical else Vector2(0,-24 if source=="wood_bed" else -8)
	cover.position/= .64
	cover.scale=Vector2.ONE*float(preload("res://scripts/sleep_rules.gd").facility(source).visual_scale)
	group.move_child(cover,0)
	cover.material=null
	# Replace only the occupied drawing; the original collider/state stays live.
	if manager.visuals.has(session.id) and is_instance_valid(manager.visuals[session.id]): manager.visuals[session.id].hide()
	# Head and cloth are still. Only the controller's zzz marker floats.
	player.character.hide()
	player.queue_redraw()
	return anchor

func fingerprint(node: Node) -> String:
	var value := str(node.name)
	if node is CanvasItem: value+=str(node.modulate)+str(node.visible)
	if node is Sprite2D: value+=str(node.texture)+str(node.flip_h)+str(node.flip_v)
	for child in node.get_children(): value+=fingerprint(child)
	return value
