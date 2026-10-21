extends SceneTree
var fixture:Dictionary={}
var app:Node
var network:Node
var checks:=0
func verify(value:bool,message:String)->void:
	checks+=1
	if not value:push_error("FAIL "+message);quit(1)
func _initialize()->void:run.call_deferred()
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):fixture=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--fixture=")))
	network=root.get_node("Network")
	app=load("res://scenes/launcher.tscn").instantiate();root.add_child(app)
	await process_frame
	app.fields.username.text=fixture.username;app.fields.password.text=fixture.password
	# Exercise the actual displayed login button with pointer events.
	var login_button:Button=find_button(app.root,"登录")
	verify(login_button!=null,"login button exists")
	await process_frame
	click(login_button)
	for i in 300:
		if not network.token.is_empty():break
		await create_timer(.03).timeout
	if network.token.is_empty():
		print("LOGIN_FAILURE ",app.status.text)
		root.get_texture().get_image().save_png(fixture.output+"-failure.png")
		verify(false,"TLS login");return
	await create_timer(.2).timeout
	verify(find_button(app.root,"单机模式")!=null and find_button(app.root,"联机模式")!=null,"main mode buttons")
	verify(app.background.texture!=null,"candidate background loaded")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(fixture.output+"-menu.png")
	app.profile();await create_timer(.5).timeout
	verify(find_button(app.root,"修改密码")!=null,"profile")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(fixture.output+"-profile.png")
	app.lobby();await create_timer(.5).timeout
	await app.resume_online()
	if app.creation!=null:
		var creation:Node=app.creation
		for gender in 2:
			creation.select_gender(gender)
			verify(creation.hair_ids.size()==4,"four hair options per gender")
		creation.gender.selected=1
		creation.hair.selected=3;creation.hair.item_selected.emit(3)
		for skin in creation.skin_buttons:skin.pressed.emit()
		verify(creation.look.skin_id=="skin_6","six skin options update actual preview")
		await create_timer(.25).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(fixture.output+"-creation.png")
		click(creation.enter)
		for i in 300:
			if app.active_world!=null:break
			await create_timer(.03).timeout
	verify(app.active_world!=null,"world entry")
	var online:Node=app.active_world
	for i in 200:
		if online.actors.size()>=2:break
		await create_timer(.1).timeout
	verify(online.actors.size()>=2,"two independent clients visible")
	await online.open_bag()
	verify(online.own_character.slots.size()==40,"original inventory slots")
	var outfit_index:=-1
	for i in 40:
		if online.own_character.slots[i].get("item_id")=="modern_outfit":outfit_index=i
	if outfit_index>=0:await online.inventory_action("equip",outfit_index)
	await create_timer(.7).timeout
	verify(not online.own_character.equipment.get("outfit",{}).is_empty(),"original equipment operation")
	online.bag_panel.hide()
	var pickup:Dictionary=await network.call_api("pickup",{"request_id":online.request_id(),"object_id":"race-drop","index":0,"amount":1})
	if not pickup.get("ok",false):print("PICKUP_REJECTION ",pickup.get("error",""))
	verify(pickup.get("ok",false) or pickup.get("error","").contains("失败"),"shared pickup race resolved by server")
	var storage:Dictionary=await network.call_api("storage",{"request_id":online.request_id(),"object_id":"race-box","index":0,"amount":1,"taking":true})
	verify(storage.get("ok",false) or storage.get("error","").contains("失败"),"shared storage race resolved by server")
	var y:=InputEventKey.new();y.physical_keycode=KEY_Y;y.pressed=true;Input.parse_input_event(y);await process_frame
	verify(online.typing and online.entry.visible,"Y chat entry")
	online.entry.text=fixture.chat
	var enter:=InputEventKey.new();enter.physical_keycode=KEY_ENTER;enter.keycode=KEY_ENTER;enter.pressed=true;Input.parse_input_event(enter);await create_timer(.6).timeout
	verify(not online.typing,"Enter exits chat mode")
	var input_y:=InputEventKey.new();input_y.physical_keycode=KEY_Y;input_y.pressed=true;Input.parse_input_event(input_y);await process_frame
	var esc:=InputEventKey.new();esc.physical_keycode=KEY_ESCAPE;esc.pressed=true;Input.parse_input_event(esc);await process_frame
	verify(not online.typing,"Esc cancels chat")
	var direction_key:=KEY_A if fixture.username=="native1" else KEY_D
	var key:=InputEventKey.new();key.physical_keycode=direction_key;key.pressed=true;Input.parse_input_event(key)
	var previous_x:float=online.actors[network.profile.player_id].position.x
	await create_timer(1).timeout
	key=InputEventKey.new();key.physical_keycode=direction_key;key.pressed=false;Input.parse_input_event(key)
	await create_timer(2).timeout
	verify(absf(online.actors[network.profile.player_id].position.x-previous_x)>20,"server-authoritative movement")
	verify(online.chat.get_child_count()<=5,"at most five chat messages")
	root.get_texture().get_image().save_png(fixture.output+"-online.png")
	print("NETWORK_NATIVE_FPS ",Engine.get_frames_per_second())
	await create_timer(6).timeout
	verify(online.chat.get_child_count()==0,"chat expires")
	await online.close_world()
	print("NETWORK_NATIVE_CHECKS ",checks," PASS")
	quit()
func find_button(node:Node,text:String)->Button:
	if node is Button and node.text==text:return node
	for child in node.get_children():
		var found:=find_button(child,text)
		if found:return found
	return null
func click(button:Button)->void:
	var point:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;Input.parse_input_event(motion)
	var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.position=point;down.pressed=true;Input.parse_input_event(down)
	var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_LEFT;up.position=point;up.pressed=false;Input.parse_input_event(up)
