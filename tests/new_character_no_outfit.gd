extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	var creation=load("res://scripts/character_creation.gd").new()
	creation.selection_only=true
	creation.save_path="res://reports/.tmp/network-sync-v3/isolated-character.json"
	root.add_child(creation)
	var appearance:Dictionary=load("res://scripts/character_catalog.gd").default_look()
	var record:Dictionary={"version":1,"active_character_id":"isolated-new","world_id":"isolated-world","seed":271828,"map_cells":128,"characters":{"isolated-new":{"world_id":"isolated-world","appearance":appearance,"test_outfit_granted":false,"outfit_id":""}}}
	if not await creation.open_world(record,true):
		push_error(creation.status.text);quit(1);return
	assert(creation.world.item_service.inventory.count_item("modern_outfit")==0)
	assert(creation.world.item_service.inventory.slots.all(func(slot):return slot.is_empty()))
	assert(creation.world.record.characters["isolated-new"].test_outfit_granted)
	assert(FileAccess.file_exists(creation.save_path))
	print("NEW_CHARACTER_NO_OUTFIT_PASS empty inventory, initialization marker, isolated save")
	creation.world.persistent_world=false;creation.queue_free();await process_frame;quit()
