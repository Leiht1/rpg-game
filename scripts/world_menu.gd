extends CanvasLayer
## Shared compact in-world menu for local and network sessions.
var world_provider: Callable
var return_action: Callable
var trigger := Button.new()
var overlay := Control.new()
var panel := PanelContainer.new()
var back := Button.new()
var confirmation := VBoxContainer.new()
var returning := false
var escape_had_page := false
func _ready() -> void:
	layer=40
	trigger.text="Esc";trigger.position=Vector2(8,4);trigger.custom_minimum_size=Vector2(44,24)
	trigger.theme=preload("res://scripts/item_ui_style.gd").theme()
	for state in ["normal","hover","pressed","focus"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("e9dfc4") if state=="normal" else Color("f3e8cc")
		style.border_color=Color("85775d");style.set_border_width_all(1)
		style.content_margin_left=6;style.content_margin_right=6
		style.content_margin_top=2;style.content_margin_bottom=2
		trigger.add_theme_stylebox_override(state,style)
	trigger.focus_mode=Control.FOCUS_NONE
	add_child(trigger);trigger.pressed.connect(toggle)
	add_child(overlay);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:toggle())
	var center:=CenterContainer.new();overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter=Control.MOUSE_FILTER_IGNORE
	center.add_child(panel);panel.theme=trigger.theme
	panel.add_theme_stylebox_override("panel",preload("res://scripts/item_ui_style.gd").frame())
	back.text="返回主菜单";back.custom_minimum_size=Vector2(164,40)
	back.focus_mode=Control.FOCUS_NONE;panel.add_child(back)
	back.pressed.connect(func():set_confirmation(true))
	panel.add_child(confirmation);confirmation.add_theme_constant_override("separation",12)
	var question:=Label.new();question.text="确认返回主菜单？";question.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	confirmation.add_child(question)
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",12);confirmation.add_child(actions)
	for caption in ["确认","取消"]:
		var button:=Button.new();button.text=caption;button.custom_minimum_size=Vector2(96,36)
		button.focus_mode=Control.FOCUS_NONE;actions.add_child(button)
		if caption=="确认":button.pressed.connect(confirm_return)
		else:button.pressed.connect(func():set_confirmation(false))
	set_confirmation(false)
	overlay.hide()
func set_confirmation(value: bool) -> void:
	if returning:return
	confirmation.visible=value;back.visible=not value;panel.reset_size()
func confirm_return() -> void:
	if returning or not confirmation.visible:return
	returning=true
	for button in confirmation.get_child(1).get_children():button.disabled=true
	await return_action.call()
	if is_instance_valid(self):
		returning=false
		for button in confirmation.get_child(1).get_children():button.disabled=false
func _process(_delta: float) -> void:
	var world=world_provider.call()
	var available:=is_instance_valid(world)
	trigger.visible=available
	if not available:overlay.hide();set_confirmation(false);return
	var heading=world.get("title") if world.get("item_ui") != null else world.get("notice")
	if heading is Label:heading.hide()
	if overlay.visible and world.get("item_ui") != null:world.player.input_blocked=true
func toggle() -> void:
	var world=world_provider.call()
	if not is_instance_valid(world) or returning:return
	# Sleep retains its exclusive E-to-wake input contract.
	if world.get("item_ui") != null and world.item_service.body.sleep_active():return
	if confirmation.visible:set_confirmation(false);return
	overlay.visible=not overlay.visible
	world.set_meta("world_menu_open",overlay.visible)
	if world.get("item_ui") != null:world.item_ui.update_input_block()
func other_page_open() -> bool:
	var world=world_provider.call()
	if not is_instance_valid(world):return true
	if get_viewport().gui_is_dragging():return true
	if world.get("typing")==true:return true
	var items=world.get("item_ui")
	if items != null:
		for page in [items.bag,items.catalog,items.craft_panel,items.modal,world.map_view]:
			if is_instance_valid(page) and page.visible:return true
		if is_instance_valid(items.body_ui) and items.body_ui.overlay.visible:return true
		if is_instance_valid(world.camp_ui) and (world.camp_ui.panel.visible or world.camp_ui.sign_dialog.visible):return true
		var service=world.item_service
		for page in [service.expansion_ui,service.industry_ui,service.planting_ui,service.merchant.ui]:
			if is_instance_valid(page) and page.visible:return true
		if is_instance_valid(service.storage_ui) and service.storage_ui.panel.visible:return true
	else:
		for name_value in ["bag_panel","object_panel"]:
			var page=world.get(name_value)
			if is_instance_valid(page) and page.visible:return true
	return false
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
		escape_had_page=other_page_open()
		if overlay.visible:toggle();get_viewport().set_input_as_handled()
	elif overlay.visible and event is InputEventKey:get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
		if not escape_had_page and not other_page_open():toggle();get_viewport().set_input_as_handled()
