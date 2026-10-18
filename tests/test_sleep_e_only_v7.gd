extends "res://tests/test_sleep_occupied_v6.gd"
## Current scope only: input regression, still visuals, and default-window captures.
func run() -> void:
	capture=true;Engine.set_meta("sleep_preview",true);Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started: await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds;v.set_process(false);v.simulation.paused=false;w.player.set_physics_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)): await process_frame
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
		var pose: Transform2D=head.transform;var cloth: Transform2D=quilt.transform;var symbols: Vector2=s.sleep.symbols.position
		v.advance_gameplay(.9)
		check(quilt.material==null and quilt.transform.is_equal_approx(cloth) and head.transform.is_equal_approx(pose),"head/body/quilt completely still, no breathing deformation "+label)
		check(s.sleep.symbols.position.distance_to(symbols)>.5,"only zzz floats "+label)
		for code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_SHIFT,KEY_ESCAPE,KEY_SPACE,KEY_C]:
			root.push_input(key(code),true)
			check(s.body.sleeping and w.player.input_blocked,"non-E key does not wake "+label+" "+str(code))
			var release := key(code);release.pressed=false;root.push_input(release,true)
		check(not s.sleep_ui.handle_input(key(KEY_E,true)) and s.body.sleeping,"held E repeat cannot wake "+label)
		var mouse := InputEventMouseButton.new();mouse.position=s.sleep_ui.wake.position+Vector2(10,10);mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true;root.push_input(mouse,true)
		check(s.body.sleeping,"click cannot wake "+label)
		w.player.camera.zoom=Vector2(2.5,2.5);w.player.camera.position_smoothing_enabled=false;w.player.camera.force_update_scroll()
		await shot(label+"-detail")
		root.push_input(key(KEY_E),true)
		check(not s.sleep.active() and not w.player.input_blocked and w.player.character.visible,"fresh E wakes instantly "+label)
		check(not b.states.has(id) if kind=="sleeping_bag" else b.visuals[id].visible,"bag consumed or facility restored "+label)
		w.player.camera.zoom=Vector2.ONE
	var failed := checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"e-only-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("SLEEP E ONLY V7 ",checks.size()," checks; ",failed," failures; window ",root.size)
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(0 if failed==0 else 1)
