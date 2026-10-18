extends "res://scripts/world.gd"

func _ready() -> void:
	Engine.set_meta("energy_icon_preview","res://prototypes/energy-icon-v1/processed/clean.png")
	super._ready()

func load_world_identity(_path: String=WORLD_ID_PATH) -> void:
	world_seed=271828
	map_cells=1024
	persistent_world=false

func save_world_identity(_path: String=WORLD_ID_PATH) -> void:
	pass
