extends "res://scripts/world.gd"
## Isolated current-build demonstration; no player identity/items/environment IO.
func load_world_identity(_path: String=WORLD_ID_PATH) -> void:
	world_seed=271828;map_cells=1024;persistent_world=false
func save_world_identity(_path: String=WORLD_ID_PATH) -> void: pass
func _ready() -> void:
	super._ready()
	for id in ["stone_hammer","fishing_rod"]:item_service.inventory.add(id,1)
	for id in ["lake_fish","cabbage","wood","stone","flint"]:item_service.inventory.add(id,12)
	var row: Dictionary=item_service.builds.states.get("abandoned:v1:0:0",{})
	if not row.is_empty():
		player.position=Vector2(row.x,row.y)+Vector2(0,70)
		player.reset_physics_interpolation();player.camera.reset_smoothing();stream.update_target(player.position)
	item_service.inventory.changed.emit()
