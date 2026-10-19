extends "res://tests/test_industry_refine_v2.gd"
const REVIEW="res://reports/ui-fade-v1/"
func pause(seconds: float) -> void:
	await create_timer(seconds).timeout
func finish() -> void:
	var failures: int=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(REVIEW+"window.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failures,"checks":checks},"  "))
	print("UI FADE V1: ",checks.size()," checks; ",failures," failures")
	w.persistent_world=false;s.dirty=false;w.free();await process_frame;quit(0 if failures==0 else 1)
func sample() -> Color:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().get_pixel(30,30)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(REVIEW)
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;s.set_process(false);w.player.set_physics_process(false)
	var fade: Node=root.get_node("UIFade")
	check(root.size==Vector2i(1280,720),"default project window")
	var layer := CanvasLayer.new();layer.layer=120;root.add_child(layer)
	var background := ColorRect.new();background.color=Color.BLACK;background.size=Vector2(100,100);layer.add_child(background)
	var panel := Panel.new();panel.position=Vector2(10,10);panel.size=Vector2(60,60)
	var style := StyleBoxFlat.new();style.bg_color=Color.WHITE;panel.add_theme_stylebox_override("panel",style);panel.hide();layer.add_child(panel)
	await frames()
	panel.show();check(panel.visible,"opening enables real UI immediately")
	await pause(.05);var middle: Color=await sample()
	await pause(.15);var full: Color=await sample()
	check(middle.r>.03 and middle.r<.99 and full.r>.98,"GPU short fade in reaches original color")
	panel.hide();check(not panel.visible and not panel.is_visible_in_tree(),"closing hides logical control immediately")
	await pause(.025);var exit: Color=await sample()
	await pause(.15);var gone: Color=await sample()
	check(exit.r>.01 and exit.r<1 and gone.r<.01,"GPU hidden control fades out then disappears")
	panel.show();await pause(.025);panel.hide();await pause(.025);panel.show();await pause(.16)
	check(panel.visible and (await sample()).r>.98,"rapid open close open cancels old tween")
	panel.hide();await pause(.15);layer.queue_free()
	var ui: Control=w.item_ui
	for entry in [["bag",ui.bag],["equipment",ui.equipment_panel],["catalog/build",ui.catalog],["item actions",ui.item_menu],["quantity",ui.split_panel],["target hint",ui.target_tip],["craft",ui.craft_panel],["cooking",w.camp_ui.panel],["industry",ui.service.industry_ui] ]:
		var control: Control=entry[1]
		check(fade.entries.has(control.get_instance_id()),str(entry[0])+" registered")
		control.show();await pause(.15);control.hide()
		check(not control.visible,str(entry[0])+" close remains logically immediate")
	await pause(.15)
	for control in [w.map_view,ui.body_ui.overlay,ui.obtained.card]:
		check(fade.entries.has(control.get_instance_id()),"map/body/reward root registered")
	# Reparenting a live frame must not duplicate signal connections.
	var moving := Panel.new();ui.add_child(moving);await frames();ui.remove_child(moving);ui.add_child(moving);await frames()
	check(fade.entries.has(moving.get_instance_id()),"reparented panel registers once")
	moving.hide();moving.queue_free();await frames()
	check(true,"free during exit safely cancels tween")
	var popup := PopupPanel.new();popup.transparent_bg=true;popup.transparent=true;root.add_child(popup)
	var paper := PanelContainer.new();paper.custom_minimum_size=Vector2(160,80);popup.add_child(paper)
	var transparent_border := StyleBoxFlat.new();transparent_border.bg_color=Color.TRANSPARENT;popup.add_theme_stylebox_override("embedded_border",transparent_border)
	await frames();popup.popup(Rect2i(100,100,160,80));await pause(.16)
	check(popup.visible and paper.modulate.a>.99,"secondary popup fades in")
	check(popup.get_theme_stylebox("embedded_border").bg_color.a==0,"transparent popup border remains transparent")
	popup.hide();await process_frame;check(popup.gui_disable_input,"closing secondary popup rejects input")
	await pause(.15);check(not popup.visible and paper.modulate.a>.99,"secondary popup closes and resets opacity")
	popup.popup(Rect2i(100,100,160,80));await pause(.025);popup.hide();await pause(.025);popup.popup(Rect2i(100,100,160,80));await pause(.17)
	check(popup.visible and not popup.gui_disable_input,"popup rapid reopen cancels pending hide")
	popup.hide();await pause(.15);popup.queue_free()
	finish()
