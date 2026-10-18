extends RefCounted
static var cached: Dictionary={}
static func data() -> Dictionary:
	if cached.is_empty(): cached=JSON.parse_string(FileAccess.get_file_as_string("res://data/sleep_rules.json"))
	return cached
static func facility(kind: String) -> Dictionary:
	return data().facilities.get(kind,{})
