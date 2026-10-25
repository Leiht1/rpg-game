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
	if not snapshot.get("ok",false):quit(1);return
	entered.initial_snapshot=snapshot.snapshot
	world=load("res://scripts/network_game_world.gd").new();world.session_data=entered;root.add_child(world);current_scene=world
	for i in 500:
		if world.started and world.actors.size()==1:break
		await create_timer(.05).timeout
	verify(world.started,"original world loaded")
	verify(world.actors.size()==1,"second real player visible")
	world.player.set_physics_process(false)

	var s=world.item_service;var q=s.chapter;var m=q.mine;var p=q.puzzle;var ui=s.chapter_view
	verify(p.state.solved and not p.state.claimed,"existing completed world before real chest award")
	await barrier("loaded");m.interact("chest");await settled();await barrier("claimed")
	verify(p.state.claimed and p.state.chest_open,"shared existing chest settlement")
	if s.inventory.count_item(p.RECORD)>0:q.use_item(p.RECORD)
	else:m.interact("chest")
	await settled();await create_timer(.6).timeout
	verify(ui.route_visible and ui.route_paper.visible and not ui.words.visible,"actual painted route reading on both clients")
	verify(ui.route_paper.picture.texture.resource_path.contains("coastal-route-v6"),"new flat coastal route resource")
	var hint: Dictionary=p.route_hint.resolve(s);var due: float=p.state.next_due
	verify(hint.direction_resolved and hint.source_rock_region!=hint.connected_rock_region,"distinct coastal rock region resolved")
	verify(hint.terrain=="sea_eroded_ruins_plateau" and not hint.target_generated,"future platform contract without creating location")
	verify(ui.route_paper.hint==hint,"rendered compass uses same real world contract")
	verify(ui.reading_layer.layer>s.world.item_ui.obtained.layer,"reward UI stays behind map")
	ui.close_page()
	if s.inventory.count_item(p.RECORD)>0:q.use_item(p.RECORD)
	else:m.interact("chest")
	await settled();verify(p.state.next_due==due and ui.route_visible,"repeated reading does not restart original wait")
	await barrier("read");await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/coastal-route-v6/network/client"+str(int(fixture.index))+".png")
	world.stopping=true;network.token=""
	var login_again: Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password})
	verify(login_again.get("ok",false),"fresh authenticated session")
	var resumed: Dictionary=await network.call_api("resume",{})
	var entered_again: Dictionary=await network.call_api("character",{"appearance":resumed.character.appearance})
	verify(entered_again.get("ok",false),"resume original character")
	var final: Dictionary=await network.call_api("game_snapshot",{})
	verify(final.get("ok",false) and final.snapshot.exploration_chapter.mine.puzzle.read and final.snapshot.exploration_chapter.mine.puzzle.next_due==due,"read state and shared deadline survive authentication")
	var records:=0
	for slot in final.snapshot.slots:
		if slot.get("item_id")==p.RECORD:records+=int(slot.count)
	FileAccess.open("res://reports/coastal-route-v6/network/client"+str(int(fixture.index))+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"records":records,"hint":hint,"due":due,"inside":final.snapshot.mine_travel.inside,"failed":failed}))
	print("COASTAL ROUTE NETWORK ",fixture.index,": ",checks," checks failed=",failed)
	Engine.remove_meta("network_game_controller");world.queue_free();await process_frame;quit(1 if failed else 0)
func settled() -> void:
	for i in 200:
		if world.commands.is_empty():break
		await create_timer(.05).timeout
	await create_timer(.4).timeout
func barrier(label: String) -> void:
	var marker:=FileAccess.open(folder.path_join(label+str(int(fixture.index))),FileAccess.WRITE);marker.store_string("ready");marker.close()
	for step in 600:
		if FileAccess.file_exists(folder.path_join(label+str(1-int(fixture.index)))):return
		await create_timer(.05).timeout
	verify(false,"peer barrier "+label)
