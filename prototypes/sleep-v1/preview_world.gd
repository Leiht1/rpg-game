extends "res://scripts/world.gd"
var sleep_samples_ready := false

func _ready() -> void:
	Engine.set_meta("sleep_preview",true)
	super._ready()
	call_deferred("prepare_sleep_samples")

func load_world_identity(path: String=WORLD_ID_PATH) -> void:
	super.load_world_identity(path)
	persistent_world=false

func save_world_identity(_path: String=WORLD_ID_PATH) -> void:
	pass

func prepare_sleep_samples() -> void:
	while not started: await get_tree().process_frame
	var origin: Vector2=player.position
	for id in ["wood","plant_fiber","broad_leaf","stone","flint"]: item_service.inventory.add(id,99)
	item_service.inventory.add("sleeping_bag",3);item_service.inventory.add("stone_hammer",1)
	for entry in [["workbench",false],["straw_mat",false],["straw_mat",true],["wood_bed",false],["wood_bed",true]]:
		var placed := false
		for yy in range(-2,3):
			for xx in range(-3,4):
				var at: Vector2=origin+Vector2(xx*144,yy*112)
				player.position=at+Vector2(0,85)
				var row: Dictionary=item_service.builds.candidate(entry[0],at,entry[1],true,0)
				if item_service.builds.reason(row).is_empty():
					item_service.builds.place(row,item_service.inventory.slots.duplicate(true));placed=true;break
			if placed: break
		await get_tree().process_frame
	player.position=origin;player.camera.reset_smoothing();item_service.body.energy=25
	title.text="风栖原野 · 睡眠设施候选（独立临时世界）"
	item_service.notice.emit("附近有工具台与横竖床席；E睡觉、再按E醒来；V建造时R换方向。睡袋仅工具台制作。此预览不写玩家存档。")
	sleep_samples_ready=true
