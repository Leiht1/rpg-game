extends SceneTree
func _initialize() -> void:run.call_deferred()
func click_button(app: Node, caption: String) -> void:
	var button: Button
	for candidate in app.content.find_children("*","Button",true,false):
		if candidate.text==caption:button=candidate;break
	assert(is_instance_valid(button),caption)
	var point: Vector2=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;Input.parse_input_event(motion)
	await process_frame
	print("HOVER ",caption," ",root.gui_get_hovered_control())
	var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;Input.parse_input_event(event)
	await process_frame
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
	await process_frame
func run() -> void:
	root.get_node("Network").config={"server_url":"https://isolated.invalid","login_cache":"user://launcher-click-isolated.json"}
	var app=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();root.add_child(app);current_scene=app
	await create_timer(.3).timeout
	await click_button(app,"首次账号激活")
	assert(app.fields.has("activation"),"Activation button must open activation page")
	await click_button(app,"返回登录")
	assert(not app.fields.has("activation"),"Return must restore login")
	await click_button(app,"离线单机")
	assert(app.offline,"Offline button must open local menu")
	print("LAUNCHER_CLICK_PASS 3")
	quit()
