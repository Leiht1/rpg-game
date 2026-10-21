extends "res://scripts/world.gd"
signal returned
var session_data: Dictionary={}
var routes: Dictionary={}
var commands: Array=[]
var stopping:=false
var typing:=false
var applying:=false
var moving_request:=false
var requesting:=false
var last_error:=""
var sequence:=0
var move_clock:=0.0
var sync_clock:=0.0
var actors: Dictionary={}
var entry:=LineEdit.new()
var chat:=VBoxContainer.new()
var return_dialog:=ConfirmationDialog.new()
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
	for owner in [item_service,item_service.inventory,item_service.camps,item_service.builds,item_service.industry,item_service.expansion,item_service.planting,item_service.animals,item_service.sleep,item_service.merchant]:routes[owner.get_instance_id()]=true
	routes[get_node("Fishing").get_instance_id()]=true
	Engine.set_meta("network_game_controller",self)
	if session_data.has("initial_snapshot"):apply_snapshot(session_data.initial_snapshot)
	var back:=Button.new();back.text="返回大厅";back.theme=preload("res://scripts/item_ui_style.gd").theme();back.position=Vector2(1120,16);back.custom_minimum_size=Vector2(140,40);ui.add_child(back);back.pressed.connect(confirm_return)
	return_dialog.theme=back.theme;return_dialog.title="返回大厅";return_dialog.dialog_text="确定返回大厅吗？角色和随身物品会保留。";return_dialog.ok_button_text="返回大厅";return_dialog.cancel_button_text="继续游戏";ui.add_child(return_dialog);return_dialog.confirmed.connect(close_world)
	return_dialog.canceled.connect(func():item_ui.update_input_block())
	ui.add_child(chat);chat.position=Vector2(20,470);chat.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(entry);entry.position=Vector2(20,640);entry.size=Vector2(620,36);entry.max_length=120;entry.hide();entry.text_submitted.connect(send_chat)
	call_deferred("sync_server")
func enqueue(operation: String, args: Array) -> void:
	if stopping or applying:return
	if commands.size()>=24:item_ui.show_notice("正在同步，请稍候");return
	var command:={"request_id":Crypto.new().generate_random_bytes(16).hex_encode(),"operation":operation,"args":args,"expected":{}}
	var indices: Array=[]
	if operation=="inventory":
		indices.append(int(args[1]))
		if args[0] in ["move_slot","equip_hotbar"]:indices.append(int(args[2]))
	elif operation in ["discard","lamp"] and int(args[0])>=0:indices.append(int(args[0]))
	for index in indices:command.expected[str(index)]=item_service.inventory.get_slot(index).duplicate(true)
	commands.append(command)
func _process(delta: float) -> void:
	super._process(delta)
	hint.text=hint.text.replace(" · N 新世界","").replace(" · F3 调试","").replace(" · F4 环境","").replace(" · F7 资源分布","")
	if stopping:return
	move_clock+=delta;sync_clock+=delta
	if move_clock>=.1 and not moving_request:move_clock=0;move_server()
	if sync_clock>=.4 and not requesting:sync_clock=0;sync_server()
	item_service.sleep.render()
func move_server() -> void:
	moving_request=true;sequence+=1
	var response: Dictionary=await Network.call_api("move",{"seq":sequence,"dx":0,"dy":0,"inputs":player.pending_inputs.duplicate(true),"pose":{"action":player.action,"clock":player.action_clock,"facing":player.facing}})
	moving_request=false
	if stopping:return
	if response.get("ok",false):player.acknowledge(response.character,int(response.input_ack))
	else:item_ui.show_notice(response.get("error","移动同步失败"))
func sync_server() -> void:
	if requesting or stopping:return
	requesting=true
	var command: Dictionary=commands[0].duplicate(true) if not commands.is_empty() else {}
	command.selected=item_service.inventory.selected
	command.station=item_service.craft_station_id
	var response: Dictionary=await Network.call_api("game_snapshot" if commands.is_empty() else "game_command",command)
	if stopping:requesting=false;return
	if response.get("ok",false):
		if command.has("request_id"):commands.pop_front()
		apply_snapshot(response.snapshot)
		for event in response.get("events",[]):
			match event.kind:
				"notice":item_service.notice.emit(str(event.text))
				"obtained":item_service.item_obtained.emit(str(event.id),int(event.count))
				"sound":AudioFX.play_sfx(str(event.key),Vector2(event.at.x,event.at.y) if not event.at.is_empty() else Vector2.INF)
	elif command.has("request_id"):
		last_error=str(response.get("error","操作同步失败"))
		# Keep the same ID after transport failure; never retry a rejected command.
		if not str(response.get("error","")).begins_with("服务器暂时不可用") and not str(response.get("error","")).begins_with("无法连接服务器"):commands.pop_front()
		item_ui.show_notice(response.get("error","操作同步失败"))
	var poll: Dictionary=await Network.call_api("poll",{"cursor":Network.cursor})
	requesting=false
	if stopping:return
	if not poll.get("ok",false):
		var error:=str(poll.get("error","连接中断"))
		item_ui.show_notice(error)
		if error.contains("会话已过期") or error.contains("账号已禁用"):
			Network.token="";close_world.call_deferred()
		return
	if poll.get("ok",false):
		Network.cursor=int(poll.cursor)
		var present: Dictionary={}
		for row in poll.players:
			if row.player_id==Network.profile.player_id:continue
			present[row.player_id]=true
			if not actors.has(row.player_id):
				var actor=preload("res://scripts/network_actor.gd").new();actor.generator=generator;actor.stream=stream;actor.position=Vector2(row.x,row.y);actor.input_blocked=true;object_root.add_child(actor);actor.camera.enabled=false;actors[row.player_id]=actor
				var label:=Label.new();label.name="Nickname";label.position=Vector2(-70,-105);label.size.x=140;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;actor.add_child(label)
			actors[row.player_id].get_node("Nickname").text=row.nickname;actors[row.player_id].receive(row)
		for id in actors.keys():
			if not present.has(id):actors[id].queue_free();actors.erase(id)
		for message in poll.messages:show_chat(message)
func apply_snapshot(source: Dictionary) -> void:
	applying=true
	var snapshot:=source.duplicate(true)
	snapshot.player_position={"x":player.position.x,"y":player.position.y}
	var selected: int=item_service.inventory.selected
	var previous_hits: Dictionary=stream.tree_hits.duplicate()
	var previous_job: Dictionary=item_service.craft_job.duplicate(true)
	item_service.writable=true;item_service.load_state("",false,snapshot)
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
	if typing or return_dialog.visible:player.input_blocked=true
	for node in object_root.get_children():
		var prop_id:=str(node.get_meta("prop_id",""))
		if node.is_in_group("trees") and snapshot.harvested.has(prop_id):
			node.remove_from_group("trees");node.fade_out();stream.call_deferred("refresh_grounding",node.position);continue
		if node.is_in_group("trees") and int(snapshot.tree_hits.get(prop_id,0))>int(previous_hits.get(prop_id,0)):node.hit()
		if node.has_method("fade_out") and node.get("state") in ["fading","removed"]:continue
		for key in ["prop_id","ore_id","drop_id"]:
			var id:=str(node.get_meta(key,""))
			if not id.is_empty() and (snapshot.harvested.has(id) or snapshot.consumed.has(id)):
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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_N,KEY_F3,KEY_F4,KEY_F6,KEY_F7]:get_viewport().set_input_as_handled();return
	super._unhandled_input(event)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE and typing:
		entry.hide();entry.release_focus();typing=false;item_ui.update_input_block();get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_N,KEY_F3,KEY_F4,KEY_F6,KEY_F7] and not get_viewport().gui_get_focus_owner() is LineEdit:get_viewport().set_input_as_handled();return
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
func confirm_return() -> void:
	player.input_blocked=true
	return_dialog.popup_centered(Vector2i(420,160))
func close_world() -> void:
	if stopping:return
	stopping=true;player.input_blocked=true
	while requesting or moving_request:await get_tree().process_frame
	await Network.call_api("leave_lobby",{})
	returned.emit();queue_free()
func network_close() -> void:await close_world()
func _exit_tree() -> void:
	if Engine.has_meta("network_game_controller") and Engine.get_meta("network_game_controller")==self:Engine.remove_meta("network_game_controller")
