extends Control
## E enters and exits sleep. Movement/modifier keys never wake the player.
const SleepSkin = preload("res://scripts/item_ui_style.gd")
var service: Node
var wake := Button.new()

func configure(owner_service: Node) -> void:
	service=owner_service;theme=SleepSkin.theme();mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wake.text="按 E 醒来";wake.size=Vector2(210,42);add_child(wake);wake.hide()
	wake.mouse_filter=Control.MOUSE_FILTER_IGNORE;wake.focus_mode=Control.FOCUS_NONE
	get_viewport().size_changed.connect(fit);fit()

func fit() -> void:
	var area := get_viewport_rect().size
	wake.position=Vector2((area.x-wake.size.x)*.5,area.y-146)

func open(id: String) -> void:
	var error: String=service.sleep.start(id)
	if not error.is_empty(): service.notice.emit(error)

func handle_input(event: InputEvent) -> bool:
	if service.sleep.active() and event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_E or event.keycode==KEY_E):
		service.sleep.interrupt();return true
	return false

func _process(_delta: float) -> void:
	if service!=null: wake.visible=service.body.sleeping
