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
	checks+=1;print("CHECK ",value," ",message)
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
	print("REQUEST initial snapshot")
	var snapshot: Dictionary=await network.call_api("game_snapshot",{})
	verify(snapshot.get("ok",false),"original server snapshot: "+str(snapshot.get("error","")))
	if not snapshot.get("ok",false):return
	entered.initial_snapshot=snapshot.snapshot
	print("START world creation")
	world=load("res://scripts/network_game_world.gd").new();world.session_data=entered;root.add_child(world);current_scene=world
	for i in 500:
		if world.started and world.actors.size()==1:break
		await create_timer(.05).timeout
	verify(world.started,"original world loaded")
	verify(world.actors.size()==1,"second real player visible")
	world.player.set_physics_process(false)


	var q=world.item_service.chapter
	verify(q.state.stage==4,"shared lakeside fishing clue")
	var f=world.get_node("Fishing")
	var deadline:=Time.get_ticks_msec()+100000
	var last_judge:=0
	var starts:=0
	while q.state.stage<5 and Time.get_ticks_msec()<deadline:
		if q.state.bottle_claimed:
			for i in 40:
				if world.item_service.inventory.slots[i].get("item_id","")==q.BOTTLE and world.commands.is_empty():
					world.item_service.inventory.use_slot(i);break
		elif f.state=="idle" and world.commands.is_empty():
			if f.try_start():starts+=1
		elif f.state=="game" and world.commands.is_empty() and Time.get_ticks_msec()-last_judge>550 and absf(f.bar.marker-f.bar.safe_center)<.025:
			f.judge();last_judge=Time.get_ticks_msec()
		await create_timer(.025).timeout
	verify(q.state.stage==5 and q.state.bottle_read,"concurrent real fishing and owner opening shared mine clue")
	verify(starts>0,"original rod fishing used in real window")
	var amounts: Dictionary={}
	for slot in world.item_service.inventory.slots:
		if slot.get("item_id","")==q.BOTTLE:amounts[q.BOTTLE]=int(amounts.get(q.BOTTLE,0))+int(slot.count)
	verify(amounts.get(q.BOTTLE,0)<=1,"no personal bottle duplicate")
	# The other player can finish the chapter while this rod is still out.
	# End that real fishing session before testing an NPC conversation.
	f.finish("")
	for wait_cancel in 200:
		if world.commands.is_empty() and f.state=="idle":break
		await create_timer(.05).timeout
	world.item_service.chapter_view.close_page()
	world.item_service.chapter_view.investigate("shore")
	for wait_page in 200:
		if world.commands.is_empty() and world.item_service.chapter_view.panel.visible:break
		await create_timer(.05).timeout
	print("SHARED PAGE ",world.item_service.chapter_view.words.text," ERROR ",world.last_error," FISH ",f.state)
	verify(world.item_service.chapter_view.panel.visible and world.item_service.chapter_view.words.text.contains("废弃矿洞"),"both players reread shared mine record at river")
	world.stopping=true
	network.token=""
	var relogin: Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password})
	verify(relogin.get("ok",false),"fresh authenticated session after disconnect")
	var resume2: Dictionary=await network.call_api("resume",{})
	verify(resume2.get("ok",false),"resume saved character")
	var enter2: Dictionary=await network.call_api("character",{"appearance":resume2.character.appearance})
	verify(enter2.get("ok",false),"reenter original world")
	var restored: Dictionary=await network.call_api("game_snapshot",{})
	verify(restored.get("ok",false) and restored.snapshot.exploration_chapter.stage==5,"reconnect preserves shared completed clue")
	FileAccess.open("res://reports/exploration-waits-v2/network-lake/client"+str(int(fixture.index))+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"chapter":q.state,"amounts":amounts,"starts":starts}))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/exploration-waits-v2/network-lake/client"+str(int(fixture.index))+".png")
	print("EXPLORATION NETWORK ",fixture.index,": ",checks," passed")
	Engine.remove_meta("network_game_controller");world.queue_free();await process_frame;quit(1 if failed else 0)
