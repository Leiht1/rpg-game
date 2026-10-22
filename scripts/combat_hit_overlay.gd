extends CanvasLayer
## Presentation observes only this world's local authoritative body snapshot.
var player: Node2D
var previous_health := -1.0
var remaining := 0.0
var panel: Control

func _ready() -> void:
	layer = 1000
	panel = HitBorder.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

func _process(delta: float) -> void:
	if not is_instance_valid(player) or player.body == null:
		return
	var health := float(player.body.health)
	if previous_health >= 0.0 and health < previous_health - 0.001:
		remaining = 0.65
	previous_health = health
	remaining = maxf(0.0, remaining - delta)
	panel.strength = sin(PI * clampf(remaining / 0.65, 0.0, 1.0))
	panel.queue_redraw()

class HitBorder extends ColorRect:
	var strength := 0.0
	func _ready() -> void:
		material=ShaderMaterial.new();material.shader=preload("res://assets/combat/v1/hit_border.gdshader")
	func _process(_delta: float) -> void:
		material.set_shader_parameter("strength",strength);material.set_shader_parameter("viewport_size",size)
