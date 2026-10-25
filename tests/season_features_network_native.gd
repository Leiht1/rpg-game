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
	Engine.set_meta("season_features_preview",true)
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
	var sim=world.environment_view.simulation
	verify(sim.season_date().index==3 and sim.lakes_frozen(),"authority winter and freeze on both clients")
	verify(sim.snow>=.9,"surface state restored from shared authority")
	verify(world.generator.season_sim==sim,"collision uses same authoritative environment")
	var hits:=0
	for lake in world.generator.lakes:
		var p:=Vector2(lake.x,lake.y)
		if world.generator.lake_weight(p)>.9:
			verify(world.generator.can_walk(p) and world.generator.frozen_at(p),"real lake authority collision")
			hits+=1
	verify(hits>0,"inland lake exists")
	verify(not world.generator.frozen_at(Vector2(-1,-1)),"ocean remains liquid")
	await create_timer(2).timeout
	verify(sim.lakes_frozen() and sim.snow>=.9,"polling retains surface state")
	var output={"checks":checks,"surface":sim.serialize().season_surface,"frozen":sim.lakes_frozen(),"day":sim.day}
	FileAccess.open("res://reports/season-features-v1/network/client"+str(int(fixture.index))+".json",FileAccess.WRITE).store_string(JSON.stringify(output))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/season-features-v1/network/client"+str(int(fixture.index))+".png")
	print("WEATHER NETWORK ",fixture.index,": ",checks," passed")
	world.stopping=true
	Engine.remove_meta("network_game_controller")
	world.queue_free();await process_frame;quit()
