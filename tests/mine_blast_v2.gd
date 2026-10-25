extends "res://tests/mine_playable_preview.gd"
var checks: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func move_to(at: Vector2) -> void:
	w.player.position=at;w.player.camera.position_smoothing_enabled=false;w.stream.update_target(at)
	while not w.stream.viewport_ready(at,Vector2(640,360)):await process_frame
	await create_timer(.12).timeout
func smoke() -> void:
	var s=w.item_service;var m=s.chapter.mine;var view=s.chapter_view.get_node("MineView")
	check(not w.persistent_world,"isolated playable preview")
	await move_to(m.record_at()+Vector2(0,60));w.player.facing="back";w.player.try_interact()
	check(m.state.recipe,"real distant record investigation")
	s.chapter_view.close_page()
	var bench: Dictionary=s.builds.states[bench_id]
	await move_to(Vector2(bench.x,bench.y)+Vector2(0,85));w.player.facing="back";w.player.try_interact()
	check(w.item_ui.craft_panel.recipe_buttons.has(m.config.recipe_id),"discovered recipe available at actual advanced table")
	w.item_ui.craft_panel.recipe_buttons[m.config.recipe_id].pressed.emit();w.item_ui.craft_panel.once.pressed.emit()
	await create_timer(1.8).timeout;check(m.count_pack()==1,"normal UI craft produces real pack")
	w.item_ui.close_panels();w.item_ui.update_input_block()
	await move_to(m.at()+Vector2(0,115))
	w.player.facing="back";w.player.try_interact()
	check(m.state.phase=="armed" and m.count_pack()==0,"real E placement consumes once")
	check(is_equal_approx(m.remaining_seconds(),5.0),"starts at five real seconds")
	var armed: Dictionary=s.snapshot().duplicate(true)
	# Game time can be accelerated without shortening this fuse.
	w.environment_view.simulation.advance_calendar(1000);w.environment_view.simulation.time_scale=8
	var started: int=Time.get_ticks_msec();var observed: Array=[];var frame_indices: Array=[]
	var cropped: Array[Image]=[];var capture_ms: Array=[];var snapshots: Array=[];var opened_ms:=-1;var last_digit:=""
	while Time.get_ticks_msec()-started<7800:
		await RenderingServer.frame_post_draw
		var screen: Image=root.get_texture().get_image()
		var digit: String=view.countdown.text if view.countdown.visible else ""
		if not digit.is_empty() and digit!=last_digit:
			observed.append(digit);last_digit=digit
			snapshots.append({"name":"countdown-"+digit,"image":screen})
		if m.state.phase=="open" and opened_ms<0:opened_ms=Time.get_ticks_msec()-started
		if view.blast.active and view.blast.frame_index not in frame_indices:
			frame_indices.append(view.blast.frame_index)
			if view.blast.frame_index in [1,3,5,8,11,14]:snapshots.append({"name":"blast-"+str(view.blast.frame_index),"image":screen})
		var point: Vector2=w.get_viewport().get_canvas_transform()*m.at()
		var area:=Rect2i(Vector2i(point)-Vector2i(300,260),Vector2i(600,500)).intersection(Rect2i(Vector2i.ZERO,screen.get_size()))
		cropped.append(screen.get_region(area));capture_ms.append(Time.get_ticks_msec()-started)
		await create_timer(.065).timeout
	check(observed==["5","4","3","2","1"],"visible exact 5 4 3 2 1 ordering")
	check(opened_ms>=4900 and opened_ms<=5250,"five actual seconds despite accelerated calendar")
	check(frame_indices.size()>=9 and view.blast.frames.size()==16,"painted one-shot traverses detailed frames")
	check(not view.blast.active and not view.countdown.visible,"one-shot and countdown finish and disappear")
	check(m.state.phase=="open" and view.barrier.get_child(0).disabled and not view.rubble.visible,"only confirmed opening clears rock and collider")
	var opened: Dictionary=s.snapshot().duplicate(true)
	s.load_state("",false,JSON.parse_string(JSON.stringify(opened)));await create_timer(.2).timeout
	check(not view.blast.active,"restoring opened state does not replay explosion")
	# Partly elapsed fuse survives a JSON snapshot and cannot be reset by E.
	s.set_process(false);armed.exploration_chapter.mine.fuse_remaining_seconds=2.6
	s.load_state("",false,JSON.parse_string(JSON.stringify(armed)));await create_timer(.1).timeout
	check(is_equal_approx(m.remaining_seconds(),2.6),"JSON restores remaining fuse without restart")
	check(not m.interact("place").is_empty() and is_equal_approx(m.remaining_seconds(),2.6),"repeated placement cannot restart countdown")
	var path_before: String=s.save_path;w.persistent_world=true;s.save_path="res://reports/mine-blast-v2/missing/sub/save.json"
	m.advance(3.0);await create_timer(.15).timeout
	check(m.state.phase=="armed" and not view.blast.active and not view.barrier.get_child(0).disabled,"failed opening save keeps seal and never plays blast")
	w.persistent_world=false;s.save_path=path_before;m.advance();await create_timer(.3).timeout
	check(m.state.phase=="open" and view.blast.active,"retry completes once after save recovery")
	var folder: String="res://reports/.tmp/mine-blast-v2/"
	DirAccess.make_dir_recursive_absolute(folder)
	for entry in snapshots:entry.image.save_png("res://reports/mine-blast-v2/"+entry.name+".png")
	for i in cropped.size():cropped[i].save_png(folder+"frame-%03d.png"%i)
	var failures: int=checks.filter(func(c):return not c.pass).size()
	FileAccess.open("res://reports/mine-blast-v2/window.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"digits":observed,"opened_ms":opened_ms,"frames":frame_indices,"capture_frames":cropped.size(),"capture_ms":capture_ms},"  "))
	print("MINE BLAST V2 ",checks.size()," checks failures=",failures," opened_ms=",opened_ms)
	w.queue_free();await process_frame;quit(1 if failures else 0)
