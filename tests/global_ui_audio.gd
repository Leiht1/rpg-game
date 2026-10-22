extends SceneTree
var fx:Node
var events:Array=[]
func _initialize()->void:run.call_deferred()
func frames()->void:
	for i in 3:await process_frame
func reset()->void:events.clear();fx.last_played.clear()
func click_named(parent:Node,label:String)->void:
	for button in parent.find_children("*","Button",true,false):
		if button.text==label:
			reset();button.pressed.emit();await frames()
			assert(events==["sfx_ui_click"])
			return
	assert(false,"button missing: "+label)
func run()->void:
	fx=root.get_node("AudioFX");fx.muted=true
	fx.sound_played.connect(func(key):events.append(key))
	assert(fx.world==null)
	var launcher=load("res://tests/lobby_management_fixture.gd").new();root.add_child(launcher)
	await frames()
	await click_named(launcher,"离线单机")
	print("GLOBAL_AUDIO_PASS login to main menu")
	await click_named(launcher,"单机模式")
	print("GLOBAL_AUDIO_PASS main menu to local mode")
	launcher.offline=false
	root.get_node("Network").profile={"role":"admin","world_id":"","nickname":"测试","username":"fixture","nickname_uses":0}
	await launcher.lobby();await frames()
	await click_named(launcher,"世界管理")
	print("GLOBAL_AUDIO_PASS lobby to management")
	launcher.queue_free();await frames()
	var creation=load("res://scripts/character_creation.gd").new();creation.selection_only=true;root.add_child(creation)
	await frames();await click_named(creation,"背面")
	reset();creation.skin_buttons[1].pressed.emit();await frames();assert(events==["sfx_ui_click"])
	reset();creation.gender.get_popup().id_pressed.emit(1);await frames();assert(events==["sfx_ui_click"])
	print("GLOBAL_AUDIO_PASS character orientation, skin, popup")
	reset()
	for i in 12:fx.play_sfx("sfx_ui_click")
	await frames();assert(events==["sfx_ui_click"] and fx.voices.is_empty())
	reset();fx.play_sfx("sfx_ui_click");fx.play_sfx("sfx_ui_close");await frames();assert(events==["sfx_ui_close"])
	reset();fx.play_sfx("sfx_ui_click");fx.clear_world();await frames();assert(events==["sfx_ui_click"])
	assert(not fx.play_sfx("sfx_step_grass",Vector2.ZERO))
	print("GLOBAL_AUDIO_PASS single player, priority, scene transition, world sounds guarded")
	creation.queue_free();await frames();quit()
