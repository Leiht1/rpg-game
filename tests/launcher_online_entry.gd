extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var network=root.get_node("Network")
	network.profile={"nickname":"测试","avatar":""}
	var app=load("res://tests/launcher_online_fixture.gd").new();root.add_child(app)
	app.menu()
	var entry:Button
	for node in app.content.find_children("*","Button",true,false):
		if node.text=="联机模式":entry=node
	assert(entry!=null)
	entry.pressed.emit()
	assert(app.lobby_calls==1 and app.login_calls==0)
	app.offline=true
	entry.pressed.emit()
	assert(app.lobby_calls==1 and app.login_calls==1)
	app.queue_free();await process_frame
	print("LAUNCHER_ONLINE_ENTRY_PASS 3")
	quit()
