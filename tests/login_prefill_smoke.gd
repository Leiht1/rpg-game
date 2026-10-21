extends SceneTree
func _initialize():run.call_deferred()
func run():
	var network=root.get_node("Network")
	network.config={"server_url":"https://isolated.invalid","login_cache":"user://login-prefill-isolated.json"}
	var memory=load("res://scripts/login_memory.gd")
	var mode:=OS.get_cmdline_user_args()[0]
	if mode=="write":
		assert(memory.save(network.config,"isolated-user","Isolated-password-123",true))
	else:
		var app=load("res://scenes/launcher.tscn").instantiate();root.add_child(app)
		await process_frame
		assert(app.fields.username.text=="isolated-user")
		assert(app.fields.password.secret)
		var boxes:Array[Node]=app.find_children("*","CheckBox",true,false)
		assert(boxes.size()==1)
		if mode=="read":
			assert(app.fields.password.text=="Isolated-password-123" and boxes[0].button_pressed)
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../../reports/network-movement-v4/login.png"))
			boxes[0].button_pressed=false
			assert(memory.read(network.config).password.is_empty())
		else:
			assert(app.fields.password.text.is_empty() and not boxes[0].button_pressed)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(memory.path(network.config)))
		app.queue_free();await process_frame
	print("LOGIN_PREFILL_PASS ",mode)
	quit()
