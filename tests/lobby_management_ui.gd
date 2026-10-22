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
	var world=load("res://scripts/network_game_world.gd").new()
	world.style_return_dialog()
	var dialog:ConfirmationDialog=world.return_dialog
	dialog.theme=load("res://scripts/item_ui_style.gd").theme()
	root.add_child(dialog);dialog.dialog_text="确定返回大厅吗？角色和随身物品会保留。"
	dialog.ok_button_text="返回大厅";dialog.cancel_button_text="继续游戏";dialog.popup_centered(Vector2i(420,160))
	assert(dialog.transparent_bg and dialog.borderless)
	assert(dialog.get_theme_stylebox("panel") is StyleBoxTexture)
	assert(dialog.get_theme_stylebox("embedded_border") is StyleBoxTexture)
	await create_timer(.3).timeout
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://reports/.tmp/lobby-management-ui")
	root.get_texture().get_image().save_png("res://reports/.tmp/lobby-management-ui/dialog.png")
	dialog.hide();root.remove_child(dialog);world.free()
	print("LOBBY_MANAGEMENT_UI_PASS 10")
	quit()
