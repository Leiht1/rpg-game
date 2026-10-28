extends SceneTree
var checks: Array=[]
var w: Node
var s: Node
var v: Node
var b: RefCounted
func default_size() -> Vector2i:
	return Vector2i(int(ProjectSettings.get_setting("display/window/size/window_width_override",1280)),int(ProjectSettings.get_setting("display/window/size/window_height_override",720)))
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=4) -> void:
	for i in n: await process_frame
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
const REPORT="res://reports/ui-sleep-hover-thermal-v1/"
func capture_frame(label: String) -> void:
	await frames(4)
	await create_timer(.35).timeout
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(REPORT+label+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(REPORT)
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds
	w.set_process(false);v.set_process(false);s.set_process(false);w.player.set_physics_process(false)
	root.size=default_size();root.content_scale_size=root.size
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	stock();b.states.clear();b.refresh_all()
	var row:=find_site("wood_bed",false)
	check(not row.is_empty(),"bed location found")
	check(b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"real bed placed")
	await frames()
	var bed_id: String=b.states.keys()[0]
	var at:=Vector2(row.x,row.y)
	var shelter: Dictionary=b.candidate("rain_shelter",at,false,true,0)
	b.states["test-shelter"]=shelter;b.refresh_all();await frames()
	var ui=w.item_ui
	var body=ui.body_ui
	w.player.position=at+Vector2(0,85);s.body.energy=10
	check(s.sleep.start(bed_id).is_empty(),"sleep starts")
	s.sleep.render();await frames()
	w.player.camera.position=Vector2.ZERO;w.player.camera.reset_smoothing()
	for roof_vertical in [false,true]:
		b.states["test-shelter"].vertical=roof_vertical;b.refresh_all();await frames()
		var canopy=b.visuals["test-shelter"].shelter_view
		for pose in [["wood_bed",false],["wood_bed",true],["straw_mat",false],["straw_mat",true],["sleeping_bag",false]]:
			s.body.sleep_session.source=pose[0];s.body.sleep_session.vertical=pose[1]
			s.sleep.render();await frames()
			canopy.update_occlusion(w.player.global_position)
			await create_timer(.3).timeout
			var label: String=str(roof_vertical)+"-"+str(pose[0])+"-"+str(pose[1])
			check(canopy.faded and canopy.roof.modulate.a<.9,"sleep canopy fades "+label)
			check(canopy.parts.all(func(p):return p.modulate.a==1.0),"sleep poles opaque "+label)
			await capture_frame("sleep-"+label)
		w.player.position=at+Vector2(1000,1000);canopy.update_occlusion(w.player.global_position)
		await create_timer(.3).timeout
		check(not canopy.faded and canopy.roof.modulate.a==1,"clear roof restores "+str(roof_vertical))
	s.body.sleep_session.source="wood_bed";s.body.sleep_session.vertical=false;s.sleep.render()
	w.player.camera.reset_smoothing()
	body.hud.pressed.emit();await frames()
	check(body.overlay.visible and s.sleep.active() and w.player.input_blocked,"HUD opens details during sleep without waking")
	s.body.cold_level=3;s.body.felt_temperature=-8;body.refresh()
	check(body.weather_summary.text.contains("#235ac4") and body.details.text.contains("#235ac4"),"extreme cold blue in HUD and details")
	await capture_frame("body-cold")
	s.body.cold_level=0;s.body.hot=true;s.body.felt_temperature=34;body.refresh()
	check(body.weather_summary.text.contains("#c64b38") and body.details.text.contains("#c64b38"),"heat red in HUD and details")
	await capture_frame("body-hot")
	root.push_input(key(KEY_ESCAPE),true);await frames()
	check(not body.overlay.visible and s.sleep.active() and w.player.input_blocked,"Esc closes details and retains sleep input lock")
	body.hud.pressed.emit();await frames()
	root.push_input(key(KEY_E),true);await frames()
	check(not s.sleep.active(),"E wakes with details open")
	ui.close_panels();ui.toggle_bag();await frames()
	ui.show_item_hover(8,ui.cells[8]);await create_timer(.2).timeout
	check(is_instance_valid(ui.hover_card) and ui.hover_card.visible,"hover appears")
	var card: Control=ui.hover_card
	for i in 80:
		s.inventory.changed.emit();await process_frame
		check(is_instance_valid(ui.hover_card) and ui.hover_card==card and ui.hover_card.visible,"unchanged sync retains visible card "+str(i))
	s.inventory.slots[8]={"item_id":"stone","count":4};s.inventory.changed.emit()
	check(is_instance_valid(ui.hover_card) and ui.hover_card==card and ui.hover_card.visible and ui.hover_snapshot.item_id=="stone","changed slot retains visible panel and updates contents without delay")
	await capture_frame("hover-updated")
	s.inventory.slots[39]={"item_id":"stone","count":1};s.inventory.changed.emit()
	ui.hide_item_hover()
	var motion:=InputEventMouseMotion.new();motion.position=ui.cells[39].get_global_rect().get_center()
	root.warp_mouse(motion.position);root.push_input(motion,true);await create_timer(.25).timeout
	check(ui.hover_index==39 and is_instance_valid(ui.hover_card) and ui.hover_card.visible,"real GUI pointer enters rightmost bag cell")
	card=ui.hover_card
	for i in 20:
		s.inventory.slots[39].count=i%2+1;s.inventory.changed.emit();await process_frame
		check(is_instance_valid(ui.hover_card) and ui.hover_card==card and ui.hover_card.visible and ui.hover_card.get_global_rect().end.x<=root.size.x,"changing metadata preserves right-edge visible panel "+str(i))
	await capture_frame("hover-right-edge")
	motion=InputEventMouseMotion.new();motion.position=Vector2(900,600)
	root.warp_mouse(motion.position);root.push_input(motion,true);await create_timer(.2).timeout
	check(ui.hover_index==-1 and not is_instance_valid(ui.hover_card),"leaving item hides hover")
	var failed:=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(REPORT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("UI_SLEEP_HOVER_THERMAL ",checks.size()," checks ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(1 if failed else 0)
