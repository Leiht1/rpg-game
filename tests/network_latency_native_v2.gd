extends SceneTree
var world: Node
var fixture: Dictionary
var folder: String
var actions: Array=[]
var frame_ms: Array=[]
var remote_samples: Array=[]
var last_frame:=0
var collecting:=false
var max_ack_age:=0
var prediction_blocked_frames:=0
var local_visual_events: Array=[]
var local_attack_active:=false
func _initialize() -> void:run.call_deferred()
func _process(_delta: float) -> bool:
	if collecting and is_instance_valid(world):
		var now:=Time.get_ticks_usec()
		if last_frame>0:frame_ms.append((now-last_frame)/1000.0)
		last_frame=now
		var age: int=Time.get_ticks_msec()-world.player.confirmed_at
		max_ack_age=maxi(max_ack_age,age)
		if age>=1500 or world.player.pending_inputs.size()>=85:prediction_blocked_frames+=1
		var attacking: bool=not world.player.combat_render_state.get("attack",{}).is_empty()
		if attacking!=local_attack_active:
			local_attack_active=attacking
			local_visual_events.append({"at_us":Time.get_unix_time_from_system()*1000000,"attacking":attacking})
		for actor in world.actors.values():
			var remote_attacking: bool=not actor.remote_combat.get("attack",{}).is_empty()
			var signature:=str(actor.network_equipment)+str(actor.action)+str(remote_attacking)
			if signature!=actor.get_meta("audit_signature",""):
				actor.set_meta("audit_signature",signature)
				remote_samples.append({"at_us":Time.get_unix_time_from_system()*1000000,"player_id":str(actor.get_meta("combat_id","")),"attacking":remote_attacking,"equipment":actor.network_equipment.duplicate(true),"action":actor.action})
	return false
func wait_idle() -> void:
	var deadline:=Time.get_ticks_msec()+180000
	while (world.requesting or not world.commands.is_empty()) and Time.get_ticks_msec()<deadline:await process_frame
func command(label: String, operation: String, args: Array=[]) -> bool:
	var start:=Time.get_ticks_usec()
	var before: int=world.commands.size()
	world.last_error=""
	world.enqueue(operation,args)
	var request_id: String=str(world.commands[-1].request_id) if not world.commands.is_empty() else ""
	var enqueued:=Time.get_ticks_usec()
	var row:={"label":label,"operation":operation,"sent_at_us":Time.get_unix_time_from_system()*1000000,"queue_before":before,"enqueue_ms":(enqueued-start)/1000.0}
	var deadline:=Time.get_ticks_msec()+180000
	while world.commands.any(func(c):return str(c.request_id)==request_id) and Time.get_ticks_msec()<deadline:await process_frame
	row.confirm_ms=(Time.get_ticks_usec()-start)/1000.0
	row.ok=world.last_error.is_empty() and world.commands.is_empty()
	row.error=world.last_error
	row.request_id=request_id;row.began_us=start
	await RenderingServer.frame_post_draw
	row.render_ms=(Time.get_ticks_usec()-start)/1000.0
	actions.append(row)
	print("ACTION ",label," ",row.confirm_ms," ",row.ok)
	return row.ok
func panel(label: String, callable: Callable) -> void:
	var began:=Time.get_ticks_usec();callable.call()
	await RenderingServer.frame_post_draw
	actions.append({"label":label,"operation":"local_ui","render_ms":(Time.get_ticks_usec()-began)/1000.0,"ok":true})
	world.item_ui.close_panels();world.map_view.close_map()
	await create_timer(.3).timeout
func walk_to(target: Vector2, radius: float=45.0, seconds: float=8.0) -> bool:
	var player=world.player
	player.automated=true
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	var last: Vector2=player.position
	var stuck:=0
	while player.position.distance_to(target)>radius and Time.get_ticks_msec()<deadline:
		var direction: Vector2=(target-player.position).normalized()
		if stuck>5:direction=direction.rotated((1 if int(fixture.index)%2==0 else -1)*PI*.4)
		player.input_override=direction
		await create_timer(.1).timeout
		stuck=stuck+1 if player.position.distance_to(last)<2 else 0
		last=player.position
	player.input_override=Vector2.ZERO
	await create_timer(.2).timeout
	return player.position.distance_to(target)<=radius
func gather() -> void:
	var visited: Dictionary={}
	for turn in 24:
		var targets: Array=[]
		for node in world.object_root.get_children():
			if not node is Node2D or node==world.player or not node.visible or visited.has(node.get_instance_id()):continue
			if node.position.distance_to(world.player.position)>650:continue
			if node.has_meta("animal_id") or node.has_meta("building_id") or node.has_meta("camp_id"):continue
			if load("res://scripts/world_interaction.gd").action_for(node)!="pickup":continue
			targets.append(node)
		if targets.is_empty():break
		targets.sort_custom(func(a,b):return a.position.distance_to(world.player.position)<b.position.distance_to(world.player.position))
		var node: Node2D=targets[mini(int(fixture.index),targets.size()-1)]
		visited[node.get_instance_id()]=true
		var at: Vector2=node.position
		if not await walk_to(at):
			actions.append({"label":"pickup_approach","operation":"navigation_fixture","ok":false,"error":"approach timed out"});continue
		if not is_instance_valid(node):continue
		var identity: Dictionary=load("res://scripts/network_game_route.gd").encode(node)
		if identity.is_empty():continue
		await command("pickup_"+str(turn),"interact",[identity])
		await create_timer(.2).timeout
func inventory_checks() -> void:
	var inventory=world.item_service.inventory
	var destination: int=-1
	for i in range(8,40):
		if inventory.get_slot(i).is_empty():destination=i;break
	if destination>=0 and not inventory.get_slot(0).is_empty():
		await command("move_guide_out","inventory",["move_slot",0,destination])
		await command("move_guide_back","inventory",["move_slot",destination,0])
	await command("organize","organize")
	for i in range(8,40):
		if inventory.get_slot(i).get("count",0)>1:
			await command("split_stack","inventory",["split_slot",i,1]);break
	for i in range(8,40):
		if not inventory.get_slot(i).is_empty():
			await command("discard_one","discard",[i,1]);break
func crafting_checks() -> void:
	var s=world.item_service
	for recipe in ["hand_leaf_fiber","hand_stone_axe","hand_stone_pickaxe","hand_field_lantern","hand_stone_hammer","hand_simple_shovel"]:
		if not s.craft_check(recipe,1).is_empty():continue
		if await command("craft_"+recipe,"craft",[recipe,1]):
			var start:=Time.get_ticks_msec()
			while not s.craft_job.is_empty() and Time.get_ticks_msec()-start<30000:await create_timer(.1).timeout
			actions.append({"label":"craft_completion_"+recipe,"operation":"craft_completion","confirm_ms":Time.get_ticks_msec()-start,"ok":s.craft_job.is_empty(),"includes_designed_craft_time":true})
	for i in range(8,40):
		var slot: Dictionary=s.inventory.get_slot(i)
		if slot.is_empty():continue
		var definition: Dictionary=s.database.item(slot.item_id)
		if definition.get("equippable",false):
			await command("equip_"+str(slot.item_id),"inventory",["equip",i])
			await create_timer(.5).timeout
			await command("unequip_"+str(slot.item_id),"inventory",["unequip",40])
			break
	for i in range(8,40):
		var slot: Dictionary=s.inventory.get_slot(i)
		if slot.get("item_id","")=="field_lantern":
			await command("lamp_on","lamp",[i]);await command("lamp_off","lamp",[i]);break
func run() -> void:
	Engine.set_meta("network_timings",{})
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):
			folder=arg.trim_prefix("--fixture=").get_base_dir();fixture=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--fixture=")))
	var net=root.get_node("Network")
	net.http_channels.game=load("res://tests/network_latency_channel_v1.gd").new()
	net.http_channels.game_snapshot=load("res://tests/network_latency_channel_v1.gd").new()
	net.http_channels.poll=load("res://tests/network_latency_channel_v1.gd").new()
	net.http_channels.move=load("res://tests/network_latency_channel_v1.gd").new()
	net.http_channels.move.record_roster=true
	net.http_channels.poll.record_roster=fixture.get("mode","")=="remote"
	var response: Dictionary=await net.call_api("login",{"username":fixture.username,"password":fixture.password})
	if not response.get("ok",false):push_error("Test login failed");quit(1);return
	response=await net.call_api("resume",{})
	response=await net.call_api("character",{"appearance":response.character.appearance})
	if not response.get("ok",false):push_error("Test entry failed");quit(1);return
	var state: Dictionary=await net.call_api("game_snapshot",{})
	response.initial_snapshot=state.snapshot
	world=load("res://tests/network_latency_world_v1.gd").new();world.session_data=response;root.add_child(world);current_scene=world
	while not world.started:await process_frame
	var marker:=FileAccess.open(folder.path_join("ready"+str(int(fixture.index))),FileAccess.WRITE);marker.store_string("ready");marker.close()
	var deadline:=Time.get_ticks_msec()+120000
	while Time.get_ticks_msec()<deadline:
		var ready:=true
		for i in int(fixture.players):ready=ready and FileAccess.file_exists(folder.path_join("ready"+str(i)))
		if ready:break
		await create_timer(.1).timeout
	await create_timer(3).timeout
	collecting=true
	await panel("open_bag",world.item_ui.toggle_bag)
	await panel("open_body",world.item_ui.body_ui.toggle)
	await panel("open_craft",world.item_ui.toggle_craft)
	await panel("open_build",world.item_ui.toggle_build)
	await panel("open_map",world.item_ui.toggle_map)
	var origin: Vector2=world.player.position
	world.player.automated=true
	for turn in (24 if fixture.get("mode","")=="remote" else 12):
		world.player.input_override=Vector2.RIGHT if turn%2==0 else Vector2.LEFT
		if turn%4==2:await command("attack_"+str(turn),"combat_attack",[{"x":0,"y":1}])
		await create_timer(1).timeout
	world.player.input_override=Vector2.ZERO
	await inventory_checks()
	await crafting_checks()
	if fixture.get("mode","")=="soak":
		var until: int=Time.get_ticks_msec()+int(fixture.get("seconds",120))*1000
		var turn:=0
		while Time.get_ticks_msec()<until:
			world.player.input_override=Vector2.RIGHT if turn%2==0 else Vector2.LEFT
			await command("soak_organize_"+str(turn),"organize")
			if turn%3==0:await command("soak_attack_"+str(turn),"combat_attack",[{"x":0,"y":1}])
			await create_timer(.65).timeout;turn+=1
		world.player.input_override=Vector2.ZERO
	else:
		if fixture.get("mode","")!="remote":
			await gather()
			await crafting_checks()
			await inventory_checks()
	# Explicit rejection timings do not count as successful gameplay coverage.
	for row in [["station",[""]],["craft_cancel",[]],["fish_cancel",[]],["fish_start",[]],["fish_judge",[]],["wake",[]]]:
		await command("attempt_"+str(row[0]),row[0],row[1])
	await command("end_organize","organize")
	await create_timer(3).timeout
	var done:=FileAccess.open(folder.path_join("done"+str(int(fixture.index))),FileAccess.WRITE);done.store_string("done");done.close()
	var done_deadline:=Time.get_ticks_msec()+30000
	while Time.get_ticks_msec()<done_deadline:
		var all_done:=true
		for i in int(fixture.players):all_done=all_done and FileAccess.file_exists(folder.path_join("done"+str(i)))
		if all_done:break
		await create_timer(.1).timeout
	await create_timer(1).timeout
	collecting=false
	FileAccess.open(folder.path_join("result"+str(int(fixture.index))+".json"),FileAccess.WRITE).store_string(JSON.stringify({"scope":"isolated cloud clone over SSH forwarded TLS; real rendered client; same world and normal cadence; not production endpoint or raw WAN RTT","players":fixture.players,"actions":actions,"channel":net.http_channels.game.audit_rows,"snapshot_channel":net.http_channels.game_snapshot.audit_rows,"move_channel":net.http_channels.move.audit_rows,"roster_channel":net.http_channels.poll.audit_rows,"snapshot_apply":world.audit_apply,"api_ms":Engine.get_meta("network_timings"),"frame_ms":frame_ms,"max_move_ack_age_ms":max_ack_age,"prediction_blocked_frames":prediction_blocked_frames,"self_player_id":str(world.session_data.character.id),"local_visual_events":local_visual_events,"remote_changes":remote_samples,"travel":origin.distance_to(world.player.position)},"  "))
	print("NATIVE_LATENCY_DONE actions=",actions.size()," frames=",frame_ms.size())
	await world.close_world();quit()
