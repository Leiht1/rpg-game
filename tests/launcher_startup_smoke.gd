extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.get_node("Network").config={"server_url":"https://isolated.invalid","login_cache":"user://launcher-startup-isolated.json"}
	var entry=load(ProjectSettings.get_setting("application/run/main_scene"))
	assert(entry is PackedScene,"Configured main scene must load")
	var app=entry.instantiate();root.add_child(app);current_scene=app
	await process_frame
	assert(app.root.visible and app.content.get_child_count()>0,"Login must be visible")
	assert(app.fields.has("username") and app.fields.has("password"),"Login controls must exist")
	assert(app.fields.username.is_visible_in_tree() and app.fields.password.is_visible_in_tree(),"Login controls must render")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://reports/network-launcher-fix-v6/login.png"))
	print("LAUNCHER_STARTUP_PASS 4")
	quit()
