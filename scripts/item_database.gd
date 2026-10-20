class_name ItemDatabase
extends RefCounted
## Immutable definitions; stack slots contain IDs/counts; equipment keeps separate instance state.
var definitions: Dictionary = {}
var errors: Array[String] = []

func _init(path: String = "res://data/items.json") -> void:
	var rows = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not rows is Array:
		errors.append("物品数据不是数组")
		return
	rows.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://data/merchant_items.json")))
	for row in rows:
		if not row is Dictionary or not row.has("item_id"):
			errors.append("物品缺少 ID")
			continue
		var id := str(row.item_id)
		if definitions.has(id):
			errors.append("重复 ID: " + id)
			continue
		for field in ["name","category","description","icon","world_visual","max_stack","usable","use_action","consumable","tags","rarity","drop_rules"]:
			if not row.has(field): errors.append(id + " 缺少 " + field)
		if int(row.get("max_stack",0)) < 1: errors.append(id + " 堆叠数无效")
		if row.get("equippable",false):
			for field in ["equip_slot","equipment_type","capabilities","action_id","visual_id","stats","durability"]:
				if not row.has(field): errors.append(id+" 缺少装备字段 "+field)
			if int(row.max_stack)!=1: errors.append(id+" 装备必须独占实例")
		definitions[id] = row.duplicate(true)

func item(id: String) -> Dictionary:
	return definitions.get(id,{}).duplicate(true)

func ids() -> Array:
	return definitions.keys()

