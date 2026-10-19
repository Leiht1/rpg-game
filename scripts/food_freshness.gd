extends RefCounted
## Fractional spoilage travels with each stack; storage changes only its rate.
static func cooked(db: ItemDatabase, id: String) -> bool:
	return db.item(id).get("food_kind","")=="cooked"

static func normalize(db: ItemDatabase, value: Dictionary) -> bool:
	if value.is_empty() or not cooked(db,str(value.get("item_id",""))): return not value.has("spoilage")
	var n = value.get("spoilage",0.0)
	if not (n is int or n is float) or not is_finite(float(n)) or n<0 or n>1: return false
	value.spoilage=float(n)
	return true

static func same(a: Dictionary, b: Dictionary) -> bool:
	var x := a.duplicate(true);var y := b.duplicate(true)
	x.erase("count");y.erase("count")
	return x==y and not a.has("instance_id") and not a.has("lamp_id")

static func matches(a: Dictionary, b: Dictionary) -> bool:
	var x := a.duplicate(true);var y := b.duplicate(true)
	x.erase("spoilage");y.erase("spoilage")
	return x==y

static func advance(db: ItemDatabase, value: Dictionary, minutes: float, chilled: bool=false) -> void:
	if value.is_empty() or not cooked(db,str(value.get("item_id",""))): return
	var days := 7.0 if chilled else float(db.item(value.item_id).get("shelf_days",2.5))
	value.spoilage=minf(1.0,float(value.get("spoilage",0))+minutes/(days*1440.0))

static func rotten(value: Dictionary) -> bool:
	return float(value.get("spoilage",0))>=1.0

static func effects(db: ItemDatabase, value: Dictionary) -> Dictionary:
	var effect: Dictionary=db.item(str(value.get("item_id",""))).get("effects",{}).duplicate(true)
	if rotten(value):
		var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/industry_rules.json"))
		effect.hunger=float(effect.get("hunger",0))*float(rules.rotten_hunger_ratio)
		effect.health=-float(rules.rotten_damage);effect.discomfort=float(rules.discomfort_seconds)
	return effect
