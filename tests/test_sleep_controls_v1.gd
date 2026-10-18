extends SceneTree
const OUT := "res://reports/sleep-v1/"
var checks: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func run() -> void:
	Engine.set_meta("sleep_preview",true);Engine.set_meta("integration_seed",271828)
	var w: Node=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started: await process_frame
	var s=w.item_service;var p=w.player;var v=w.environment_view
	v.set_process(false);v.simulation.paused=false;p.set_physics_process(false)
	while not w.stream.viewport_ready(p.position,Vector2(640,360)): await process_frame
	for id in ["wood","plant_fiber","broad_leaf"]: s.inventory.add(id,99)
	var row := {}
	for y in range(-3,4):
		for x in range(-3,4):
			var at: Vector2=w.generator.spawn+Vector2(x*96,y*64);p.position=at+Vector2(0,85)
			var candidate: Dictionary=s.builds.candidate("straw_mat",at,false,true,0)
			if s.builds.reason(candidate).is_empty() and s.sleep.path_clear(p.position,at,""): row=candidate;break
		if not row.is_empty(): break
	check(not row.is_empty(),"native physics fixture site")
	if row.is_empty(): w.queue_free();quit(1);return
	s.builds.place(row,s.inventory.slots.duplicate(true))
	for i in 6: await process_frame
	var id: String=s.builds.states.keys()[0];s.body.energy=20
	p.automated=true;p.input_override=Vector2.RIGHT;p.run_override=true
	check(s.sleep.start(id).is_empty(),"native physics starts sleep")
	p.set_physics_process(true);v.set_process(true)
	await create_timer(2.5).timeout
	check(s.body.sleeping and not p.moving and not p.running and p.velocity==Vector2.ZERO,"actual physics refuses held movement and sprint during sleep")
	var fixed: Vector2=p.position
	await create_timer(.25).timeout
	check(p.position==fixed and p.action.is_empty(),"native collider stays fixed during breathing")
	var e: float=s.body.energy;var t: float=v.simulation.minute
	v.simulation.paused=true;await create_timer(.3).timeout
	check(s.body.energy==e and v.simulation.minute==t,"actual pause stops sleep and world together")
	v.simulation.paused=false
	var key := InputEventKey.new();key.physical_keycode=KEY_E;key.keycode=KEY_E;key.pressed=true
	root.push_input(key,true);await process_frame
	check(not s.body.sleeping and s.body.sleep_session.phase=="wake","native E input requests rising")
	await create_timer(.45).timeout
	check(s.body.sleep_active() and p.velocity==Vector2.ZERO,"movement remains locked through rising")
	await create_timer(1.1).timeout
	check(not s.body.sleep_active() and not p.input_blocked and p.moving and p.velocity.length()>0,"actual physics resumes held movement after rise")
	p.input_override=Vector2.ZERO
	var bkey := InputEventKey.new();bkey.physical_keycode=KEY_B;bkey.keycode=KEY_B;bkey.pressed=true
	root.push_input(bkey,true);await process_frame
	check(w.item_ui.bag.visible,"native B input opens inventory after waking")
	w.item_ui.close_panels()
	check(p.character.get_node("Visual/Pelvis/Head/Sprite").material==null and not s.sleep.symbols.visible and not p.get_node("SleepCover").visible,"wake restores face and clears all sleep visual layers")
	p.input_override=Vector2.ZERO;p.position=Vector2(row.x,row.y)+Vector2(0,85)
	s.sleep_ui.open(id)
	var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=w.item_ui.craft_button.get_global_rect().get_center()
	root.push_input(click,true);click=click.duplicate();click.pressed=false;root.push_input(click,true);await process_frame
	check(s.sleep_ui.panel.visible and not w.item_ui.craft_panel.visible,"choice modal blocks outside craft button clicks")
	check(w.item_ui.cells[8]._get_drag_data(Vector2.ZERO)==null,"choice modal rejects inventory drag")
	s.sleep_ui.choose(0);await create_timer(2.4).timeout
	check(s.body.sleeping and w.item_ui.cells[8]._get_drag_data(Vector2.ZERO)==null,"sleep blocks mouse inventory drag")
	click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=s.sleep_ui.wake.get_global_rect().get_center()
	root.push_input(click,true);click=click.duplicate();click.pressed=false;root.push_input(click,true);await process_frame
	check(not s.body.sleeping and s.body.sleep_session.phase=="wake","native wake button remains clickable through central lock")
	await create_timer(1.5).timeout
	check(not s.sleep.active() and not p.input_blocked,"button wake returns input")
	var failed := checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"controls-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("SLEEP CONTROLS ",checks.size()," checks; ",failed," failures")
	s.dirty=false;w.queue_free()
	for i in 6: await process_frame
	quit(0 if failed==0 else 1)
