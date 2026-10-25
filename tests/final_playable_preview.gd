extends SceneTree
## Disposable final-chapter arena; never opens a player save.
var w: Node
func _initialize() -> void:call_deferred("run")
func run() -> void:
	Engine.set_meta("integration_seed",271828);w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w);current_scene=w
	while not w.started:await process_frame
	var s=w.item_service;w.player.input_blocked=true;w.player.set_physics_process(false)
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/final-chapter-v1/ready.json"))
	s.load_state("",false,source)
	if not s.writable:push_error("隔离试玩状态无效");quit(1);return
	var f=s.chapter.finale
	f.state.merge({"discovered":false,"triggered":false,"defeated":false,"core_claimed":false,"chest_open":false,"letter_claimed":false,"blueprint_claimed":false,"dock_unlocked":false},true);f.reset_boss();f.sync_recipe()
	for i in 40:s.inventory.slots[i]={}
	s.inventory.equipment.clear();s.inventory.hotbar_equipment.clear()
	s.inventory.add("tusk_club",1);s.inventory.add("medical_kit",8);s.inventory.add("wild_berry",20);s.inventory.add(s.chapter.puzzle.RECORD,1)
	s.inventory.equip(8);s.body.health=100;s.body.energy=100;s.body.hunger=100;s.body.stamina=100;s.combat.state.boars.clear();s.combat.personal.phase="alive";s.combat.personal.attack={};s.guide_stage=2
	w.environment_view.simulation.day=30;w.environment_view.simulation.minute=600;w.environment_view.simulation.force_weather(0)
	w.player.position=f.at()+Vector2(0,430);w.player.camera.zoom=Vector2.ONE*.8;w.player.camera.reset_smoothing();w.player.reset_physics_interpolation();w.stream.update_target(w.player.position)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	s.inventory.changed.emit();w.player.input_blocked=false;w.player.set_physics_process(true)
	DisplayServer.window_set_title("风栖原野 · 海蚀遗迹台地独立试玩 · 重开重置")
	if "--smoke" in OS.get_cmdline_user_args():
		await create_timer(.7).timeout
		assert(not w.persistent_world and w.environment_view.save_path.is_empty() and not f.state.defeated)
		assert(s.inventory.has_capability("combat") or s.combat.weapon().get("damage",0)==15)
		assert(not f.state.dock_unlocked and not f.state.chest_open)
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/final-chapter-v2/preview.png")
		print("FINAL PREVIEW SMOKE PASS");s.dirty=false;w.queue_free();await process_frame;quit()
