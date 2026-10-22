extends RefCounted
## Pure authoritative calculations. Callers own persistence and request receipts.
const CONFIG_PATH := "res://data/combat_rules.json"

static func load_rules() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))

static func damage_result(health: float, damage: float, duel: bool=false, duel_floor: float=1.0) -> Dictionary:
	if not is_finite(health) or not is_finite(damage) or health <= 0.0 or damage <= 0.0:
		return {"accepted":false,"health":health,"damage":0.0,"lethal":false}
	var remaining := maxf(maxf(1.0,duel_floor) if duel else 0.0, health-damage)
	remaining=minf(health,remaining)
	return {"accepted":true,"health":remaining,"damage":health-remaining,"lethal":remaining<=0.0}

static func can_hit(origin: Vector2, facing: Vector2, target: Vector2, reach: float, radius: float=0.0) -> bool:
	if not origin.is_finite() or not facing.is_finite() or not target.is_finite():return false
	if not is_finite(reach) or not is_finite(radius) or reach<=0.0 or radius<0.0 or facing.length_squared()<0.001:return false
	var offset := target-origin
	return offset.length()<=reach+radius and (offset.length_squared()<0.001 or facing.normalized().dot(offset.normalized())>=0.5)

static func transfers_on_death(definition: Dictionary) -> bool:
	return definition.get("death_retention","retain")=="relic"
