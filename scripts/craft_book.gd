extends RefCounted
## Static recipes only. No player/UI state is saved here.
const MAX_BATCH := 99
var recipes: Dictionary = {}
var errors: Array[String] = []
var database: ItemDatabase
var building_book := false

func _init(db: ItemDatabase, path: String = "res://data/recipes.json") -> void:
	database=db
	building_book=path=="res://data/buildings.json"
	var rows = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not rows is Array:
		errors.append("配方数据不是数组")
		return
	for row in rows:
		var reason := validate(row)
		if not reason.is_empty(): errors.append(reason); continue
		if recipes.has(row.recipe_id): errors.append("重复配方："+str(row.recipe_id)); continue
		recipes[row.recipe_id]=row.duplicate(true)

func validate(row: Variant) -> String:
	if not row is Dictionary: return "配方格式无效"
	for field in ["recipe_id","output_id","output_count","materials","category","conditions","default_unlocked","description"]:
		if not row.has(field): return "配方缺少："+field
	if not row.recipe_id is String or row.recipe_id.is_empty(): return "配方ID无效"
	if not row.output_id is String or database.item(row.output_id).is_empty(): return "成品不存在"
	if not positive_integer(row.output_count): return "产出数量无效"
	if not row.materials is Dictionary or (row.materials.is_empty() and not building_book): return "材料无效"
	for id in row.materials:
		if database.item(str(id)).is_empty() or not positive_integer(row.materials[id]): return "材料定义或数量无效"
		if database.item(str(id)).get("equippable",false): return "不支持消耗装备实例"
	if not row.category is String or row.category.is_empty() or not row.description is String: return "配方分类或描述无效"
	if not row.conditions is Array or not row.default_unlocked is bool: return "制作条件无效"
	if row.conditions.any(func(c):return c not in ["workbench","metal_workbench"]): return "未知制作设施条件"
	var duration = row.get("craft_time",1.5)
	if not (duration is int or duration is float) or not is_finite(float(duration)) or duration<.1 or duration>30: return "制作时间须为0.1–30秒"
	return ""

static func positive_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=1 and value<=9999 and value==floor(value)

func recipe(id: String) -> Dictionary:
	return recipes.get(id,{}).duplicate(true)

func available(category: String = "全部", station: Variant=false) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var kind: String=str(station) if station is String else "workbench" if station is bool and station else ""
	for row in recipes.values():
		var matches: bool=row.conditions==[kind] if kind=="metal_workbench" else row.conditions.is_empty() or row.conditions==[kind]
		if row.default_unlocked and matches and (category=="全部" or row.category==category): result.append(row.duplicate(true))
	return result

func categories(station: Variant=false) -> Array[String]:
	var result: Array[String]=["全部"]
	for row in available("全部",station):
		if not result.has(row.category): result.append(row.category)
	return result
