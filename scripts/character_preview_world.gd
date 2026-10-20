extends "res://scripts/world.gd"
var record: Dictionary={}
var creating := true
var isolated_path := "user://character-preview-v1/state.json"
func load_world_identity(_path: String=WORLD_ID_PATH) -> void:
	world_seed=int(record.seed);map_cells=int(record.map_cells);persistent_world=not creating
	set_meta("character_preview",true)
	set_meta("character_save_path",isolated_path)
func save_world_identity(_path: String=WORLD_ID_PATH) -> void: pass
func parse_arguments() -> void: pass
func _ready() -> void:
	super._ready()
	player.character_look=record.characters[record.active_character_id].appearance.duplicate(true)
	player.update_animation()
	item_ui.update_portrait(0)
	title.text="风栖原野 · 人物与换装候选"
func character_snapshot() -> Dictionary:
	var next: Dictionary=record.duplicate(true)
	var active: Dictionary=next.characters[next.active_character_id]
	active.outfit_id=item_service.inventory.equipment.get("outfit",{}).get("item_id","")
	# Original root inventory/position fields belong to this explicitly named player.
	return {"character_session":next,"player_state_owner":next.active_character_id}
func _unhandled_input(event: InputEvent) -> void:
	# This preview resumes ONE character's assigned world. Reset is an explicit
	# separate backup operation; the historical N shortcut must not change Seed.
	if event is InputEventKey and event.physical_keycode==KEY_N:
		get_viewport().set_input_as_handled();return
	super._unhandled_input(event)
func _process(delta: float) -> void:
	super._process(delta)
	hint.text=hint.text.replace(" · N 新世界","")
func safe_entry() -> bool:
	var p: Vector2=player.position
	if generator.sample(p).z>.03 or generator.coast_distance(p)<24: return false
	if not item_service.ground_clear(p,20,item_service.nearby_props(p)): return false
	for row in item_service.builds.states.values():
		if row.layer=="ground":continue
		var bounds: Rect2=item_service.builds.footprint_rect(row)
		bounds.position+=Vector2(row.x,row.y)
		if bounds.grow(24).has_point(p):return false
	return true
