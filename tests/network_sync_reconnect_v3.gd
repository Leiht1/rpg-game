extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var fixture: Dictionary={};var folder: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):
			folder=arg.trim_prefix("--fixture=").get_base_dir();fixture=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--fixture=")))
	Engine.set_meta("sync_trace",{"requests":[],"restore_parts":{}})
	var net=root.get_node("Network")
	var began:=Time.get_ticks_usec()
	var response: Dictionary=await net.call_api("login",{"username":fixture.username,"password":fixture.password})
	assert(response.get("ok",false))
	response=await net.call_api("resume",{});assert(response.get("ok",false))
	response=await net.call_api("character",{});assert(response.get("ok",false))
	var state: Dictionary=await net.call_api("game_snapshot",{});assert(state.get("ok",false))
	var expected_path:=folder.path_join("final_state"+str(int(fixture.index))+".json")
	if FileAccess.file_exists(expected_path):
		var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(expected_path))
		assert(load("res://scripts/item_service.gd").same_network_value(state.snapshot.slots,expected.slots),"Reconnect lost inventory")
		assert(load("res://scripts/item_service.gd").same_network_value(state.snapshot.equipment,expected.equipment),"Reconnect lost equipment")
		assert(state.snapshot.buildings.objects.size()>=expected.buildings.size(),"Reconnect lost buildings")
	response.initial_snapshot=state.snapshot
	var world=load("res://scripts/network_game_world.gd").new();world.session_data=response;root.add_child(world)
	while not world.started:await process_frame
	if fixture.get("mode","")=="craft_disconnect":
		var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("craft_pending.json")))
		var deadline:=Time.get_ticks_msec()+15000
		var samples: Array=[]
		while not world.item_service.craft_job.is_empty() and Time.get_ticks_msec()<deadline:
			samples.append({"job":world.item_service.craft_job.duplicate(true),"visual_elapsed":world.craft_visual_elapsed,"progress":world.item_ui.craft_panel.progress.value})
			await create_timer(.1).timeout
		assert(world.item_service.craft_job.is_empty(),"Reconnected crafting never completed")
		assert(world.item_service.inventory.count_item("broad_leaf")==int(expected.leaf)-2)
		assert(world.item_service.inventory.count_item("plant_fiber")==int(expected.fiber)+3)
		await create_timer(2).timeout
		assert(world.item_service.inventory.count_item("plant_fiber")==int(expected.fiber)+3,"Craft rewarded twice after reconnect")
		FileAccess.open(folder.path_join("craft_reconnect.json"),FileAccess.WRITE).store_string(JSON.stringify({"ok":true,"samples":samples,"job":world.item_service.craft_job,"fiber":world.item_service.inventory.count_item("plant_fiber")}))
	await RenderingServer.frame_post_draw
	# A changed invalid relic must never hit the successful-content cache.
	var combat=world.item_service.combat
	var probe: Dictionary=combat.state.duplicate(true)
	probe.relics["sync-cache-check"]={"owner":"test","x":world.player.position.x,"y":world.player.position.y,"contents":[{"item_id":"branch","count":1}]}
	assert(combat.valid(probe,combat.personal))
	assert(combat.valid(probe,combat.personal))
	probe.relics["sync-cache-check"].contents[0].count=-1
	assert(not combat.valid(probe,combat.personal),"Changed malformed contents bypassed validation")
	assert(combat.valid(combat.state,combat.personal))
	if fixture.get("mode","")!="craft_disconnect":
		assert(load("res://scripts/item_service.gd").same_network_value(world.item_service.inventory.slots,state.snapshot.slots))
	FileAccess.open(folder.path_join("reconnect"+str(int(fixture.index))+".json"),FileAccess.WRITE).store_string(JSON.stringify({"ok":true,"render_us":Time.get_ticks_usec()-began,"trace":Engine.get_meta("sync_trace")}))
	await world.close_world();print("SYNC_RECONNECT_PASS");quit()
