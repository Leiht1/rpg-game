extends RefCounted
## Server-owned attack timeline. A cancelled attack never produces a late hit.
var elapsed := 0.0
var active := false
var definition: Dictionary = {}
var hit_targets: Dictionary = {}
var sequence := -1
var facing := Vector2.DOWN
var hit_window := false

func begin(request_sequence: int, weapon: Dictionary, direction: Vector2) -> bool:
	if active or request_sequence <= sequence or not direction.is_finite() or direction.length_squared() < 0.001:
		return false
	for key in ["windup", "active", "recovery"]:
		var value := float(weapon.get(key, -1.0))
		if not is_finite(value) or value < 0.0:
			return false
	if float(weapon.active) <= 0.0:
		return false
	sequence = request_sequence
	definition = weapon.duplicate(true)
	facing = direction.normalized()
	elapsed = 0.0
	hit_window = false
	hit_targets.clear()
	active = true
	return true

func advance(delta: float) -> bool:
	hit_window = false
	if not active or not is_finite(delta) or delta <= 0.0:
		return false
	var previous := elapsed
	elapsed += delta
	var start := float(definition.windup)
	var finish := start + float(definition.active)
	var crossed_hit_window := previous < finish and elapsed >= start
	hit_window = crossed_hit_window
	if elapsed >= finish + float(definition.recovery):
		active = false
	return crossed_hit_window

func claim_target(target_id: String) -> bool:
	if target_id.is_empty() or hit_targets.has(target_id):
		return false
	if not hit_window:
		return false
	hit_targets[target_id] = true
	return true

func cancel() -> void:
	active = false
	hit_window = false
	definition.clear()
	hit_targets.clear()
