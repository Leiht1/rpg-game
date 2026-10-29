extends SceneTree
func _initialize()->void:run.call_deferred()
func find_button(app:Node,text:String)->Button:
	for candidate in app.content.find_children("*","Button",true,false):
		if candidate.text==text:return candidate
	return null
func run()->void:
	var network=root.get_node("Network")
	network.profile={"role":"admin","world_id":"fixture"}
	var app=load("res://tests/lobby_management_fixture.gd").new();root.add_child(app)
	app.lobby()
	assert(find_button(app,"世界管理")!=null)
	assert(find_button(app,"测试原野  · 0 人在线")!=null)
	assert(find_button(app,"继续原有世界")!=null)
	assert(find_button(app,"创建世界")!=null)
	app.request_world_change("join_world",{"world_id":"other"})
	assert(app.status.text.contains("删除当前所在世界的进度"))
	find_button(app,"取消").pressed.emit()
	assert(network.profile.world_id=="fixture")
	app.request_world_change("create_world",{"name":"新世界"})
	assert(app.status.text.contains("创建新的世界"))
	find_button(app,"取消").pressed.emit()
	find_button(app,"世界管理").pressed.emit()
	assert(find_button(app,"删除世界")!=null)
	find_button(app,"删除世界").pressed.emit()
	assert(app.deletes==0)
	find_button(app,"确认删除 测试原野").pressed.emit()
	assert(app.status.text.contains("在线玩家"))
	assert(find_button(app,"确认删除 测试原野")!=null)
	app.reject_delete=false
	find_button(app,"确认删除 测试原野").pressed.emit()
	assert(network.profile.world_id=="")
	network.profile.role="player";app.lobby()
	assert(find_button(app,"世界管理")==null)
	print("LOBBY_LIST_CONFIRM_CANCEL_AND_MANAGEMENT_PASS")
	quit()
