extends RefCounted
## Online tools follow the authenticated profile, never a nickname or local flag.
static func allowed() -> bool:
	var network=Engine.get_main_loop().root.get_node_or_null("Network")
	if network==null:return OS.has_feature("debug")
	if Engine.has_meta("network_game_controller") or not network.profile.is_empty():
		return network.profile.get("role", "player")=="admin"
	return OS.has_feature("debug")
