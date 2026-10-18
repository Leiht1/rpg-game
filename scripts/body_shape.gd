extends RefCounted
## Absolute visual-only scale: no parent joints, limb or grip changes.
static var rules: Dictionary=preload("res://scripts/body_rules.gd").load_rules()
static func apply(rig: Node2D, value: float) -> void:
	for entry in [["Visual/Pelvis/Torso",rules.torso_width_range],["Visual/Pelvis/Head/Sprite",rules.head_width_range]]:
		var sprite: Sprite2D=rig.get_node(entry[0])
		var width := lerpf(1.0,float(entry[1][0 if value<0 else 1]),absf(value))
		sprite.scale=Vector2(.25*width,.25)

