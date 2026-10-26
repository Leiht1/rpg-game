extends SceneTree
## Actual final-chapter world and player camera; disposable fixture, no player save.
var w: Node
func _initialize() -> void:call_deferred("run")
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w);current_scene=w
	while not w.started:await process_frame
	var s=w.item_service
	w.set_process(false);s.set_process(false);w.environment_view.set_process(false)
	w.player.set_physics_process(false);w.player.automated=true;w.player.camera.position_smoothing_enabled=false
	var snapshot: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/final-chapter-v1/ready.json"))
	s.load_state("",false,snapshot)
	assert(not w.persistent_world and w.environment_view.save_path.is_empty())
	var f=s.chapter.finale
	f.state.defeated=false;f.state.triggered=false;f.reset_boss();s.guide_stage=2;s.combat.state.boars.clear()
	var at: Vector2=f.boss_at()
	w.player.position=at+Vector2(0,100);w.player.camera.zoom=Vector2.ONE
	w.player.camera.reset_smoothing();w.player.reset_physics_interpolation();w.stream.update_target(w.player.position)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	await create_timer(.4).timeout
	var view: Node=s.chapter_view.get_node("FinaleView")
	view.set_process(false);view.guardian.hide()
	var rigs: Array=[]
	for i in 3:
		var rig=load("res://scripts/ancient_lord_posture_v3.gd").new()
		w.object_root.add_child(rig);rig.position=at+Vector2((i-1)*300,0);rig.scale=Vector2.ONE*.8
		rig.set_view(["front","back","right"][i]);rigs.append(rig)
	DisplayServer.window_set_title("远古领主 · V2返工实际台地 · 正常相机1.0")
	for pose in ["neutral","contact","down","passing"]:
		for rig in rigs:rig.set_posture(pose)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/boss-posture-v3/world-"+pose+".png")
	s.dirty=false;w.queue_free();await process_frame;quit()
