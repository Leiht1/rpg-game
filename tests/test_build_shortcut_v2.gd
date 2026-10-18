extends SceneTree
var world: Node
var checks: Array=[]
func _initialize() -> void: call_deferred("run")
func frames() -> void:
	for i in 3: await process_frame
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func key(code: int, echo: bool = false) -> void:
	var event := InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;event.echo=echo
	root.push_input(event,true);await frames()
	event.pressed=false;event.echo=false;root.push_input(event,true);await frames()
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	world.environment_view.simulation.paused=true
	var ui: Control=world.item_ui
	while not world.stream.viewport_ready(world.player.position,Vector2(640,360)): await process_frame
	await frames()
	check(ui.build_button.size==ui.craft_button.size,"build and craft buttons have same actual dimensions")
	check(ui.build_button.text=="V  建造","button identifies build shortcut")
	await key(KEY_V)
	check(ui.craft_panel.visible and ui.craft_panel.building and world.player.input_blocked,"native V opens building and protects world input")
	check(ui.craft_panel.close_button.text=="V / Esc  关闭","building close hint matches shortcut")
	await key(KEY_V,true)
	check(ui.craft_panel.visible and ui.craft_panel.building,"held V repeat does not toggle repeatedly")
	await key(KEY_C)
	check(ui.craft_panel.visible and not ui.craft_panel.building,"C switches building to crafting")
	await key(KEY_V)
	check(ui.craft_panel.visible and ui.craft_panel.building,"V switches crafting to building")
	await key(KEY_V)
	check(not ui.craft_panel.visible and not world.player.input_blocked,"second V closes building and restores movement")
	ui.build_button.pressed.emit();await frames()
	check(ui.craft_panel.visible and ui.craft_panel.building,"build button uses same toggle as V")
	await key(KEY_ESCAPE)
	check(not ui.craft_panel.visible and not world.player.input_blocked,"Esc closes building")
	await key(KEY_B);await key(KEY_V)
	check(not ui.bag.visible and ui.craft_panel.visible and ui.craft_panel.building,"V switches bag to building")
	ui.close_panels()
	for dimensions in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size=dimensions;root.content_scale_size=dimensions;await frames()
		check(ui.build_button.size==ui.craft_button.size,"equal buttons at "+str(dimensions))
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/cooking-build-v2/build-button-%d.png"%dimensions.x)
	var failed: int=checks.filter(func(row): return not row.pass).size()
	FileAccess.open("res://reports/cooking-build-v2/build-shortcut.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("BUILD SHORTCUT: ",checks.size()," checks; ",failed," failures")
	world.persistent_world=false;world.item_service.dirty=false;world.queue_free();await frames()
	quit(0 if failed==0 else 1)
