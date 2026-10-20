extends RefCounted
const PATH := "res://prototypes/character-creation-v1/catalog.json"
static var data: Dictionary = {}
static func rules() -> Dictionary:
	if data.is_empty(): data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return data
static func default_look() -> Dictionary:
	return {"gender":"male","hair_id":"male_natural","skin_id":"skin_2"}
static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.get("gender") not in ["male","female"]: return false
	var hair: Dictionary=rules().hair.get(value.get("hair_id",""),{})
	return not hair.is_empty() and hair.gender==value.gender and rules().skin.has(value.get("skin_id",""))
static func enable_candidate(database: ItemDatabase) -> void:
	# Only the independent creation entry calls this, before inventory restore.
	var row: Dictionary=database.definitions.modern_outfit
	row.equippable=true;row.equip_slot="outfit";row.equipment_type="outfit";row.visual_id="candidate:modern_outfit"
