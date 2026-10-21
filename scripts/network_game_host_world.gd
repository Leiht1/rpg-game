extends "res://scripts/world.gd"
## Isolated server world. Never reads or writes the machine's player saves.
var bootstrap: Dictionary = {}
func load_world_identity(_path: String = WORLD_ID_PATH) -> void:
	world_seed=int(bootstrap.seed)
	map_cells=int(bootstrap.map_cells)
	world_id=str(bootstrap.id)
	persistent_world=false
	set_meta("character_preview",true)
	set_meta("network_rules_host",true)
func save_world_identity(_path: String = WORLD_ID_PATH) -> void: pass
func parse_arguments() -> void: pass
