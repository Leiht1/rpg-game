extends Control
## Only choices are UI; the existing feed gesture owns validation and atomic debit.
const ItemSkin=preload("res://scripts/item_ui_style.gd")
class Choice extends Button:
	var screen: Control
	var slot: int
	func _make_custom_tooltip(_text: String) -> Object:
		return screen.make_item_card(slot)
var screen: Control
var current := ""
var panel:=PanelContainer.new()
var grid:=HBoxContainer.new()

func configure(owner_screen: Control) -> void:
	screen=owner_screen;theme=ItemSkin.theme();name="AnimalFoodChoices"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP;z_index=35
	panel.add_theme_stylebox_override("panel",ItemSkin.frame(14))
	add_child(panel);panel.add_child(grid)
	grid.add_theme_constant_override("separation",6)
	gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:close_panel())
	screen.service.inventory.changed.connect(refresh)
	hide()

func available() -> bool:
	var animals=screen.service.animals
	if current.is_empty() or not screen.service.writable or screen.service.body.sleep_active() or screen.service.body.down:return false
	if not animals.visuals.has(current) or not is_instance_valid(animals.visuals[current]) or animals.food_slots(current).is_empty():return false
	return preload("res://scripts/world_interaction.gd").in_reach(screen.world.stream,screen.world.player.position,animals.visuals[current])

func open(id: String) -> bool:
	screen.close_panels();current=id
	if not available():current="";return false
	screen.world.player.cancel_action();screen.hide_item_hover()
	show();refresh();screen.update_input_block();return true

func close_panel() -> void:
	hide();current=""
	if is_instance_valid(screen):screen.update_input_block()

func refresh() -> void:
	if not visible:return
	if not available():close_panel();return
	for child in grid.get_children():grid.remove_child(child);child.queue_free()
	for index in screen.service.animals.food_slots(current):
		var stack: Dictionary=screen.service.inventory.slots[index].duplicate(true)
		var choice:=Choice.new();choice.screen=screen;choice.slot=index
		choice.custom_minimum_size=Vector2(52,52)
		choice.tooltip_text=screen.service.stack_name(stack)
		choice.icon=screen.service.stack_texture(stack,"icon")
		choice.expand_icon=true;choice.add_theme_constant_override("icon_max_width",38)
		choice.add_theme_stylebox_override("normal",ItemSkin.slot(false,false))
		choice.add_theme_stylebox_override("hover",ItemSkin.slot(false,true))
		choice.pressed.connect(choose.bind(index,stack))
		grid.add_child(choice)
	panel.reset_size()

func choose(index: int, expected: Dictionary) -> void:
	if not visible or not available():close_panel();return
	var id:=current
	close_panel()
	var reason: String=screen.world.player.animal_feed.start(screen.world.player,id,index,expected)
	if not reason.is_empty():screen.show_notice(reason)

func handle_input(event: InputEvent) -> bool:
	if not visible:return false
	if event is InputEventKey:
		if event.pressed and not event.echo and event.physical_keycode in [KEY_E,KEY_ESCAPE]:close_panel()
		return true
	return false

func _process(_delta: float) -> void:
	if not visible:return
	if not available():close_panel();return
	var target: Node2D=screen.service.animals.visuals[current]
	var anchor: Vector2=get_viewport().get_canvas_transform()*target.position
	panel.position=(anchor+Vector2(24,-110)).clamp(Vector2(12,12),get_viewport_rect().size-panel.size-Vector2(12,12))
