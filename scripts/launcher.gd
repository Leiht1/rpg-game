extends Node
const MenuSkin=preload("res://scripts/item_ui_style.gd")
var layer:=CanvasLayer.new()
var root:=Control.new()
var content:=Control.new()
var status:=Label.new()
var fields:Dictionary={}
var busy:=false
var active_world:Node
var creation:Node
var online_creation:=false
var offline:=false
var background:=TextureRect.new()
var loading_layer:CanvasLayer
var loading_text:Label
func show_loading(message:String)->void:
	if not is_instance_valid(loading_layer):
		loading_layer=CanvasLayer.new();loading_layer.layer=45;add_child(loading_layer)
		var shade:=ColorRect.new();shade.color=Color(0.10,0.16,0.08,0.86);loading_layer.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var center:=CenterContainer.new();loading_layer.add_child(center);center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var frame:=PanelContainer.new();frame.theme=MenuSkin.theme();frame.add_theme_stylebox_override("panel",MenuSkin.frame(24));frame.custom_minimum_size.x=420;center.add_child(frame)
		var box:=VBoxContainer.new();box.add_theme_constant_override("separation",18);frame.add_child(box)
		loading_text=Label.new();loading_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;box.add_child(loading_text)
		var progress:=ProgressBar.new();progress.indeterminate=true;progress.show_percentage=false;progress.custom_minimum_size=Vector2(360,18);box.add_child(progress)
	loading_text.text=message;loading_layer.show()
	# Present feedback before synchronous terrain/scene preparation begins.
	await get_tree().process_frame
	await get_tree().process_frame
func hide_loading()->void:
	if is_instance_valid(loading_layer):loading_layer.hide()
func default_avatar()->Texture2D:
	var image:=Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72"><circle cx="36" cy="36" r="34" fill="#e6e3bc"/><circle cx="36" cy="27" r="12" fill="#657b54"/><path d="M15 60a21 23 0 0 1 42 0" fill="#657b54"/></svg>')
	return ImageTexture.create_from_image(image)
func _ready()->void:
	get_tree().auto_accept_quit=false
	if FileAccess.file_exists("res://prototypes/network-menu-v1/app-icon.png"):
		DisplayServer.set_icon(Image.load_from_file("res://prototypes/network-menu-v1/app-icon.png"))
	add_child(layer);layer.layer=30;layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.theme=MenuSkin.theme()
	var plain:=ColorRect.new();plain.color=Color("90ae77");root.add_child(plain);plain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if FileAccess.file_exists("res://prototypes/network-menu-v1/background.png"):background.texture=ImageTexture.create_from_image(Image.load_from_file("res://prototypes/network-menu-v1/background.png"))
	root.add_child(content);content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	login()
func clear()->void:
	fields.clear()
	if is_instance_valid(status) and not status.is_inside_tree():status.free()
	for child in content.get_children():content.remove_child(child);child.queue_free()
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.custom_minimum_size.x=330
func panel(title:String,width:float=400)->VBoxContainer:
	clear()
	var center:=CenterContainer.new();content.add_child(center);center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame:=PanelContainer.new();frame.add_theme_stylebox_override("panel",MenuSkin.frame(22));frame.custom_minimum_size.x=width;center.add_child(frame)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",10);frame.add_child(box)
	var label:=Label.new();label.text=title;label.add_theme_font_size_override("font_size",26);box.add_child(label)
	box.add_child(status)
	return box
func input(box:Node,key:String,placeholder:String,secret:bool=false)->LineEdit:
	var field:=LineEdit.new();field.placeholder_text=placeholder;field.secret=secret;field.max_length=128;field.keep_editing_on_text_submit=true;field.custom_minimum_size.y=38;box.add_child(field);fields[key]=field;return field
func button(box:Node,text:String,action:Callable)->Button:
	var item:=Button.new();item.text=text;item.custom_minimum_size.y=40;box.add_child(item)
	item.pressed.connect(func():
		if not busy:action.call())
	return item
func send(op:String,data:Dictionary)->Dictionary:
	busy=true;status.text="正在连接…"
	var entering:=op in ["create_world","join_world","resume","character"]
	if entering:await show_loading("正在生成世界，首次创建需要一些时间…" if op=="create_world" else "正在连接世界…")
	var response:Dictionary=await Network.call_api(op,data)
	if entering:hide_loading()
	busy=false
	if is_instance_valid(status):status.text="" if response.get("ok",false) else str(response.get("error","操作失败"))
	return response
func login(activation:bool=false)->void:
	var box:=panel("首次账号激活" if activation else "风栖原野 · 登录")
	if activation:
		input(box,"account","内部账号 ID")
		input(box,"activation","一次性激活凭证",true)
	input(box,"username","登录用户名");input(box,"password","密码",true)
	var memory:=preload("res://scripts/login_memory.gd")
	var saved:Dictionary=memory.read(Network.config)
	fields.username.text=str(saved.get("username",""))
	fields.password.text=str(saved.get("password","")) if not activation else ""
	var remember:=CheckBox.new();remember.text="记住密码";remember.button_pressed=bool(saved.get("remember",false));box.add_child(remember)
	remember.toggled.connect(func(enabled:bool):
		if not enabled:memory.save(Network.config,fields.username.text,"",false))
	button(box,"激活并登录" if activation else "登录",func():
		var data:={}
		for key in fields:data[key]=fields[key].text
		var response:=await send("activate" if activation else "login",data)
		if response.get("ok",false):
			offline=false
			memory.save(Network.config,data.username,data.password,remember.button_pressed)
			# Cache contains display identity only. Never grants online authority.
			var cache:=FileAccess.open(str(Network.config.get("profile_cache","user://local-profile.json")),FileAccess.WRITE)
			if cache:cache.store_string(JSON.stringify({"nickname":Network.profile.nickname,"username":Network.profile.username}));cache.close()
			if Network.profile.nickname.is_empty():nickname(true)
			else:menu())
	button(box,"返回登录" if activation else "首次账号激活",func():login(not activation))
	button(box,"离线单机",func():offline=true;menu())
func nickname(required:bool=false)->void:
	var box:=panel("设置昵称" if required else "修改昵称")
	var field:=input(box,"nickname","昵称")
	field.grab_focus.call_deferred()
	var request:bool=not required and int(Network.profile.get("nickname_uses",0))>=2
	button(box,"提交管理员审核" if request else "保存",func():
		var response:=await send("nickname_request" if request else "nickname",{"nickname":fields.nickname.text})
		if response.get("ok",false):menu() if required else profile())
	if not required:button(box,"返回",profile)
func menu()->void:
	clear();root.show()
	var identity:=Button.new();identity.text="◉  "+("本地玩家" if offline else str(Network.profile.get("nickname","")))
	if offline and FileAccess.file_exists("user://local-profile.json"):
		var cached=JSON.parse_string(FileAccess.get_file_as_string("user://local-profile.json"))
		if cached is Dictionary and cached.get("nickname") is String:identity.text=str(cached.nickname)
	identity.icon=default_avatar();identity.text=identity.text.trim_prefix("◉  ");identity.expand_icon=true;identity.add_theme_constant_override("icon_max_width",36)
	identity.position=Vector2(26,22);identity.custom_minimum_size=Vector2(210,54);content.add_child(identity)
	identity.pressed.connect(func():
		if offline:login()
		else:profile())
	if not offline and not str(Network.profile.get("avatar","")).is_empty():
		var tex:=await Network.avatar(Network.profile.avatar)
		if is_instance_valid(identity):identity.icon=tex;identity.expand_icon=true;identity.add_theme_constant_override("icon_max_width",36)
	var stack:=VBoxContainer.new();content.add_child(stack);stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	stack.offset_left=-230;stack.offset_right=230;stack.offset_top=105;stack.offset_bottom=420;stack.add_theme_constant_override("separation",20)
	if FileAccess.file_exists("res://prototypes/network-menu-v1/logo.png"):
		var logo:=TextureRect.new();logo.texture=ImageTexture.create_from_image(Image.load_from_file("res://prototypes/network-menu-v1/logo.png"));logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;logo.custom_minimum_size=Vector2(460,185);stack.add_child(logo)
	else:
		var title:=Label.new();title.text="风栖原野";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",58);stack.add_child(title)
	button(stack,"单机模式",local_mode)
	button(stack,"联机模式",func():
		if offline:login()
		else:lobby())
func profile()->void:
	var box:=panel("个人资料",440)
	var image:=TextureRect.new();image.texture=default_avatar();image.custom_minimum_size=Vector2(72,72);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;box.add_child(image)
	var label:=Label.new();label.text=str(Network.profile.nickname)+"\n"+str(Network.profile.username);box.add_child(label)
	button(box,"修改头像",upload_avatar);button(box,"修改昵称" if int(Network.profile.nickname_uses)<2 else "申请修改昵称",func():nickname())
	button(box,"修改密码",password)
	if Network.profile.role=="admin":button(box,"服务器管理",admin)
	button(box,"返回主菜单",menu)
	var tex:=await Network.avatar(Network.profile.avatar)
	if is_instance_valid(image) and tex:image.texture=tex
func password()->void:
	var box:=panel("修改密码");input(box,"current","当前密码",true);input(box,"password","新密码（10至128字符）",true)
	button(box,"保存",func():
		var new_password:String=fields.password.text
		var response:=await send("password",{"current":fields.current.text,"password":fields.password.text})
		fields.current.clear();fields.password.clear()
		if response.get("ok",false):
			var memory:=preload("res://scripts/login_memory.gd")
			var saved:Dictionary=memory.read(Network.config)
			memory.save(Network.config,Network.profile.username,new_password,bool(saved.get("remember",false)))
			profile())
	button(box,"返回",profile)
func upload_avatar()->void:
	var dialog:=FileDialog.new();dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.filters=PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; 图片"]);content.add_child(dialog)
	dialog.file_selected.connect(func(path:String):
		var file:=FileAccess.open(path,FileAccess.READ)
		if not file or file.get_length()>512*1024:status.text="头像最大512KB";return
		var response:=await send("avatar",{"image":Marshalls.raw_to_base64(file.get_buffer(file.get_length()))})
		file.close()
		if response.get("ok",false):profile())
	dialog.popup_centered_ratio(.65)
func lobby()->void:
	var box:=panel("在线世界",620)
	var response:=await send("worlds",{})
	if not response.get("ok",false):button(box,"返回",menu);return
	if not Network.profile.world_id.is_empty():
		button(box,"继续所属世界",resume_online)
		button(box,"永久退出当前世界",confirm_leave)
	else:
		input(box,"name","新世界名称")
		button(box,"创建世界",func():
			var result:=await send("create_world",{"name":fields.name.text})
			if result.get("ok",false):resume_online())
		var scroll:=ScrollContainer.new();scroll.custom_minimum_size.y=200;box.add_child(scroll)
		var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
		for w in response.worlds:
			button(list,"%s  · %d 人在线"%[w.name,int(w.online)],func():
				var result:=await send("join_world",{"world_id":w.id})
				if result.get("ok",false):resume_online())
	button(box,"返回主菜单",menu)
func confirm_leave()->void:
	var box:=panel("永久退出世界",450)
	status.text="角色将被删除，随身物品留作遗产。此操作无法撤销。"
	button(box,"确认永久退出",func():
		var response:=await send("permanent_leave",{"confirm":Network.profile.world_id})
		if response.get("ok",false):lobby())
	button(box,"取消",lobby)
func resume_online()->void:
	var response:=await send("resume",{})
	if not response.get("ok",false):return
	if response.character==null:
		online_creation=true;create_character()
	else:
		var result:=await send("character",{})
		if result.get("ok",false):await open_online(result)
func create_character()->void:
	root.hide()
	creation=preload("res://scripts/character_creation.gd").new()
	creation.set("selection_only",true)
	creation.set("save_path","user://singleplayer-characters-v1/state.json")
	creation.connect("appearance_selected",func(look:Dictionary):
		if online_creation:
			await show_loading("正在创建人物并准备世界…")
			var response:Dictionary=await Network.call_api("character",{"appearance":look})
			if response.get("ok",false):creation.queue_free();creation=null;await open_online(response)
			else:hide_loading();creation.set("busy",false);creation.get("enter").disabled=false;creation.get("status").text=response.get("error","进入失败")
		else:
			creation.set("selection_only",false);creation.set("busy",false);creation.begin_creation())
	add_child(creation)
func open_online(response:Dictionary)->void:
	busy=true
	await show_loading("正在铺展原野…")
	if response.get("gameplay_enabled",false):
		var snapshot: Dictionary=await Network.call_api("game_snapshot",{})
		if not snapshot.get("ok",false):hide_loading();busy=false;status.text=snapshot.get("error","世界准备失败");return
		response.initial_snapshot=snapshot.snapshot
	root.hide()
	active_world=load("res://scripts/network_game_world.gd" if response.get("gameplay_enabled",false) else "res://scripts/network_world.gd").new()
	active_world.session_data=response
	active_world.returned.connect(func():
		active_world=null;root.show()
		if Network.token.is_empty():login();status.text="请重新登录"
		else:lobby())
	add_child(active_world)
	active_world.typing=true
	var deadline:=Time.get_ticks_msec()+30000
	while is_instance_valid(active_world) and (not active_world.started or not active_world.stream.viewport_ready(active_world.player.position,get_viewport().get_visible_rect().size)) and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	if is_instance_valid(active_world):
		active_world.typing=false
		if response.get("gameplay_enabled",false):active_world.item_ui.update_input_block()
	await get_tree().process_frame
	await get_tree().process_frame
	hide_loading();busy=false
func local_mode()->void:
	var box:=panel("单机模式")
	button(box,"继续原有本地世界",func():root.hide();active_world=load("res://scenes/world.tscn").instantiate();add_child(active_world);add_local_return())
	button(box,"人物创建 / 继续新角色",func():
		online_creation=false
		if FileAccess.file_exists("user://singleplayer-characters-v1/state.json"):
			root.hide();creation=preload("res://scripts/character_creation.gd").new();creation.save_path="user://singleplayer-characters-v1/state.json";add_child(creation);add_local_return()
		else:create_character();add_local_return())
	button(box,"返回主菜单",menu)
func add_local_return()->void:
	var button_layer:=CanvasLayer.new();button_layer.name="LocalReturn";button_layer.layer=35;add_child(button_layer)
	var back:=Button.new();back.theme=MenuSkin.theme();back.text="返回主菜单";back.custom_minimum_size=Vector2(164,40);back.position=Vector2(1060,12);button_layer.add_child(back)
	back.pressed.connect(func():
		var w:Node=active_world if is_instance_valid(active_world) else creation.get("world") if is_instance_valid(creation) else null
		if w and not w.item_service.save_state():w.item_ui.show_notice("保存失败，请重试");return
		if w:w.persistent_world=false;w.item_service.writable=false
		if is_instance_valid(active_world):remove_child(active_world);active_world.queue_free();active_world=null
		if is_instance_valid(creation):remove_child(creation);creation.queue_free();creation=null
		button_layer.queue_free();menu())
func admin()->void:
	var box:=panel("服务器管理",680)
	var response:=await send("admin_list",{})
	if not response.get("ok",false):button(box,"返回",profile);return
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(620,300);box.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	for a in response.accounts:
		var row:=HBoxContainer.new();list.add_child(row)
		var label:=Label.new();label.text="%s  %s  %s"%[a.id,a.nickname,"启用" if a.enabled else "停用"];row.add_child(label)
		if a.role=="admin":continue
		button(row,"禁用" if a.enabled else "启用",func():await send("admin_enabled",{"account":a.id,"enabled":not a.enabled});admin())
		button(row,"重置凭证",func():show_credential(await send("admin_reset",{"account":a.id})))
		if not a.nickname_request.is_empty():
			button(list,"批准昵称："+a.nickname_request,func():await send("admin_nickname",{"account":a.id});admin())
			button(list,"拒绝昵称申请",func():await send("admin_reject",{"account":a.id});admin())
	for w in response.worlds:
		var row:=HBoxContainer.new();list.add_child(row)
		var label:=Label.new();label.text=w.name+" · "+w.id;row.add_child(label)
		button(row,"删除世界",func():
			var confirm:=panel("删除世界")
			status.text="仅允许删除无人在线的世界；服务器会先备份。"
			button(confirm,"确认删除 "+w.name,func():await send("admin_delete_world",{"world_id":w.id,"confirm":w.id});admin())
			button(confirm,"取消",admin))
	button(box,"创建普通测试账号",func():show_credential(await send("admin_create",{})))
	button(box,"返回个人资料",profile)
func show_credential(response:Dictionary)->void:
	if not response.get("ok",false):return
	var box:=panel("一次性激活凭证",640)
	var text:=TextEdit.new();text.editable=false;text.custom_minimum_size=Vector2(570,100);text.text=str(response.account)+"\n"+str(response.activation)+("\n原用户名："+str(response.username) if not str(response.get("username","")).is_empty() else "");box.add_child(text)
	button(box,"完成",admin)
func _notification(what:int)->void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(active_world) and active_world.has_method("network_close"):await active_world.network_close()
		elif is_instance_valid(active_world) and not active_world.item_service.save_state():active_world.item_ui.show_notice("保存失败，请重试");return
		elif is_instance_valid(creation) and is_instance_valid(creation.get("world")) and not creation.world.item_service.save_state():return
		get_tree().quit()

