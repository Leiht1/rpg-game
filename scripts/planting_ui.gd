extends Control
var service: Node
var current := ""
var panel := Panel.new()
var choices := VBoxContainer.new()
var empty := Label.new()
func configure(items: Node) -> void:
	service=items;theme=preload("res://scripts/item_ui_style.gd").theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(panel);panel.size=Vector2(400,300);panel.add_theme_stylebox_override("panel",preload("res://scripts/item_ui_style.gd").frame())
	var title := Label.new();title.text="选择种子";title.position=Vector2(28,22);title.add_theme_font_size_override("font_size",23);panel.add_child(title)
	var button := Button.new();button.text="关闭";button.set_meta("audio_window_close",true);button.position=Vector2(308,20);button.size=Vector2(64,34);panel.add_child(button);button.pressed.connect(close_panel)
	choices.position=Vector2(28,70);choices.size=Vector2(344,190);choices.add_theme_constant_override("separation",8);panel.add_child(choices)
	empty.text="没有种子";empty.position=Vector2(28,112);empty.size=Vector2(344,60);empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;panel.add_child(empty)
	service.inventory.changed.connect(refresh);hide()
func available() -> bool:
	if current.is_empty() or service.body.sleep_active() or service.body.down or not service.writable:return false
	if service.builds.states.get(current,{}).get("kind","")!="tilled_soil" or service.planting.action(current)!="sow":return false
	var target: Node2D=service.builds.visuals.get(current)
	return is_instance_valid(target) and preload("res://scripts/world_interaction.gd").in_reach(service.world.stream,service.world.player.position,target)
func open(id: String) -> bool:
	service.world.item_ui.close_panels();current=id
	if not available():current="";return false
	service.world.player.cancel_action();show();refresh();service.world.item_ui.update_input_block();return true
func close_panel() -> void:
	hide();current="";service.world.item_ui.update_input_block()
func refresh() -> void:
	if not visible:return
	for child in choices.get_children():choices.remove_child(child);child.queue_free()
	for spec in service.planting.rules.crops.values():
		var count: int=service.inventory.count_item(str(spec.seed))
		if count<=0:continue
		var button := Button.new();button.text="%s  ×%d"%[service.database.item(spec.seed).name,count]
		button.icon=service.texture(spec.seed,"icon");button.expand_icon=true;button.add_theme_constant_override("icon_max_width",32)
		button.custom_minimum_size=Vector2(344,52);button.pressed.connect(choose.bind(str(spec.seed)));choices.add_child(button)
	empty.visible=choices.get_child_count()==0
func choose(seed: String) -> void:
	if not visible:return
	if not available():close_panel();service.notice.emit("耕地已变化，请重新选择");return
	var target: Node2D=service.builds.visuals[current]
	if service.planting.interact(current,target,seed):close_panel()
	else:refresh()
func handle_input(event: InputEvent) -> bool:
	if not visible:return false
	if service.body.sleep_active():close_panel();return false
	if event is InputEventKey:
		if event.pressed and not event.echo and event.physical_keycode in [KEY_E,KEY_ESCAPE]:close_panel()
		return true
	return false
func _process(_delta: float) -> void:
	if not visible:return
	panel.position=(get_viewport_rect().size-panel.size)*.5
	if not available():close_panel()
