extends "res://tests/world_v06_formal_fixture.gd"
func _init()->void:
	Engine.set_meta("integration_seed",271828)
	Engine.set_meta("chest_open_preview",true)
func _ready()->void:
	super._ready()
	while not started:await get_tree().process_frame
	while not stream.viewport_ready(player.position,Vector2(640,360)):await get_tree().process_frame
	var id:=""
	for item in ["wood","plant_fiber"]:item_service.inventory.add(item,20)
	for y in range(-3,4):
		for x in range(-3,4):
			var at:Vector2=generator.spawn+Vector2(x*96,y*64);player.position=at+Vector2(130,85)
			var row:Dictionary=item_service.builds.candidate("wood_chest",at,false,true,0)
			if item_service.builds.reason(row).is_empty() and item_service.builds.place(row,item_service.inventory.slots.duplicate(true)).is_empty():
				id=item_service.builds.states.keys()[0];break
		if not id.is_empty():break
	if id.is_empty():item_service.notice.emit("附近暂无木箱合法位置；可用V建造临时测试木箱");return
	var row:Dictionary=item_service.builds.states[id]
	player.position=Vector2(row.x,row.y)+Vector2(0,45);player.facing="back";player.camera.reset_smoothing()
	item_service.builds.states[id].contents[0]={"item_id":"branch","count":5}
	item_service.inventory.changed.emit();item_ui.toggle_bag();item_service.storage_ui.open(id)
	title.text="木箱打开造型候选 · 独立临时世界"
	hint.text="B 背包 · E 开关木箱 · 拖动存取 · WASD 移动；不读写玩家存档"
