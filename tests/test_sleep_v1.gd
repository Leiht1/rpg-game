extends SceneTree
const OUT := "res://reports/sleep-v1/"
var checks: Array=[]
var w: Node
var s: Node
var b: RefCounted
var v: Node
var anchor := Vector2.ZERO
var capture := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func shot(label: String) -> void:
	if not capture or DisplayServer.get_name()=="headless": return
	await frames(3);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func stock() -> void:
	for i in 40: s.inventory.slots[i]={}
	for id in ["wood","plant_fiber","broad_leaf","stone","flint"]: s.inventory.add(id,90)
	s.inventory.equipment={};s.inventory.hotbar_equipment={}
func find_site(kind: String,vertical: bool=false) -> Dictionary:
	for y in range(-4,5):
		for x in range(-4,5):
			var at: Vector2=w.generator.spawn+Vector2(x*96,y*64)
			w.player.position=at+Vector2(0,85)
			var row: Dictionary=b.candidate(kind,at,vertical,true,0)
			if b.reason(row).is_empty() and s.sleep.path_clear(w.player.position,at,""): return row
	return {}
func clear_builds() -> void:
	b.states.clear();b.refresh_all();await frames(4)
func install(kind: String,vertical: bool=false) -> String:
	var row := find_site(kind,vertical)
	check(not row.is_empty(),"find actual legal terrain "+kind+str(vertical))
	if row.is_empty(): return ""
	anchor=Vector2(row.x,row.y)
	var error: String=b.place(row,s.inventory.slots.duplicate(true))
	check(error.is_empty(),"atomic place "+kind+str(vertical)+" "+error)
	await frames(4)
	return str(b.states.keys()[-1]) if error.is_empty() else ""
func settle_wake() -> void:
	v.advance_gameplay(1.5)
	check(not s.body.sleep_active() and not w.player.input_blocked,"wake releases state and input")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	capture="--capture" in OS.get_cmdline_user_args()
	Engine.set_meta("sleep_preview",true);Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started: await process_frame
	s=w.item_service;b=s.builds;v=w.environment_view
	v.set_process(false);v.simulation.paused=false;w.player.set_physics_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)): await process_frame
	stock();await frames()
	check(s.database.errors.is_empty() and s.craft_book.errors.is_empty() and s.camps.build_book.errors.is_empty(),"registered item craft build data valid")
	check(s.craft_book.available().all(func(r):return not "workbench" in r.conditions),"hand book hides station recipes")
	check(s.craft_book.available("全部",true).size()==s.craft_book.available().size()+1,"workbench includes hand and exclusive sleeping bag")
	check(s.craft_check("bench_sleeping_bag",1).contains("工具台"),"service rejects hand sleeping bag")
	var work_id: String=await install("workbench")
	if work_id.is_empty(): finish();return
	w.item_ui.toggle_craft(work_id);await frames()
	check(w.item_ui.craft_panel.mode_title.text=="工具台制作" and w.item_ui.craft_panel.recipe_buttons.has("bench_sleeping_bag"),"E station context exposes bag recipe")
	check(s.craft_check("bench_sleeping_bag",1).is_empty(),"valid station authorizes bag")
	var pre: int=s.inventory.count_item("broad_leaf")
	check(s.start_craft("bench_sleeping_bag",1).is_empty(),"start station sleeping bag craft")
	s.advance_craft(1.5)
	check(s.inventory.count_item("sleeping_bag")==1 and s.inventory.count_item("broad_leaf")==pre-6,"bag crafted into original inventory")
	s.start_craft("bench_sleeping_bag",1);w.player.position+=Vector2(180,0);s.advance_craft(1.5)
	check(s.craft_job.is_empty() and s.inventory.count_item("sleeping_bag")==1,"leaving station cancels without output or debit")
	w.item_ui.close_panels();w.item_ui.toggle_craft();await frames()
	check(not w.item_ui.craft_panel.recipe_buttons.has("bench_sleeping_bag"),"C hand UI hides bag after station close")
	w.item_ui.close_panels();await clear_builds();stock();s.inventory.add("sleeping_bag",4)
	var index := -1
	for i in 40:
		if s.inventory.slots[i].get("item_id")=="sleeping_bag": index=i;break
	var count: int=s.inventory.count_item("sleeping_bag")
	s.inventory.use_slot(index)
	check(w.camp_ui.bag_placing and is_instance_valid(w.camp_ui.ghost),"backpack use starts native bag ghost")
	w.camp_ui.cancel_placement();check(s.inventory.count_item("sleeping_bag")==count,"cancel preview no debit")
	s.inventory.move_slot(index,0);s.inventory.use_slot(0)
	check(w.camp_ui.bag_placing,"hotbar use starts same placement")
	w.camp_ui.cancel_placement()
	var row := find_site("sleeping_bag")
	check(not row.is_empty(),"bag legal terrain found")
	anchor=Vector2(row.x,row.y)
	var expected: Dictionary=s.inventory.slots[0].duplicate(true)
	var illegal := row.duplicate(true);illegal.x=0
	check(not b.place_bag(illegal,0,expected).is_empty() and s.inventory.count_item("sleeping_bag")==count,"boundary failure no item debit")
	check(b.place_bag(row,0,expected).is_empty() and s.inventory.count_item("sleeping_bag")==count-1,"bag commit debits one")
	check(not b.place_bag(row,0,expected).is_empty() and b.states.size()==1,"stale repeat no duplicate bag")
	await frames(5)
	var bag_id: String=b.states.keys()[0]
	w.player.position=anchor+Vector2(0,75);s.body.energy=20
	check(preload("res://scripts/world_interaction.gd").caption(b.visuals[bag_id],s.inventory)=="E 睡觉","same interaction sleep caption")
	w.player.try_interact();check(s.sleep_ui.panel.visible,"actual selected E target opens sleep UI")
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=size;root.content_scale_size=size;s.sleep_ui.fit();await frames()
		check(Rect2(Vector2.ZERO,Vector2(size)).encloses(s.sleep_ui.panel.get_global_rect()),"sleep choice fits "+str(size))
		await shot("sleep-choice-"+str(size.x))
	s.sleep_ui.close_panel();check(not s.sleep.active() and b.states[bag_id].sleep_state=="PLACED","cancel choice preserves placed bag")
	check(s.sleep.start(bag_id,"maximum").is_empty(),"bag reservation accepted")
	check(b.states[bag_id].sleep_state=="RESERVED" and not s.body.sleeping,"reserve before sleep no recovery")
	check(not s.sleep.start(bag_id).is_empty(),"reentry rejected")
	s.sleep.interrupt();check(not s.body.sleep_active() and b.states[bag_id].sleep_state=="PLACED","cancel alignment preserves unused bag")
	check(s.sleep.start(bag_id,"maximum").is_empty(),"reserve again")
	v.advance_gameplay(2.15)
	check(s.body.sleeping and b.states[bag_id].sleep_state=="IN_USE","lie completes before bag IN_USE")
	check(s.sleep.symbols.visible and w.player.animation_player.current_animation=="sleep/breathe","sleep symbols and native breathing start together")
	await shot("sleeping-bag-inside")
	w.player.camera.zoom=Vector2(2.5,2.5);w.player.camera.position_smoothing_enabled=false;w.player.camera.force_update_scroll()
	await shot("sleeping-bag-detail");w.player.camera.zoom=Vector2.ONE
	check(not b.protected_reason(bag_id).is_empty(),"occupied bag cannot demolish")
	var energy: float=s.body.energy;var time: float=v.simulation.minute
	v.advance_gameplay(60)
	check(is_equal_approx(v.simulation.minute-time,24) and absf(s.body.energy-energy-4)<.001,"60 elapsed seconds =24 game minutes and +4 bag energy")
	s.sleep.interrupt();check(not s.sleep.symbols.visible and w.player.animation_player.current_animation=="sleep/wake","manual wake hides zzz starts rise")
	settle_wake();check(not b.states.has(bag_id),"used bag consumed after rise")
	var awake_energy: float=s.body.energy;v.advance_gameplay(1)
	check(s.body.energy<awake_energy,"no end-of-sleep bonus")
	for kind in ["straw_mat","wood_bed"]:
		for vertical in [false,true]:
			await clear_builds();stock()
			var id: String=await install(kind,vertical)
			if id.is_empty(): continue
			w.player.position=anchor+Vector2(0,85)
			s.body.energy=20
			check(b.states[id].vertical==vertical,"orientation persisted "+kind+str(vertical))
			check(b.footprint(b.states[id]).y>b.footprint(b.states[id]).x if vertical else b.footprint(b.states[id]).x>b.footprint(b.states[id]).y,"footprint follows direction "+kind+str(vertical))
			w.camp_ui.begin_build("build_"+kind);var old_vertical: bool=w.camp_ui.build_vertical
			var key := InputEventKey.new();key.physical_keycode=KEY_R;key.pressed=true;w.camp_ui.handle_input(key)
			check(w.camp_ui.build_vertical!=old_vertical,"R changes build preview "+kind+str(vertical));w.camp_ui.cancel_placement()
			check(s.sleep.start(id,"full").is_empty(),"sleep reusable "+kind+str(vertical))
			v.advance_gameplay(1.0)
			check(not s.body.sleeping and not s.sleep.symbols.visible,"lie phase no zzz "+kind+str(vertical))
			await shot(kind+str(vertical)+"-lie")
			v.advance_gameplay(1.2)
			check(s.body.sleeping and s.sleep.symbols.visible,"sleep phase zzz "+kind+str(vertical))
			check(w.player.animation_player.current_animation==("sleep/vertical_breathe" if vertical else "sleep/breathe"),"posture matches facility orientation "+kind+str(vertical))
			var fixed_position: Vector2=w.player.position
			var torso: Sprite2D=w.player.character.get_node("Visual/Pelvis/Torso")
			var first_rotation: float=torso.rotation
			v.advance_gameplay(1.7)
			check(absf(torso.rotation-first_rotation)>.005 and w.player.position==fixed_position,"small articulated breath without root drift "+kind+str(vertical))
			w.player.camera.zoom=Vector2(2.5,2.5);w.player.camera.position_smoothing_enabled=false;w.player.camera.force_update_scroll()
			await shot(kind+str(vertical)+"-detail");w.player.camera.zoom=Vector2.ONE
			var e: float=s.body.energy;var rate: float=13 if kind=="straw_mat" else 17
			v.advance_gameplay(30)
			check(absf(s.body.energy-e-rate*.2)<.001,"time based rate "+kind+str(vertical))
			var frozen: Dictionary=s.body.serialize();var t: float=v.simulation.minute
			v.simulation.paused=true;v.advance_gameplay(99)
			check(s.body.serialize()==frozen and v.simulation.minute==t,"pause freezes clock and sleep "+kind+str(vertical));v.simulation.paused=false
			for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
				root.size=size;root.content_scale_size=size;w.item_ui.fit_core_ui();s.sleep_ui.fit();await frames(4)
				var canvas: Transform2D=w.player.get_viewport().get_canvas_transform()
				var symbol_rect := Rect2(canvas*s.sleep.symbols.global_position,s.sleep.symbols.get_minimum_size()*canvas.get_scale().abs())
				check(s.sleep.symbols.visible and Rect2(Vector2.ZERO,Vector2(size)).encloses(symbol_rect),"zzz projected bounds fit window "+kind+str(vertical)+str(size))
				await shot(kind+str(vertical)+"-sleep-"+str(size.x))
			s.sleep.interrupt("event");v.advance_gameplay(.5);await shot(kind+str(vertical)+"-wake")
			settle_wake();check(b.states[id].sleep_state=="PLACED","reusable released "+kind+str(vertical))
			check(s.sleep.start(id,"nap").is_empty(),"repeated sleep accepted "+kind+str(vertical))
			s.sleep.interrupt();check(not s.sleep.active(),"pre-lie cancellation releases reusable "+kind+str(vertical))
	# End conditions and real-time sample use bed from final loop.
	var id: String=b.states.keys()[0];w.player.position=anchor+Vector2(0,85);s.body.energy=69.9
	s.sleep.start(id,"target");v.advance_gameplay(5)
	check(s.body.energy<=70.000001 and not s.body.sleeping,"target stops at exact energy ceiling")
	settle_wake()
	s.body.energy=20;s.sleep.start(id,"nap");v.advance_gameplay(2.2)
	var start_minute: float=v.simulation.minute;var start_energy: float=s.body.energy
	s.camps.states["sleep:trace"]={"x":anchor.x+140,"y":anchor.y,"fuel":1000.0,"lit":true,"recipe":"roast_carrot","elapsed":0.0,"ready":false}
	s.camps.rebuild();s.inventory.add("field_lantern",1)
	for i in 40:
		if s.inventory.slots[i].get("item_id")=="field_lantern": s.toggle_lantern(i);break
	var started := Time.get_ticks_msec();v.set_process(true)
	await create_timer(5.0).timeout
	v.set_process(false)
	var real_seconds := (Time.get_ticks_msec()-started)/1000.0
	var game_minutes: float=v.simulation.minute-start_minute
	check(absf(game_minutes-real_seconds*.4)<.06 and v.simulation.time_scale==1 and Engine.time_scale==1,"real wall time proves no sleeping multiplier")
	check(absf(s.body.energy-start_energy-game_minutes/60*17)<.001,"real trace energy matches sole world clock")
	check(absf(1000-float(s.camps.states["sleep:trace"].fuel)-real_seconds)<.15 and s.camps.states["sleep:trace"].elapsed>4.9,"normal camp fuel and cooking during sleep")
	check(s.lantern_remaining<1795.2 and s.lantern_remaining>1794.6,"normal independent lamp fuel during sleep")
	FileAccess.open(OUT+"normal-time-trace.json",FileAccess.WRITE).store_string(JSON.stringify({"real_seconds":real_seconds,"start_minute":start_minute,"end_minute":v.simulation.minute,"energy_before":start_energy,"energy_after":s.body.energy,"camp":s.camps.states["sleep:trace"],"lamp":s.lantern_remaining},"  "))
	s.sleep.interrupt();settle_wake()
	# Forced zero-energy path uses the same manager and real-time clock.
	s.body.energy=0;w.player.position=anchor+Vector2(0,90)
	v._process(.01);v.set_process(false)
	check(s.body.sleep_active() and s.body.sleep_forced,"energy zero triggers shared forced lie")
	v.advance_gameplay(1.5);check(s.body.sleeping,"forced sleep enters same breathing state")
	s.sleep.interrupt();check(s.body.sleeping,"unsafe early forced wake rejected")
	v.advance_gameplay(450)
	check(not s.body.sleeping and s.body.energy>38 and s.body.energy<39.1,"forced three game hours restore approximately39 normally")
	settle_wake();check(b.states.has(id),"forced sleep leaves unrelated bed intact")
	finish()
func finish() -> void:
	var failed := checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+("window" if capture else "headless")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("SLEEP V1 ",checks.size()," checks; ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6)
	quit(0 if failed==0 else 1)
