extends "res://scripts/world.gd"
func load_world_identity(_path:String=WORLD_ID_PATH)->void:
	world_seed=int(Engine.get_meta("world_v04_seed",271828))
	map_cells=1024
	persistent_world=false
func save_world_identity(_path:String=WORLD_ID_PATH)->void:pass
