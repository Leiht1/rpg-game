extends SceneTree
var checks:=0
var sample_frames:=false
var frame_times:Array=[]
var max_pending:=0
var max_ack_age:=0
var blocked_prediction:=0
var blocked_loading:=0
var remote_times:Array=[]
var last_remote_sample:=-1.0
var last_remote_arrival:=0
var remote_max_step:=0.0
var last_remote_position:=Vector2.INF
func _process(delta:float)->bool:
	if sample_frames:
		frame_times.append(delta*1000.0)
		if not world.actors.is_empty():
			var actor=world.actors.values()[0]
			if actor.sample_time!=last_remote_sample:
				if last_remote_arrival>0:remote_times.append(Time.get_ticks_msec()-last_remote_arrival)
				last_remote_sample=actor.sample_time;last_remote_arrival=Time.get_ticks_msec()
			if last_remote_position.is_finite():remote_max_step=maxf(remote_max_step,actor.position.distance_to(last_remote_position))
			last_remote_position=actor.position
		max_pending=maxi(max_pending,world.player.pending_inputs.size())
		max_ack_age=maxi(max_ack_age,Time.get_ticks_msec()-world.player.confirmed_at)
		if world.player.pending_inputs.size()>=85 or Time.get_ticks_msec()-world.player.confirmed_at>=1500:blocked_prediction+=1
		if world.player.blocked_by_loading:blocked_loading+=1
	return false
var fixture: Dictionary={}
var world: Node
var folder: String
func verify(value: bool, message: String) -> void:
	checks+=1
	if not value:push_error("FAIL "+message);quit(1)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture="):
			folder=argument.trim_prefix("--fixture=").get_base_dir()
			fixture=JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--fixture=")))
	var network=root.get_node("Network")
	var response: Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password})
	verify(response.get("ok",false),"login: "+str(response.get("error","")))
	var ready:=FileAccess.open(folder.path_join("login"+str(int(fixture.index))),FileAccess.WRITE);ready.store_string("ready");ready.close()
	for wait_login in 600:
		if FileAccess.file_exists(folder.path_join("login"+str(1-int(fixture.index)))):break
		await create_timer(.05).timeout
	response=await network.call_api("resume",{})
	verify(response.get("ok",false),"resume")
	var entered: Dictionary=await network.call_api("character",{"appearance":response.character.appearance})
	verify(entered.get("ok",false) and entered.get("gameplay_enabled",false),"full game enabled: "+str(entered.get("error","")))
	var entered_ready:=FileAccess.open(folder.path_join("entered"+str(int(fixture.index))),FileAccess.WRITE);entered_ready.store_string("ready");entered_ready.close()
	for wait_enter in 600:
		if FileAccess.file_exists(folder.path_join("entered"+str(1-int(fixture.index)))):break
		await create_timer(.05).timeout
	var snapshot: Dictionary=await network.call_api("game_snapshot",{})
	verify(snapshot.get("ok",false),"original server snapshot: "+str(snapshot.get("error","")))
	if not snapshot.get("ok",false):return
	entered.initial_snapshot=snapshot.snapshot
	world=load("res://scripts/network_game_world.gd").new();world.session_data=entered;root.add_child(world);current_scene=world
	for i in 500:
		if world.started and world.actors.size()==1:break
		await create_timer(.05).timeout
	verify(world.started,"original world loaded")
	verify(world.actors.size()==1,"second real player visible")
	world.player.set_physics_process(false)
	var initial_health: float=world.item_service.body.health
	verify(world.item_service.body.cold_level==3,"authoritative extreme state restored")
	verify(world.environment_view.simulation.blend.y>.99,"shared real storm")
	if int(fixture.index)==0:
		world.item_service.inventory.equip(0)
		for i in 200:
			if world.item_service.inventory.equipment.get("main_hand",{}).get("item_id","")=="rain_umbrella":break
			await create_timer(.05).timeout
		verify(world.item_service.inventory.equipment.get("main_hand",{}).get("item_id","")=="rain_umbrella","real remote equip request confirmed")
		var command := {"request_id":"cf462b81a270401c9248b65d329e0d31","operation":"inventory","args":["equip",0],"selected":0}
		var once: Dictionary=await network.call_api("game_command",command)
		var twice: Dictionary=await network.call_api("game_command",command)
		verify(once.get("ok",false) and twice.get("ok",false),"duplicate umbrella command acknowledged")
		var entries: Array=twice.snapshot.slots.duplicate()+twice.snapshot.equipment.values()
		verify(entries.filter(func(row):return row.get("item_id","")=="rain_umbrella").size()==1,"duplicate request retains one physical umbrella")
	await create_timer(6.0).timeout
	var body=world.item_service.body
	verify(body.health<initial_health and body.health>initial_health-1,"authority applies slow extreme damage")
	verify(body.cold_level==3,"both clients retain extreme state")
	if int(fixture.index)==0:verify(body.wetness<100,"umbrella stops rain wetting through authority")
	else:verify(body.wetness==100,"unprotected client remains soaked")
	var previous: float=body.health
	body.health=1 # A local mutation is overwritten by the next authority response.
	for i in 100:
		if body.health>80:break
		await create_timer(.05).timeout
	verify(body.health>80 and body.health<=previous,"client cannot persist local health mutation")
	var ui=world.item_ui.body_ui;ui.refresh()
	verify(ui.weather_summary.text.contains("湿透") and ui.weather_summary.text.contains("极冷"),"native network HUD displays authority")
	ui.toggle();ui.refresh();verify(ui.details.text.contains("雷暴雨"),"network details show real storm")
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/weather-v1/network-client"+str(int(fixture.index))+".png")
	ui.close_panel()
	var output: Dictionary={"checks":checks,"health":body.health,"wetness":body.wetness,"temperature":body.felt_temperature,"cold_level":body.cold_level,"weather":world.environment_view.simulation.serialize()}
	FileAccess.open("res://reports/weather-v1/network-client"+str(int(fixture.index))+".json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("WEATHER NETWORK ",fixture.index,": ",checks," passed")
	world.stopping=true
	Engine.remove_meta("network_game_controller")
	world.queue_free();await process_frame;quit()
