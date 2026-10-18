extends SceneTree
const OUT := "res://reports/sleep-cover-v4/"
var checks: Array=[]
var w: Node
var s: Node
var v: Node
var b: RefCounted
var capture := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=4) -> void:
	for i in n: await process_frame
func shot(label: String) -> void:
	if not capture or DisplayServer.get_name()=="headless": return
	w.item_ui.body_ui.refresh();await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func stock() -> void:
	for i in 40: s.inventory.slots[i]={}
	for id in ["wood","plant_fiber","broad_leaf","stone","sleeping_bag"]: s.inventory.add(id,80 if id!="sleeping_bag" else 3)
func find_site(kind: String,vertical: bool) -> Dictionary:
	for y in range(-4,5):
		for x in range(-4,5):
			var at: Vector2=w.generator.spawn+Vector2(x*96,y*64);w.player.position=at+Vector2(0,85)
			var row: Dictionary=b.candidate(kind,at,vertical,true,0)
			if b.reason(row).is_empty() and s.sleep.path_clear(w.player.position,at,""): return row
	return {}
func key(code: int,echo: bool=false) -> InputEventKey:
	var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;event.echo=echo
	return event
func rig_shot(label: String) -> void:
	if not capture or DisplayServer.get_name()=="headless": return
	var viewport := SubViewport.new();viewport.size=Vector2i(512,320);viewport.transparent_bg=true;viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var copy: Node2D=w.player.character.duplicate();copy.position=Vector2(64,0);viewport.add_child(copy)
	viewport.canvas_transform=Transform2D(0,Vector2.ZERO).scaled(Vector2(2,2))
	await frames();await RenderingServer.frame_post_draw;viewport.get_texture().get_image().save_png(OUT+label+"-rig.png")
	viewport.queue_free();await frames()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT);capture="--capture" in OS.get_cmdline_user_args()
	Engine.set_meta("sleep_preview",true);Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started: await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds;v.set_process(false);v.simulation.paused=false;w.player.set_physics_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)): await process_frame
	check(not s.sleep_ui.get_children().any(func(n):return n is Panel or n is PanelContainer),"no sleep choice window exists")
	check(not w.player.animation_player.has_animation("sleep/lie") and not w.player.animation_player.has_animation("sleep/wake"),"no lie or rise transition clips")
	check(s.craft_book.available().all(func(r):return not "workbench" in r.conditions) and s.craft_book.available("全部",true).any(func(r):return r.recipe_id=="bench_sleeping_bag"),"hand/workbench split retained")
	var count := 0
	for entry in [["sleeping_bag",false],["straw_mat",false],["straw_mat",true],["wood_bed",false],["wood_bed",true]]:
		b.states.clear();b.refresh_all();await frames();stock()
		var kind: String=entry[0];var vertical: bool=entry[1];var label := kind+("-vertical" if vertical else "-horizontal")
		var row := find_site(kind,vertical);check(not row.is_empty(),"real placement site "+label)
		if row.is_empty(): continue
		check(b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"place original building manager "+label);await frames()
		var id: String=b.states.keys()[0];w.player.position=Vector2(row.x,row.y)+Vector2(0,85);s.body.energy=30
		if kind!="sleeping_bag":
			w.camp_ui.begin_build("build_"+kind);var before: bool=w.camp_ui.build_vertical;w.camp_ui.handle_input(key(KEY_R))
			check(w.camp_ui.build_vertical!=before,"R build direction retained "+label);w.camp_ui.cancel_placement()
		var before_energy: float=s.body.energy
		w.player.update_animation()
		var standing_pelvis: Transform2D=w.player.character.get_node("Visual/Pelvis").transform
		check(preload("res://scripts/world_interaction.gd").execute(w.stream,w.player,b.visuals[id]),"E interaction executes "+label)
		check(s.body.sleeping and s.body.sleep_session.phase=="sleep" and b.states[id].sleep_state=="IN_USE","same-call immediate sleep and IN_USE "+label)
		check(s.body.energy==before_energy and s.body.sleep_elapsed==0,"enter sleep gives no instant energy "+label)
		check(s.sleep.symbols.visible and w.player.input_blocked and not s.body.can_labor("mine"),"closed sleep locks action and shows zzz "+label)
		check(not s.sleep.start(id).is_empty(),"repeated E start cannot duplicate session "+label)
		check(not s.sleep_ui.handle_input(key(KEY_E,true)) and s.body.sleeping,"held key repeat does not instantly cancel "+label)
		var resting: Node2D=w.player.get_node("SleepHeadCover")
		var pivot: Node2D=resting.get_node("HeadPivot")
		var head: Sprite2D=pivot.get_node("CurrentHead/Sprite")
		var quilt: Sprite2D=resting.get_node("Quilt")
		check(resting.visible and not w.player.character.visible and quilt.visible,"body fully hidden and only current head plus quilt displayed "+label)
		check(head.texture==w.player.character.get_node("Visual/Pelvis/Head/Sprite").texture and head.material.get_shader_parameter("closure")==1.0,"current side head texture reused with closed eye "+label)
		check(is_equal_approx(pivot.rotation,0 if vertical else -PI/2),"horizontal face points upward; vertical uses side profile "+label)
		var fixed: Vector2=w.player.position;var pose: Transform2D=pivot.transform
		var material: ShaderMaterial=quilt.material;var breath: float=material.get_shader_parameter("breath")
		v.advance_gameplay(.9)
		check(w.player.position==fixed and pivot.transform.is_equal_approx(pose) and absf(float(material.get_shader_parameter("breath"))-breath)>.9,"quilt breathes while head/root stay still "+label)
		root.size=Vector2i(1280,720);root.content_scale_size=root.size;w.player.camera.zoom=Vector2(2.5,2.5);w.player.camera.position_smoothing_enabled=false;w.player.camera.force_update_scroll()
		await shot(label+"-detail")
		w.player.camera.zoom=Vector2.ONE
		for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
			root.size=size;root.content_scale_size=size;w.item_ui.fit_core_ui();s.sleep_ui.fit();w.player.camera.force_update_scroll();await frames()
			var canvas: Transform2D=w.player.get_viewport().get_canvas_transform();var rect := Rect2(canvas*s.sleep.symbols.global_position,s.sleep.symbols.get_minimum_size()*canvas.get_scale().abs())
			check(Rect2(Vector2.ZERO,Vector2(size)).encloses(rect),"zzz remains on screen "+label+str(size))
			await shot(label+"-"+str(size.x))
		var at: float=v.simulation.minute;var energy: float=s.body.energy;var rate: float=preload("res://scripts/sleep_rules.gd").facility(kind).rate
		v.advance_gameplay(30)
		check(absf(v.simulation.minute-at-12)<.0001 and absf(s.body.energy-energy-rate*.2)<.0001,"normal world time and gradual rate "+label)
		v.simulation.paused=true;at=v.simulation.minute;energy=s.body.energy;v.advance_gameplay(10)
		check(v.simulation.minute==at and s.body.energy==energy,"paused sleep does not progress "+label);v.simulation.paused=false
		var wake_key: int=[KEY_E,KEY_W,KEY_SPACE,KEY_B,KEY_ESCAPE][count]
		root.push_input(key(wake_key),true)
		check(not s.body.sleep_active() and not w.player.input_blocked and not s.sleep.symbols.visible,"any new key wakes in same call "+label)
		check(w.player.character.visible and not resting.visible and w.player.character.get_node("Visual/Pelvis").transform.is_equal_approx(standing_pelvis),"standing rig restored instantly and sleeping head/quilt hidden "+label)
		check(not b.states.has(id) if kind=="sleeping_bag" else b.states[id].sleep_state=="PLACED","bag disappears immediately or reusable released "+label)
		if kind!="sleeping_bag":
			check(s.sleep.start(id).is_empty() and s.body.sleeping,"repeat use still instant "+label);s.sleep.interrupt()
		count+=1
		await shot(label+"-awake")
	# Native running process, movement lock, arbitrary-key wake and next input.
	var id: String=b.states.keys()[0];var row: Dictionary=b.states[id]
	w.player.position=Vector2(row.x,row.y)+Vector2(0,85);s.body.energy=20
	w.player.automated=true;w.player.input_override=Vector2.RIGHT;w.player.set_physics_process(true)
	s.sleep.start(id);v.set_process(true);await create_timer(.25).timeout
	check(s.body.sleeping and w.player.velocity==Vector2.ZERO and not w.player.moving,"actual physics refuses held movement during sleep")
	root.push_input(key(KEY_C),true)
	check(not s.sleep.active() and not w.item_ui.craft_panel.visible,"wake key is consumed instead of opening another UI")
	await create_timer(.2).timeout
	check(w.player.moving and w.player.velocity.length()>0,"actual physics resumes immediately without rise delay")
	w.player.input_override=Vector2.ZERO;v.set_process(false)
	# Forced zero energy also uses immediate closed-eye pose and fresh-key exit.
	s.body.energy=0
	check(v.try_start_sleep(true) and s.body.sleeping and s.body.sleep_forced,"forced sleep remains immediate")
	v.advance_gameplay(1);root.push_input(key(KEY_SPACE),true)
	check(not s.sleep.active() and b.states.has(id),"forced wake does not consume unrelated facility")
	var failed := checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+("window" if capture else "headless")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("SLEEP HEAD COVER V4 ",checks.size()," checks; ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(0 if failed==0 else 1)
