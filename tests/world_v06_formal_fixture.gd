extends "res://scripts/world.gd"
func load_world_identity(_path:String=WORLD_ID_PATH)->void:
	world_seed=int(Engine.get_meta("integration_seed",447349832))
	map_cells=1024
	persistent_world=false
func save_world_identity(_path:String=WORLD_ID_PATH)->void:pass
func choose_entry_point() -> Vector2:
	# Legacy integration fixtures deliberately place objects around this anchor.
	# Keep them loaded without changing the game's randomized player entry.
	return generator.spawn
