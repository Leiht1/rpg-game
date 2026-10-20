extends 'res://scripts/world_map_v3_preview.gd'
func load_world_identity(_path: String=WORLD_ID_PATH) -> void:
	world_seed=int(Engine.get_meta("map_v3_seed",81273));map_cells=int(Engine.get_meta("map_v3_cells",1536));persistent_world=true
	world_id="map-v3-test:%d:%d"%[world_seed,map_cells]
	set_meta('map_art_v3',true);set_meta('isolated_environment',true)
	set_meta('character_save_path',str(Engine.get_meta('map_v3_save','res://reports/world-map-v3/runtime-save.json')))
func _ready() -> void:
	# Skip candidate's initial autosave; the harness verifies explicit transactions.
	super._ready()
func _notification(_what: int) -> void:pass
