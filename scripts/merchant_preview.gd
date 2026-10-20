extends "res://scripts/world.gd"
func load_world_identity(_path: String=WORLD_ID_PATH) -> void:
	world_seed=447349832;map_cells=1024;persistent_world=false
	Engine.set_meta("merchant_preview",true)
func save_world_identity(_path: String=WORLD_ID_PATH) -> void:pass
func _ready() -> void:
	super._ready()
	while not started:await get_tree().process_frame
	var s: Node=item_service
	for i in 40:s.inventory.slots[i]={}
	for id in ["gold_ingot","silver_ingot","copper_parts","wool"]:s.inventory.add(id,90)
	for id in ["roasted_fish","smoked_fish","vegetable_fish_soup"]:s.inventory.add(id,20)
	# Move the preview player to the merchant, leaving global spawn selection intact.
	if not s.merchant.state.is_empty():
		player.position=Vector2(s.merchant.state.x,s.merchant.state.y)+Vector2(0,55)
	stream.update_target(player.position);player.camera.reset_smoothing();player.reset_physics_interpolation()
	s.inventory.changed.emit()
	var label := Label.new();label.text="异次元商人 · 独立试玩 · 交易材料已备齐 · 不写入玩家存档";label.position=Vector2(270,12);ui.add_child(label)

