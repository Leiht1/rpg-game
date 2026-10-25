extends "res://tests/mine_playable_preview.gd"
## Reuses the existing isolated mine setup; starts inside for scene review.
func run() -> void:
	await super.run()
	if not ready:return
	var s=w.item_service;var m=s.chapter.mine
	w.player.set_physics_process(false)
	m.state.phase="open";m.state.entered=true;m.state.fuse_due=0.0;m.state.fuse_remaining_seconds=0.0;m.state.opened_at=s.chapter.now()
	m.state.puzzle=s.chapter.puzzle.initial();m.travel={"inside":true,"serial":1}
	for i in 40:s.inventory.slots[i]={}
	s.inventory.equipment.clear();s.inventory.hotbar_equipment.clear();s.inventory.add("stone_pickaxe",1)
	for i in 40:
		if s.inventory.slots[i].get("item_id")=="stone_pickaxe":s.inventory.equip(i);break
	s.inventory.changed.emit();w.player.position=m.origin()+Vector2(0,200);w.player.camera.zoom=Vector2.ONE
	w.player.reset_physics_interpolation();w.player.camera.reset_smoothing();w.stream.update_target(w.player.position)
	w.player.input_blocked=false;w.player.set_physics_process(true);w.item_ui.message_time=0
	DisplayServer.window_set_title("风栖原野 · 矿洞场景返工试玩 · 重开重置")
