extends "res://tests/sleep_formal_v9_fixture.gd"
## Current scope only: input regression, still visuals, and default-window captures.
func run() -> void:
	capture=true;Engine.set_meta("sleep_preview",false);Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started: await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds;v.set_process(false);v.simulation.paused=false;w.player.set_physics_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)): await process_frame
	check(s.camps.build_book.recipes.build_straw_mat.default_unlocked and s.camps.build_book.recipes.build_wood_bed.default_unlocked,"formal bed/mat construction unlocked without preview")
	check(s.craft_book.recipes.bench_sleeping_bag.default_unlocked and not s.craft_book.available().any(func(r):return r.recipe_id=="bench_sleeping_bag") and s.craft_book.available("全部",true).any(func(r):return r.recipe_id=="bench_sleeping_bag"),"formal sleeping bag workbench only, hand cannot craft")
	check(ResourceLoader.exists(s.database.item("sleeping_bag").icon),"formal sleeping bag inventory icon exists")
	root.size=default_size();root.content_scale_size=root.size
	check(root.size==Vector2i(1280,720),"current project startup resolution only: 1280x720")
	for entry in [["sleeping_bag",false],["straw_mat",false],["straw_mat",true],["wood_bed",false],["wood_bed",true]]:
		b.states.clear();b.refresh_all();await frames();stock()
		var kind: String=entry[0];var vertical: bool=entry[1];var label := kind+("-vertical" if vertical else "-horizontal")
		var row := find_site(kind,vertical)
		check(not row.is_empty(),"native placement site "+label)
		check(b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"place "+label);await frames()
		var id: String=b.states.keys()[0];s.body.energy=30;w.player.position=Vector2(row.x,row.y)+Vector2(0,85)
		check(preload("res://scripts/world_interaction.gd").execute(w.stream,w.player,b.visuals[id]) and s.body.sleeping,"E immediately enters sleep "+label)
		var group: Node2D=w.player.get_node("SleepHeadCover");var head: Node2D=group.get_node("HeadPivot");var quilt: Sprite2D=group.get_node("Quilt")
		check(quilt.texture.resource_path.begins_with("res://assets/sleep/occupied-v9/") and preload("res://scripts/sleep_controller.gd").art_path(kind+("-vertical" if vertical else "")).begins_with("res://assets/sleep/v1/"),"formal base and occupied art with preview disabled "+label)
		var pose: Transform2D=head.transform;var cloth: Transform2D=quilt.transform;var symbols: Vector2=s.sleep.symbols.position
		v.advance_gameplay(.9)
		check(quilt.material==null and quilt.transform.is_equal_approx(cloth) and head.transform.is_equal_approx(pose),"head/body/quilt completely still, no breathing deformation "+label)
		check(s.sleep.symbols.position.distance_to(symbols)>.5,"only zzz floats "+label)
		for code in [KEY_W,KEY_SHIFT]:
			root.push_input(key(code),true)
			check(s.body.sleeping and w.player.input_blocked,"non-E key does not wake "+label+" "+str(code))
			var release := key(code);release.pressed=false;root.push_input(release,true)
		check(not s.sleep_ui.handle_input(key(KEY_E,true)) and s.body.sleeping,"held E repeat cannot wake "+label)
		var mouse := InputEventMouseButton.new();mouse.position=s.sleep_ui.wake.position+Vector2(10,10);mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;root.push_input(mouse,true)
		check(s.body.sleeping,"click cannot wake "+label)
		w.player.camera.zoom=Vector2.ONE
		var up := InputEventMouseButton.new();up.pressed=true;up.button_index=MOUSE_BUTTON_WHEEL_UP;up.position=Vector2(640,360)
		root.push_input(up,true)
		check(is_equal_approx(w.player.camera.zoom.x,1.1) and s.body.sleeping,"wheel zooms in while still asleep "+label)
		var down := InputEventMouseButton.new();down.pressed=true;down.button_index=MOUSE_BUTTON_WHEEL_DOWN;down.position=Vector2(640,360)
		root.push_input(down,true)
		check(is_equal_approx(w.player.camera.zoom.x,1.0) and s.body.sleeping and w.player.input_blocked,"wheel zooms out without waking/unlocking actor "+label)
		w.player.camera.zoom=Vector2.ONE*1.65;root.push_input(up,true)
		check(is_equal_approx(w.player.camera.zoom.x,1.65),"original upper zoom limit retained "+label)
		w.player.camera.zoom=Vector2.ONE*.65;root.push_input(down,true)
		check(is_equal_approx(w.player.camera.zoom.x,.65),"original lower zoom limit retained "+label)
		w.player.camera.zoom=Vector2(2.5,2.5);w.player.camera.position_smoothing_enabled=false;w.player.camera.force_update_scroll()
		await shot(label+"-detail")
		root.push_input(key(KEY_E),true)
		check(not s.sleep.active() and not w.player.input_blocked and w.player.character.visible,"fresh E wakes instantly "+label)
		check(not b.states.has(id) if kind=="sleeping_bag" else b.visuals[id].visible,"bag consumed or facility restored "+label)
		w.player.camera.zoom=Vector2.ONE
	var failed := checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("SLEEP FORMAL V9 ",checks.size()," checks; ",failed," failures; window ",root.size)
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(0 if failed==0 else 1)
