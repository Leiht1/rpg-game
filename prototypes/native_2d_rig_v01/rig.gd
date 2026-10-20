@tool
extends Node2D
## Reusable native rig. All motion lives in hero_rig.tscn's AnimationPlayer.

@export_enum("Olive jacket", "Teal pullover") var outfit: int = 0:
	set(value):
		outfit = value
		if is_inside_tree():
			apply_outfit()
@export var show_bones: bool = false:
	set(value):
		show_bones = value
		if has_node("BoneOverlay"):
			$BoneOverlay.visible = value

func _ready() -> void:
	apply_outfit()
	if not has_node("BoneOverlay"):
		var overlay := Node2D.new()
		overlay.name = "BoneOverlay"
		overlay.set_script(preload("res://bone_overlay.gd"))
		overlay.z_index = 100
		add_child(overlay)
	$BoneOverlay.visible = show_bones

func apply_outfit() -> void:
	if not has_node("Meshes"):
		return
	for mesh in $Meshes.get_children():
		var garment := int(mesh.get_meta("outfit", -1))
		mesh.visible = garment < 0 or garment == outfit

func animation_player() -> AnimationPlayer:
	return $AnimationPlayer
