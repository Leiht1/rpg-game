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
var front_arm: Node2D
var front_arm_was_behind := false
var front_arm_position := Vector2.ZERO
var front_free_arm: Node2D
var front_free_arm_position := Vector2.ZERO
var front_free_arm_rotation := 0.0
var front_free_source: Sprite2D
var front_free_was_visible := true
var front_free_hand: Sprite2D

func release_pose() -> void:
	if is_instance_valid(front_arm):
		front_arm.show_behind_parent=front_arm_was_behind
		front_arm.position=front_arm_position
	if is_instance_valid(front_free_arm):
		front_free_arm.position=front_free_arm_position
		front_free_arm.rotation=front_free_arm_rotation
	if is_instance_valid(front_free_source): front_free_source.visible=front_free_was_visible
	if is_instance_valid(front_free_hand): front_free_hand.hide()
	front_free_arm=null;front_free_source=null
	front_arm=null
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
	if not textures.has(path): textures[path]=preload("res://scripts/candidate_art.gd").texture(path) if path.begins_with("res://prototypes/industry-v1/") else load(path)
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
	# All registered main-hand tools share this policy, regardless of ID or action.
	# Animation sampling may put ArmR behind Pelvis; front-facing holding must override it.
	if facing=="front":
		if front_arm!=arm:
			front_arm=arm;front_arm_was_behind=arm.show_behind_parent;front_arm_position=arm.position
		arm.show_behind_parent=false
		if not action.is_empty(): align_front_shoulders(character,arm)
	if action in row.get("aim_forward_actions",[]):
		# Aim in rig space so mirroring and the sampled arm rotation preserve the blade direction.
		var visual: Node2D=character.get_node("Visual")
		var forward := Vector2.DOWN if facing=="front" else Vector2.UP if facing=="back" else Vector2.RIGHT
		var local_forward := arm.to_local(visual.to_global(forward))-arm.to_local(visual.global_position)
		tool.rotation=local_forward.angle()+PI*.5
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

func align_front_shoulders(character: Node2D, arm: Node2D) -> void:
	var pelvis: Node2D=character.get_node("Visual/Pelvis")
	var torso: Sprite2D=pelvis.get_node("Torso")
	# Both shoulder mounts stay inside the current shirt silhouette; animated rotations remain.
	# Torso-local source coordinates also follow the existing body-width adjustment.
	arm.position=pelvis.to_local(torso.to_global(Vector2(28,-28)))
	var free_arm: Node2D=pelvis.get_node("ArmL")
	if front_free_arm!=free_arm:
		front_free_arm=free_arm;front_free_arm_position=free_arm.position;front_free_arm_rotation=free_arm.rotation
	free_arm.position=pelvis.to_local(torso.to_global(Vector2(-28,-28)))
	# The empty hand rests outward instead of crossing into the working palm/handle.
	free_arm.rotation=clampf(free_arm.rotation,.08,.24)
	var source: Sprite2D=character.get_node("Visual/ArmLBehind")
	if not is_instance_valid(front_free_hand):
		front_free_hand=Sprite2D.new();front_free_hand.name="FrontFreeArm"
		pelvis.add_child(front_free_hand);pelvis.move_child(front_free_hand,arm.get_index())
	front_free_hand.texture=source.texture;front_free_hand.centered=source.centered;front_free_hand.offset=source.offset
	front_free_hand.flip_h=source.flip_h;front_free_hand.flip_v=source.flip_v
	front_free_hand.texture_filter=source.texture_filter;front_free_hand.modulate=source.modulate
	front_free_hand.global_transform=free_arm.get_node("RearVisualDrive").global_transform
	front_free_hand.show()
	if front_free_source!=source:
		front_free_source=source;front_free_was_visible=source.visible
	source.hide()
