extends SceneTree
## Representative resources are checked at real UI size before global skin replacement.
const PATH := "res://assets/ui/rework_v1/"
var world: Node
func _initialize() -> void:call_deferred("run")
func style(id: String, border: int, inset: int) -> StyleBoxTexture:
	var result := StyleBoxTexture.new()
	result.texture=load(PATH+id+".png")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		result.set_texture_margin(side,border)
		result.set_content_margin(side,inset)
	return result
func text(value: String, point_size: int=16) -> Label:
	var result := Label.new();result.text=value
	result.add_theme_font_size_override("font_size",point_size)
	result.add_theme_color_override("font_color",Color("554a3a"))
	return result
func run() -> void:
	Engine.max_fps=60;Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	world.item_ui.hide();world.environment_view.dial.hide()
	world.environment_view.simulation.set_time(10);world.environment_view.simulation.paused=true
	var layer := CanvasLayer.new();layer.layer=5;world.add_child(layer)
	var panel := PanelContainer.new();panel.position=Vector2(240,150);panel.custom_minimum_size=Vector2(600,390)
	panel.add_theme_stylebox_override("panel",style("panel",28,28));layer.add_child(panel)
	var body := VBoxContainer.new();body.add_theme_constant_override("separation",18);panel.add_child(body)
	body.add_child(text("行囊 · 代表性素材检查",24))
	body.add_child(text("纸面、布衬与布签分层；标题和正文保持干净。",16))
	var slots := HBoxContainer.new();slots.add_theme_constant_override("separation",12);body.add_child(slots)
	for pair in [["slot","branch"],["slot","stone_pickaxe"],["slot_selected","plant_fiber"]]:
		var column := VBoxContainer.new();slots.add_child(column)
		var cell := PanelContainer.new();cell.custom_minimum_size=Vector2(56,56);cell.add_theme_stylebox_override("panel",style(pair[0],12,7));column.add_child(cell)
		var icon := TextureRect.new();icon.texture=world.item_service.texture(pair[1],"icon");icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;cell.add_child(icon)
		column.add_child(text("选中" if pair[0]=="slot_selected" else "普通",13))
	var button := Button.new();button.text="制作所选数量";button.custom_minimum_size=Vector2(180,42);button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	button.add_theme_stylebox_override("normal",style("button",20,12));button.add_theme_color_override("font_color",Color("554a3a"));body.add_child(button)
	var note := PanelContainer.new();note.position=Vector2(865,230);note.custom_minimum_size=Vector2(270,210);note.add_theme_stylebox_override("panel",style("tooltip",24,24));layer.add_child(note)
	var words := VBoxContainer.new();words.add_theme_constant_override("separation",14);note.add_child(words)
	words.add_child(text("石镐",20));words.add_child(text("装备到武器槽后\n可开采矿点。\n\n数量 1 / 1",15))
	var accent := TextureRect.new();accent.texture=load(PATH+"accent.png");accent.position=Vector2(216,525);accent.size=Vector2(42,32);accent.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;accent.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;accent.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(accent)
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/ui-rework-v1/pilot.png")
	world.queue_free()
	for i in 5:await process_frame
	quit()
