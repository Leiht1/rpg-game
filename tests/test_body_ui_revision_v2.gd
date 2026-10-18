extends SceneTree
const OUT := "res://reports/body-v2/ui-revision/"
var checks: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func descendants(node: Node) -> Array:
	var result: Array=[node]
	for child in node.get_children(): result.append_array(descendants(child))
	return result
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Engine.set_meta("integration_seed",271828)
	Engine.set_meta("energy_icon_preview","res://prototypes/energy-icon-v1/processed/clean.png")
	var world: Node=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	var ui = world.item_ui;var body_ui = ui.body_ui;var v = world.environment_view
	var body = world.item_service.body
	v.simulation.paused=true;world.player.set_physics_process(false)
	check(not descendants(body_ui).any(func(n):return n is Label and n.text=="眠"),"no text glyph substituting for energy icon")
	check(not descendants(body_ui.paper).any(func(n):return n is Button and n.text.contains("睡眠")),"body details has no active sleep button")
	check(not v.has_method("request_sleep"),"standalone voluntary sleep entry removed")
	var textures: Array=descendants(body_ui.hud).filter(func(n):return n is TextureRect)
	check(textures.size()==4 and textures[3].texture!=null,"four real image icons including preview energy")
	check(textures[3].texture.get_size()==Vector2(96,96),"candidate image loaded at source resolution")
	check(FileAccess.file_exists("res://assets/ui/body_v2/energy.png"),"approved energy candidate has formal art path")
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=size;root.content_scale_size=size;ui.fit_core_ui();await frames(6)
		body.energy=20;body_ui.refresh()
		check(not body_ui.hud.get_global_rect().intersects(ui.dock.get_global_rect()),"image HUD clear of dock %s"%size)
		check(textures[3].size==Vector2(26,26),"energy icon display 26 square %s"%size)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"candidate-hud-%d.png"%size.x)
		body_ui.toggle();await frames()
		check(body_ui.paper.get_global_rect().position.y>=0 and body_ui.paper.get_global_rect().end.y<=size.y,"button-free detail fits %s"%size)
		check(not ui.dock.visible and not body_ui.hud.visible,"detail remains modal without bottom overlap %s"%size)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"detail-no-sleep-%d.png"%size.x)
		body_ui.close_panel();await frames()
		check(ui.dock.visible and not world.player.input_blocked,"close restores original input %s"%size)
	body.energy=0;v.simulation.paused=false
	v._process(.001)
	check(body.sleeping and body.sleep_forced and world.player.input_blocked,"removing active entry preserves automatic forced sleep")
	v.set_process(false);v.advance_gameplay(450)
	check(not body.sleeping and body.energy>=38 and not world.player.input_blocked,"forced sleep still wakes normally")
	v.simulation.paused=true
	var failed := checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("BODY UI REVISION: ",checks.size()," checks; ",failed," failures")
	world.item_service.dirty=false;world.queue_free();await frames(6);quit(0 if failed==0 else 1)
