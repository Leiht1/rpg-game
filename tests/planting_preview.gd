extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.set_meta("integration_seed",98171023)
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started: await process_frame
	var s=w.item_service
	for i in 40:s.inventory.slots[i]={}
	for i in 3:s.inventory.slots[i]={"item_id":["carrot_seed","potato_seed","cabbage_seed"][i],"count":20}
	for i in 3:s.inventory.slots[3+i]=s.inventory.instance(["stone_pickaxe","simple_shovel","stone_hammer"][i])
	s.inventory.equip(3);s.inventory.selected=0;s.inventory.changed.emit()
	s.notice.emit("种植试玩 · V 选择耕地，装备石镐开垦；靠近空地按 E 选择种子，点击即种。临时世界不写玩家存档。")
