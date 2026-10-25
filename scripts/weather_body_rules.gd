extends RefCounted
static var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/weather_body_rules.json"))
