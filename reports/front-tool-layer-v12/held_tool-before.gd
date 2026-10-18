extends RefCounted
## Approved prop art, fixed shaft registration, hand-in-front native rig layering.
var definitions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/held_tools.json"))
var textures: Dictionary={}
var posed_arm: Node2D
var stance_offset := 0.0
var strike_layer: Node2D
var strike_tool: Sprite2D
var strike_hand: Sprite2D
var native_hand: Sprite2D
var hand_was_visible := true
var rear_tool: Sprite2D

func release_pose() -> void:
	if is_instance_valid(strike_layer): strike_layer.hide()
	if is_instance_valid(rear_tool): rear_tool.hide()
	if is_instance_valid(native_hand): native_hand.visible=hand_was_visible
	native_hand=null
	if is_instance_valid(posed_arm): posed_arm.rotation-=stance_offset
	stance_offset=0.0

func apply(character: Node2D, inventory: ItemInventory, facing: String, action: String) -> void:
	var arm: Node2D=character.get_node("Visual/Pelvis/ArmR")
	var grip: Node2D=arm.get_node("Grip")
	var tool: Sprite2D=arm.get_node_or_null("HeldTool")
	if tool==null:
		tool=Sprite2D.new()
		tool.name="HeldTool"
		tool.centered=false
		tool.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		arm.add_child(tool)
		# Shaft is behind the original mitten; no global Z override or pasted hand.
		arm.move_child(tool,0)
	tool.hide()
	tool.set_meta("item_id","")
	character.get_node("Visual/Pelvis/ArmR/Grip/Axe").hide()
	if inventory==null: return
	var instance: Dictionary=inventory.equipment.get("main_hand",{})
	if instance.is_empty() or action=="pickup": return
	var definition := inventory.database.item(str(instance.item_id))
	var row: Dictionary=definitions.get(definition.get("visual_id",""),{})
	if row.is_empty(): return
	var path := str(row.texture)
	if not textures.has(path): textures[path]=load(path)
	tool.texture=textures[path]
	var pin: Array=row.grip_px
	tool.offset=-Vector2(pin[0],pin[1])
	tool.scale=Vector2.ONE*float(row.scale)
	var shift: Array=row.hand_offset
	tool.position=grip.position+Vector2(shift[0],shift[1])
	tool.rotation=deg_to_rad(float(row.rotation_degrees))+(grip.rotation if action in ["chop","mine","dig","demolish"] else 0.0)
	tool.set_meta("item_id",instance.item_id)
	tool.show()
	if action.is_empty():
		var view := "side" if facing in ["left","right"] else facing
		stance_offset=deg_to_rad(float(row.stance_degrees.get(view,0)))
		posed_arm=arm
		arm.rotation+=stance_offset
		# Keep the head pointing out from the face while the shoulder lifts the hand.
		tool.rotation-=stance_offset
	if facing=="back": show_behind_legs(character,tool)

func show_behind_legs(character: Node2D, source: Sprite2D) -> void:
	# Same local world sort as the character; only its internal part order changes.
	var visual: Node2D=character.get_node("Visual")
	if not is_instance_valid(rear_tool):
		rear_tool=Sprite2D.new();rear_tool.name="HeldToolBehindLegs"
		rear_tool.show_behind_parent=true
		visual.add_child(rear_tool);visual.move_child(rear_tool,0)
	rear_tool.texture=source.texture;rear_tool.centered=source.centered
	rear_tool.offset=source.offset;rear_tool.flip_h=source.flip_h;rear_tool.flip_v=source.flip_v
	rear_tool.texture_filter=source.texture_filter;rear_tool.modulate=source.modulate
	rear_tool.global_transform=source.global_transform
	rear_tool.set_meta("item_id",source.get_meta("item_id"))
	rear_tool.show();source.hide()

func show_strike_in_front(character: Node2D, sorted_root: Node2D, target: Node2D) -> void:
	var tool: Sprite2D=character.get_node("Visual/Pelvis/ArmR/HeldTool")
	if not tool.visible: return
	if not is_instance_valid(strike_layer):
		strike_layer=Node2D.new();strike_layer.name="ActiveToolContactLayer"
		strike_layer.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		sorted_root.add_child(strike_layer)
		strike_tool=Sprite2D.new();strike_layer.add_child(strike_tool)
		strike_hand=Sprite2D.new();strike_layer.add_child(strike_hand)
	# Local world Y ordering, never a global Z override over scenery or UI.
	strike_layer.global_position=Vector2(0,maxf(character.global_position.y+112,target.global_position.y)+.5)
	strike_layer.show()
	var hand: Sprite2D=character.get_node("Visual/Pelvis/ArmR/Sprite")
	for pair in [[tool,strike_tool],[hand,strike_hand]]:
		var source: Sprite2D=pair[0];var copy: Sprite2D=pair[1]
		copy.texture=source.texture;copy.centered=source.centered;copy.offset=source.offset
		copy.flip_h=source.flip_h;copy.flip_v=source.flip_v
		copy.texture_filter=source.texture_filter;copy.modulate=source.modulate
		copy.global_transform=source.global_transform
		copy.visible=source.visible
	native_hand=hand;hand_was_visible=hand.visible
	tool.hide();hand.hide()

func clear_strike_layer() -> void:
	release_pose()
	if is_instance_valid(strike_layer): strike_layer.queue_free()
