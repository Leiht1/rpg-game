extends RefCounted
## Counts are compared to their authoritative source, never frozen historical totals.
static func rows(path: String) -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
static func item_count() -> int:
	return rows("res://data/items.json").size()+rows("res://data/merchant_items.json").size()
static func recipe_count(path: String="res://data/recipes.json") -> int:
	return rows(path).size()
static func viewport_size() -> Vector2i:
	return Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),ProjectSettings.get_setting("display/window/size/viewport_height"))
