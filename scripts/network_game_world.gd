extends "res://scripts/world.gd"
signal returned
var session_data: Dictionary={}
var routes: Dictionary={}
var commands: Array=[]
var interaction_preview=preload("res://scripts/network_interaction_preview.gd").new()
var stopping:=false
var typing:=false
var applying:=false
var moving_request:=false
var requesting:=false
var interaction_fence:=false
var polling:=false
var last_error:=""
var sequence:=0
var move_clock:=0.0
var sync_clock:=0.0
var roster_clock:=0.0
var actors: Dictionary={}
var players_sample_time:=-1.0
var entry:=LineEdit.new()
var chat:=VBoxContainer.new()
func load_world_identity(_path: String=WORLD_ID_PATH) -> void:
	world_seed=int(session_data.world.seed);map_cells=int(session_data.world.map_cells)
	world_id=str(session_data.world.id);persistent_world=false
	set_meta("character_preview",true);set_meta("network_game",true)
	set_meta("network_player_id",str(session_data.character.id))
func save_world_identity(_path: String=WORLD_ID_PATH) -> void:pass
func parse_arguments() -> void:pass
func create_player() -> WildPlayer:return preload("res://scripts/network_game_player.gd").new()
func _ready() -> void:
	super._ready()
	player.character_look=session_data.character.appearance
	player.confirmed_at=Time.get_ticks_msec()
	player.position=Vector2(session_data.character.x,session_data.character.y)
	var nickname:=Label.new();nickname.text=str(session_data.profile.nickname);nickname.position=Vector2(-70,-105);nickname.size.x=140;nickname.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;player.add_child(nickname)
	for owner in [item_service,item_service.inventory,item_service.camps,item_service.builds,item_service.industry,item_service.expansion,item_service.planting,item_service.animals,item_service.combat,item_service.sleep,item_service.merchant]:routes[owner.get_instance_id()]=true
	routes[get_node("Fishing").get_instance_id()]=true
	Engine.set_meta("network_game_controller",self)
	if session_data.has("initial_snapshot"):apply_snapshot(session_data.initial_snapshot)
	var game_menu=preload("res://scripts/world_menu.gd").new()
	game_menu.world_provider=func():return self
	game_menu.return_action=close_world
	add_child(game_menu)
	ui.add_child(chat);chat.position=Vector2(20,470);chat.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(entry);entry.position=Vector2(20,640);entry.size=Vector2(620,36);entry.max_length=120;entry.hide();entry.text_submitted.connect(send_chat)
	call_deferred("sync_server")
func enqueue(operation: String, args: Array) -> void:
	if stopping or applying:return
	if commands.size()>=24:item_ui.show_notice("正在同步，请稍候");return
	var command:={"request_id":Crypto.new().generate_random_bytes(16).hex_encode(),"operation":operation,"args":args,"expected":{}}
	if operation=="interact":
		command.input_boundary=player.input_id
		# Freeze this input ID: later frames must not merge movement into it.
		player.sent_input_id=maxi(player.sent_input_id,player.input_id)
	var indices: Array=[]
	if operation=="inventory":
		indices.append(int(args[1]))
		if args[0] in ["move_slot","equip_hotbar"]:indices.append(int(args[2]))
	elif operation in ["discard","lamp"] and int(args[0])>=0:indices.append(int(args[0]))
	for index in indices:command.expected[str(index)]=item_service.inventory.get_slot(index).duplicate(true)
	commands.append(command)
	if operation=="interact":
		for target in object_root.get_children():
			var matches:=false
			for key in args[0]:
				if target.has_meta(key) and str(target.get_meta(key))==str(args[0][key]):matches=true;break
			if matches:
				interaction_preview.begin(str(command.request_id),target,preload("res://scripts/world_interaction.gd").action_for(target),player)
				break
	if operation=="combat_attack":item_service.combat.begin_attack_preview(Vector2(args[0].x,args[0].y))
	if not requesting:sync_server.call_deferred()
func _process(delta: float) -> void:
	super._process(delta)
	hint.text=hint.text.replace(" · N 新世界","").replace(" · F3 调试","").replace(" · F4 环境","").replace(" · F7 资源分布","")
	if stopping:return
	move_clock+=delta;sync_clock+=delta;roster_clock+=delta
	if roster_clock>=.1 and not polling:roster_clock=0;poll_server()
	if move_clock>=.08 and not moving_request:move_clock=0;move_server()
	var sync_interval:=.12 if not item_service.combat.personal.attack.is_empty() else .4
	if sync_clock>=sync_interval and not requesting:sync_clock=0;sync_server()
	item_service.sleep.render()
func move_server() -> void:
	if moving_request or interaction_fence or stopping:return
	var limit_id: int=-1
	for command in commands:
		if command.has("input_boundary"):
			limit_id=int(command.input_boundary);break
	if limit_id>=0 and player.acknowledged_input_id>=limit_id:return
	moving_request=true;sequence+=1
	var region_serial: int=int(item_service.chapter.mine.travel.serial)
	var response: Dictionary=await Network.call_api("move",{"mine_serial":region_serial,"seq":sequence,"dx":0,"dy":0,"inputs":player.movement_batch(limit_id),"pose":{"action":player.action,"clock":player.action_clock,"facing":player.facing}})
	moving_request=false
	if stopping or region_serial!=int(item_service.chapter.mine.travel.serial):return
	if response.get("ok",false):
		player.acknowledge(response.character,int(response.input_ack))
		if response.has("players"):update_players(response.players,float(response.get("players_sample_time",-1)))
	else:item_ui.show_notice(response.get("error","移动同步失败"))
func sync_server() -> void:
	if requesting or stopping:return
	requesting=true
	var command: Dictionary=commands[0].duplicate(true) if not commands.is_empty() else {}
	if command.has("input_boundary"):
		# Confirm only movement up to the action, then keep later movement local
		# until the authority has checked the action at that ordered position.
		while moving_request or player.acknowledged_input_id<int(command.input_boundary):
			if stopping:requesting=false;return
			if not moving_request:move_server()
			await get_tree().process_frame
		interaction_fence=true
	command.selected=item_service.inventory.selected
	command.station=item_service.craft_station_id
	var response: Dictionary=await Network.call_api("game_snapshot" if commands.is_empty() else "game_command",command)
	interaction_fence=false
	if stopping:requesting=false;return
	if response.get("ok",false):
		var preview_chop: bool=interaction_preview.pending.get(str(command.get("request_id","")),{}).get("action","")=="chop"
		if command.has("request_id"):
			commands.pop_front()
			interaction_preview.finish(str(command.request_id),true)
		apply_snapshot(response.snapshot)
		if command.get("operation")=="combat_attack":item_service.combat.confirm_attack_preview(true)
		for event in response.get("events",[]):
			match event.kind:
				"chapter_page":item_service.chapter_view.show_page(str(event.text))
				"notice":item_service.notice.emit(str(event.text))
				"obtained":item_service.item_obtained.emit(str(event.id),int(event.count))
				"sound":
					if event.key=="sfx_chop_hit" and preview_chop:continue
					AudioFX.play_sfx(str(event.key),Vector2(event.at.x,event.at.y) if not event.at.is_empty() else Vector2.INF)
	elif command.has("request_id"):
		if command.get("operation") in ["chapter","chapter_read"]:item_service.chapter_view.close_page()
		if command.get("operation")=="mine" and item_service.chapter_view.transition.active:item_service.chapter_view.transition.prepare_reveal()
		last_error=str(response.get("error","操作同步失败"))
		# Keep the same ID after transport failure; never retry a rejected command.
		if not str(response.get("error","")).begins_with("服务器暂时不可用") and not str(response.get("error","")).begins_with("无法连接服务器"):
			commands.pop_front()
			interaction_preview.finish(str(command.request_id))
			if command.get("operation")=="combat_attack":item_service.combat.confirm_attack_preview(false)
		item_ui.show_notice(response.get("error","操作同步失败"))
	requesting=false
	if not commands.is_empty():sync_server.call_deferred()


func poll_server() -> void:
	if polling or stopping:return
	polling=true
	var poll: Dictionary=await Network.call_api("poll",{"cursor":Network.cursor})
	polling=false
	if stopping:return
	if not poll.get("ok",false):
		var error:=str(poll.get("error","连接中断"))
		item_ui.show_notice(error)
		if error.contains("会话已过期") or error.contains("账号已禁用"):
			Network.token="";close_world.call_deferred()
		return
	if poll.get("ok",false):
		Network.cursor=int(poll.cursor)
		# Reject old rosters regardless of which request completes first.
		update_players(poll.players,float(poll.get("players_sample_time",-1)))
		for message in poll.messages:show_chat(message)
	if not commands.is_empty():sync_server.call_deferred()
func update_players(players: Array, sampled_at: float=-1.0) -> void:
	if sampled_at>=0:
		if sampled_at<players_sample_time:return
		players_sample_time=sampled_at
	var present: Dictionary={}
	for row in players:
		if row.player_id==Network.profile.player_id:continue
		present[row.player_id]=true
		if not actors.has(row.player_id):
			var actor=preload("res://scripts/network_actor.gd").new();actor.generator=generator;actor.stream=stream;actor.position=Vector2(row.x,row.y);actor.input_blocked=true;object_root.add_child(actor);actor.camera.enabled=false;actors[row.player_id]=actor
			var label:=Label.new();label.name="Nickname";label.position=Vector2(-70,-105);label.size.x=140;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;actor.add_child(label)
		actors[row.player_id].set_meta("combat_id",str(row.id))
		actors[row.player_id].get_node("Nickname").text=row.nickname;actors[row.player_id].receive(row)
	for id in actors.keys():
		if not present.has(id):actors[id].queue_free();actors.erase(id)
func map_players() -> Array[Dictionary]:
	var result: Array[Dictionary]=[{"position":player.position,"name":str(session_data.profile.nickname),"self":true}]
	for actor in actors.values():
		if not is_instance_valid(actor):continue
		result.append({"position":actor.position,"name":actor.get_node("Nickname").text,"self":false})
	return result
func cancel_movement_interactions() -> void:
	# Teleports and downed-state changes invalidate the pending movement path.
	# Do not leave an interaction waiting for input IDs discarded by that reset.
	for index in range(commands.size()-1,-1,-1):
		if commands[index].has("input_boundary"):
			interaction_preview.finish(str(commands[index].request_id))
			commands.remove_at(index)
func apply_snapshot(source: Dictionary) -> void:
	applying=true
	var snapshot:=source.duplicate(true)
	var changed_region: bool=snapshot.get("mine_travel",{}).get("serial",0)!=item_service.chapter.mine.travel.serial
	if changed_region:item_service.chapter_view.transition.cover_now()
	var changed_life: bool=snapshot.get("combat_personal",{}).get("phase","alive")!=item_service.combat.personal.phase
	changed_life=changed_life or snapshot.get("combat_personal",{}).get("hit_serial",0)!=item_service.combat.personal.get("hit_serial",0)
	if changed_life or changed_region:
		cancel_movement_interactions()
		player.pending_inputs.clear();player.correction=Vector2.ZERO
	else:snapshot.player_position={"x":player.position.x,"y":player.position.y}
	var selected: int=item_service.inventory.selected
	var previous_hits: Dictionary=stream.tree_hits.duplicate()
	var previous_job: Dictionary=item_service.craft_job.duplicate(true)
	item_service.writable=true;item_service.load_state("",false,snapshot)
	if changed_life or changed_region:
		player.reset_physics_interpolation();player.camera.reset_smoothing();stream.update_target(player.position)
	if changed_region:item_service.chapter_view.transition.prepare_reveal()
	item_service.inventory.selected=selected
	item_service.restore_network_lamp(snapshot)
	item_service.merchant.sync_actor()
	item_service.craft_job=snapshot.get("network_craft_job",{}).duplicate(true)
	if not item_service.craft_job.is_empty():item_service.craft_progress.emit(float(item_service.craft_job.elapsed)/maxf(.001,float(item_service.craft_job.duration)))
	elif not previous_job.is_empty():item_service.craft_finished.emit(str(previous_job.recipe_id),int(previous_job.batches),"")
	item_service.animals.sync_visuals()
	get_node("Fishing").network_restore(snapshot.get("network_fishing",{}))
	if not item_service.body.sleep_active():
		if is_instance_valid(item_service.sleep.symbols):item_service.sleep.symbols.hide()
		if is_instance_valid(item_service.sleep_ui):item_service.sleep_ui.wake.hide()
	item_ui.update_input_block()
	if typing or get_meta("world_menu_open",false):player.input_blocked=true
	for node in object_root.get_children():
		var prop_id:=str(node.get_meta("prop_id",""))
		if node.is_in_group("trees") and snapshot.harvested.has(prop_id):
			node.remove_from_group("trees");node.fade_out();stream.call_deferred("refresh_grounding",node.position);continue
		if node.is_in_group("trees") and int(snapshot.tree_hits.get(prop_id,0))>int(previous_hits.get(prop_id,0)):
			if int(node.get_meta("network_preview_hits",0))>0:node.set_meta("network_preview_hits",int(node.get_meta("network_preview_hits"))-1)
			else:node.hit()
		if node.has_method("fade_out") and node.get("state") in ["fading","removed"]:continue
		for key in ["prop_id","ore_id","drop_id"]:
			var id:=str(node.get_meta(key,""))
			if not id.is_empty() and (snapshot.harvested.has(id) or snapshot.consumed.has(id)):
				stream.drops.erase(node)
				node.set_meta("collected",true);node.hide();node.queue_free()
	var visible_drops: Dictionary={}
	for node in stream.drops:
		if is_instance_valid(node):visible_drops[str(node.get_meta("drop_id",""))]=true
	for id in item_service.loose:
		var row: Dictionary=item_service.loose[id]
		if not visible_drops.has(str(id)) and stream.loaded.has(stream.chunk_at(Vector2(row.x,row.y))):
			var value:=row.duplicate(true);value.id=id;stream.create_item_drop(value)
	applying=false
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode in [KEY_N,KEY_F3,KEY_F7] or (event.physical_keycode in [KEY_F4,KEY_F6] and not preload("res://scripts/debug_access.gd").allowed())):get_viewport().set_input_as_handled();return
	super._unhandled_input(event)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE and typing:
		entry.hide();entry.release_focus();typing=false;item_ui.update_input_block();get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode in [KEY_N,KEY_F3,KEY_F7] or (event.physical_keycode in [KEY_F4,KEY_F6] and not preload("res://scripts/debug_access.gd").allowed())) and not get_viewport().gui_get_focus_owner() is LineEdit:get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_Y and not typing and not get_viewport().gui_get_focus_owner() is LineEdit:
		typing=true;entry.show();entry.grab_focus();player.input_blocked=true;get_viewport().set_input_as_handled()
func send_chat(text: String) -> void:
	entry.hide();entry.release_focus();typing=false;item_ui.update_input_block()
	var response: Dictionary=await Network.call_api("chat",{"text":text})
	if not response.get("ok",false):item_ui.show_notice(response.get("error","发送失败"))
func show_chat(message: Dictionary) -> void:
	while chat.get_child_count()>=5:
		var oldest=chat.get_child(0);chat.remove_child(oldest);oldest.queue_free()
	var label:=Label.new();label.text=str(message.nickname)+"："+str(message.text);chat.add_child(label)
	var tween:=label.create_tween();tween.tween_interval(5);tween.tween_callback(label.queue_free)
func close_world() -> void:
	if stopping:return
	stopping=true;player.input_blocked=true
	while requesting or moving_request or polling:await get_tree().process_frame
	await Network.call_api("leave_lobby",{})
	returned.emit();queue_free()
func network_close() -> void:await close_world()
func _exit_tree() -> void:
	interaction_preview.clear()
	if Engine.has_meta("network_game_controller") and Engine.get_meta("network_game_controller")==self:Engine.remove_meta("network_game_controller")
