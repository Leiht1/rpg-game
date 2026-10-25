extends SceneTree
var failed:=false
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
	if not value:failed=true;push_error("FAIL "+message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	pass
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

	var q=world.item_service.chapter
	verify(q.state.stage==2,"shared undiscovered site restored")
	var original: Vector2=q.point("site")
	await create_timer(.5).timeout
	verify(world.item_service.chapter_view.props.has("remains"),"same real remains in both windows")
	world.item_service.chapter_view.investigate("remains")
	for wait_claim in 300:
		if q.state.stage>=3 and world.commands.is_empty():break
		await create_timer(.05).timeout
	verify(q.state.stage==3,"authority investigation shared")
	verify(world.item_service.chapter_view.panel.visible,"server returns readable investigation page")
	world.item_service.chapter_view.close_page()
	world.item_service.chapter_view.investigate("belongings")
	for wait_repeat in 200:
		if world.commands.is_empty():break
		await create_timer(.05).timeout
	verify(q.point("site")==original and q.state.stage==3,"repeat interaction stable")
	world.item_service.chapter_view.close_page()
	var waiting_deadline: float=q.state.elder_due
	world.stopping=true;network.token=""
	var login_again: Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password})
	verify(login_again.get("ok",false),"pending wait fresh authenticated session")
	var resumed: Dictionary=await network.call_api("resume",{})
	verify(resumed.get("ok",false),"pending wait resumes character")
	var entered_again: Dictionary=await network.call_api("character",{"appearance":resumed.character.appearance})
	verify(entered_again.get("ok",false),"pending wait reenters same world")
	var response2: Dictionary=await network.call_api("game_snapshot",{})
	verify(response2.get("ok",false),"reconnect snapshot")
	verify(response2.snapshot.exploration_chapter.stage==3,"reconnect progress preserved")
	verify(response2.snapshot.exploration_chapter.elder_due==waiting_deadline and not response2.snapshot.exploration_chapter.elder_spawned,"fresh authentication preserves exact wait with no early elder")
	var amounts: Dictionary={}
	for slot in response2.snapshot.slots:
		if slot.get("item_id","") in [q.MAP,q.NOTE]:amounts[slot.item_id]=int(amounts.get(slot.item_id,0))+int(slot.count)
	verify(amounts.get(q.MAP,0)<=1 and amounts.get(q.NOTE,0)<=1,"no local duplicated rewards")
	FileAccess.open("res://reports/exploration-waits-v2/network/client"+str(int(fixture.index))+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"chapter":q.state,"amounts":amounts}))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/exploration-waits-v2/network/client"+str(int(fixture.index))+".png")
	print("EXPLORATION NETWORK ",fixture.index,": ",checks," passed")
	world.stopping=true;Engine.remove_meta("network_game_controller");world.queue_free();await process_frame;quit(1 if failed else 0)
