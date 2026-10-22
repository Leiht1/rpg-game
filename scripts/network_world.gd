extends Node2D
signal returned
var session_data:Dictionary={}
var generator:WildGenerator
var stream:WildStream
var actors:Dictionary={}
var objects:=Node2D.new()
var hud:=CanvasLayer.new()
var screen:=Control.new()
var chat:=VBoxContainer.new()
var entry:=LineEdit.new()
var notice:=Label.new()
var poll_clock:=0.0
var move_clock:=0.0
var polling:=false
var moving_request:=false
var typing:=false
var stopping:=false
var sequence:=0
var failures:=0
var inventory_label:=Label.new()
var bag_panel:=PanelContainer.new()
var bag_rows:=VBoxContainer.new()
var object_panel:=PanelContainer.new()
var object_rows:=VBoxContainer.new()
var nearby_objects:Array=[]
var current_object:Dictionary={}
var own_character:Dictionary={}
var hotbar_buttons:Array[Button]=[]
var selected_hotbar:=0
var db:=preload("res://scripts/item_database.gd").new()
func _ready()->void:
	var world:Dictionary=session_data.world
	generator=preload("res://scripts/world_generator.gd").new(int(world.seed),int(world.map_cells))
	objects.y_sort_enabled=true
	stream=preload("res://scripts/chunk_stream.gd").new();add_child(stream);add_child(objects);stream.configure(generator,objects)
	add_child(hud);hud.layer=20;hud.add_child(screen);screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);screen.mouse_filter=Control.MOUSE_FILTER_IGNORE;screen.theme=preload("res://scripts/item_ui_style.gd").theme()
	var game_menu=preload("res://scripts/world_menu.gd").new()
	game_menu.world_provider=func():return self
	game_menu.return_action=close_world
	add_child(game_menu)
	notice.text=world.name;notice.position=Vector2(20,16);screen.add_child(notice)
	screen.add_child(chat);chat.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);chat.offset_left=-340;chat.offset_right=340;chat.offset_top=-310;chat.offset_bottom=-114;chat.mouse_filter=Control.MOUSE_FILTER_IGNORE
	screen.add_child(entry);entry.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);entry.offset_left=-340;entry.offset_right=340;entry.offset_top=-112;entry.offset_bottom=-74;entry.max_length=120;entry.hide();entry.text_submitted.connect(send_chat)
	var bar:=HBoxContainer.new();screen.add_child(bar);bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);bar.offset_left=-340;bar.offset_right=164;bar.offset_top=-72;bar.offset_bottom=-14
	for i in 8:
		var slot:=Button.new();slot.custom_minimum_size=Vector2(60,58);bar.add_child(slot);hotbar_buttons.append(slot)
		slot.focus_mode=Control.FOCUS_NONE
		slot.pressed.connect(select_hotbar.bind(i))
	inventory_label.position=Vector2(20,55);screen.add_child(inventory_label)
	preload("res://scripts/character_catalog.gd").enable_candidate(db)
	for pair in [[bag_panel,bag_rows,Vector2(790,100)],[object_panel,object_rows,Vector2(320,100)]]:
		screen.add_child(pair[0]);pair[0].position=pair[2];pair[0].add_theme_stylebox_override("panel",preload("res://scripts/item_ui_style.gd").frame(18));pair[0].add_child(pair[1]);pair[0].hide()
	own_character=session_data.character
	render_hotbar()
	apply_character({"player_id":Network.profile.player_id,"nickname":Network.profile.nickname,"avatar":Network.profile.avatar}.merged(session_data.character,true))
	var own:Node=actors[Network.profile.player_id]
	own.own=true;own.camera.enabled=true
	stream.update_target(own.position)
	for item in ["move_left","move_right","move_up","move_down","run"]:
		if not InputMap.has_action(item):InputMap.add_action(item)
	var keys:={"move_left":KEY_A,"move_right":KEY_D,"move_up":KEY_W,"move_down":KEY_S,"run":KEY_SHIFT}
	for key in keys:
		var ev:=InputEventKey.new();ev.physical_keycode=keys[key]
		if not InputMap.action_has_event(key,ev):InputMap.action_add_event(key,ev)
func apply_character(row:Dictionary)->void:
	var id:String=row.player_id
	if not actors.has(id):
		var actor=preload("res://scripts/network_actor.gd").new();actor.generator=generator;actor.stream=stream;actor.position=Vector2(row.x,row.y);actor.target_position=actor.position;actor.input_blocked=true;objects.add_child(actor);actor.camera.enabled=false;actors[id]=actor
		var name_label:=Label.new();name_label.name="Nickname";name_label.position=Vector2(-70,-105);name_label.size.x=140;name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;actor.add_child(name_label)
	actors[id].get_node("Nickname").text=row.nickname
	# Poll snapshots can predate the independent movement response. They update
	# appearance/equipment but must not rewind this client's own movement.
	actors[id].receive(row,not actors[id].own)
func _process(delta:float)->void:
	if stopping:return
	poll_clock+=delta;move_clock+=delta
	if poll_clock>=.2 and not polling:poll_clock=0;poll_server()
	if move_clock>=.1 and not moving_request:move_clock=0;move_server()
	if actors.has(Network.profile.player_id):stream.update_target(actors[Network.profile.player_id].position)
func poll_server()->void:
	polling=true
	var response:Dictionary=await Network.call_api("poll",{"cursor":Network.cursor})
	polling=false
	if stopping:return
	if not response.get("ok",false):
		failures+=1;notice.text=response.get("error","连接中断")
		if str(notice.text).contains("会话已过期") or str(notice.text).contains("账号已禁用"):
			Network.token="";stopping=true;returned.emit();queue_free()
		return
	failures=0;Network.cursor=int(response.cursor)
	var present:Dictionary={}
	for row in response.players:present[row.player_id]=true;apply_character(row)
	for id in actors.keys():
		if not present.has(id) and id!=Network.profile.player_id:actors[id].queue_free();actors.erase(id)
	for message in response.messages:show_message(message)
	nearby_objects=response.get("objects",[])
	for node in get_tree().get_nodes_in_group("network_object_visual"):
		node.queue_free()
	for item in nearby_objects:
		var sprite:=Sprite2D.new();sprite.add_to_group("network_object_visual")
		var path:String="res://assets/buildings/v2/wood_chest.png" if item.kind=="storage" else str(db.item(str(item.contents[0].get("item_id","wood"))).get("world_visual","")) if not item.contents.is_empty() and not item.contents[0].is_empty() else ""
		if ResourceLoader.exists(path):sprite.texture=load(path)
		if sprite.texture:
			sprite.scale=Vector2.ONE*(60.0 if item.kind=="storage" else 30.0)/sprite.texture.get_width();sprite.position=Vector2(item.x,item.y);objects.add_child(sprite)
		else:sprite.queue_free()
func move_server()->void:
	moving_request=true;sequence+=1
	var direction:=Vector2.ZERO if get_meta("world_menu_open",false) or typing or bag_panel.visible or object_panel.visible or failures>0 else Input.get_vector("move_left","move_right","move_up","move_down")
	var response:Dictionary=await Network.call_api("move",{"seq":sequence,"dx":direction.x,"dy":direction.y,"run":not typing and Input.is_action_pressed("run"),"inputs":actors[Network.profile.player_id].pending_inputs.duplicate(true)})
	moving_request=false
	if stopping:return
	if response.get("ok",false) and actors.has(Network.profile.player_id):
		if int(response.get("movement_revision",0))<2:
			notice.text="请更新独立服务器后再测试移动";failures+=1
		else:actors[Network.profile.player_id].acknowledge(response.character,int(response.input_ack))
	else:
		failures+=1;notice.text=response.get("error","移动同步失败")
func movement_direction()->Vector2:
	return Vector2.ZERO if get_meta("world_menu_open",false) or stopping or typing or bag_panel.visible or object_panel.visible or failures>0 else Input.get_vector("move_left","move_right","move_up","move_down")
func select_hotbar(index:int)->void:
	selected_hotbar=index;render_hotbar()
	if own_character.slots[index].is_empty():object_panel.hide();return
	select_stack(index)
func render_hotbar()->void:
	for i in hotbar_buttons.size():
		var button:Button=hotbar_buttons[i]
		button.add_theme_stylebox_override("normal",preload("res://scripts/item_ui_style.gd").slot(i==selected_hotbar,false))
		button.add_theme_stylebox_override("hover",preload("res://scripts/item_ui_style.gd").slot(i==selected_hotbar,true))
		var stack:Dictionary=own_character.slots[i]
		button.text=str(i+1);button.icon=null;button.tooltip_text=""
		if not stack.is_empty():
			var item:Dictionary=db.item(stack.item_id)
			button.text=str(stack.count);button.tooltip_text=str(item.name)
			if ResourceLoader.exists(item.icon):button.icon=load(item.icon);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",32)
func show_message(message:Dictionary)->void:
	while chat.get_child_count()>=5:
		var old:=chat.get_child(0);chat.remove_child(old);old.queue_free()
	var label:=Label.new();label.text=message.nickname+"："+message.text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size.x=660;label.add_theme_color_override("font_color",Color.WHITE);label.add_theme_color_override("font_shadow_color",Color(0,0,0,.7));label.add_theme_constant_override("shadow_offset_x",1);label.add_theme_constant_override("shadow_offset_y",1);chat.add_child(label)
	var tween:=label.create_tween();tween.tween_interval(4);tween.tween_property(label,"modulate:a",0.,1);tween.tween_callback(label.queue_free)
func _input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if typing:
		if event.physical_keycode==KEY_ESCAPE:finish_typing();get_viewport().set_input_as_handled()
		return
	if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_8:
		select_hotbar(event.physical_keycode-KEY_1);get_viewport().set_input_as_handled();return
	if event.physical_keycode==KEY_Y:
		typing=true;entry.clear();entry.show();entry.grab_focus();get_viewport().set_input_as_handled()
	elif event.physical_keycode==KEY_B:
		if bag_panel.visible:bag_panel.hide()
		else:open_bag()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode==KEY_E:
		interact_object();get_viewport().set_input_as_handled()
	elif event.physical_keycode==KEY_ESCAPE:
		bag_panel.hide();object_panel.hide();get_viewport().set_input_as_handled()
func request_id()->String:return Crypto.new().generate_random_bytes(16).hex_encode()
func ui_button(parent:Node,text:String,callback:Callable)->void:
	var button:=Button.new();button.text=text;button.custom_minimum_size.y=34;parent.add_child(button);button.pressed.connect(callback)
func clear_rows(rows:Node)->void:
	for child in rows.get_children():rows.remove_child(child);child.queue_free()
func open_bag()->void:
	var response:Dictionary=await Network.call_api("bag",{})
	if response.get("ok",false):own_character=response.character;render_hotbar();render_bag();bag_panel.show()
	else:notice.text=response.get("error","读取失败")
func render_bag()->void:
	clear_rows(bag_rows)
	var title:=Label.new();title.text="背包";bag_rows.add_child(title)
	var grid:=GridContainer.new();grid.columns=4;bag_rows.add_child(grid)
	for i in range(8,40):
		var stack:Dictionary=own_character.slots[i]
		var button:=Button.new();button.custom_minimum_size=Vector2(64,48);grid.add_child(button)
		if stack.is_empty():continue
		button.text=str(stack.count);button.tooltip_text=str(db.item(stack.item_id).name)
		var path:String=db.item(stack.item_id).icon
		if ResourceLoader.exists(path):button.icon=load(path);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",28)
		button.pressed.connect(func():select_stack(i))
	for key in own_character.equipment:
		var stack:Dictionary=own_character.equipment[key]
		if stack.is_empty():continue
		var slot_defs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment_slots.json"))
		for i in slot_defs.size():
			if slot_defs[i].id==key:ui_button(bag_rows,"卸下 "+str(db.item(stack.item_id).name),func():inventory_action("unequip",40+i))
	ui_button(bag_rows,"关闭",func():bag_panel.hide())
func select_stack(index:int)->void:
	var stack:Dictionary=own_character.slots[index]
	if stack.is_empty():return
	clear_rows(object_rows);object_panel.show()
	var label:=Label.new();label.text=str(db.item(stack.item_id).name);object_rows.add_child(label)
	if db.item(stack.item_id).get("equippable",false):ui_button(object_rows,"装备",func():inventory_action("equip",index))
	ui_button(object_rows,"放到快捷栏",func():
		var slot:=0
		while slot<8 and not own_character.slots[slot].is_empty():slot+=1
		if slot<8:inventory_action("move",index,{"to":slot})
		else:notice.text="快捷栏已满")
	var amount:=SpinBox.new();amount.min_value=1;amount.max_value=int(stack.count);amount.value=1;object_rows.add_child(amount)
	ui_button(object_rows,"丢到地面",func():inventory_action("drop",index,{"amount":int(amount.value)}))
	if not current_object.is_empty() and current_object.kind=="storage" and not str(current_object.id).begins_with("legacy:"):
		ui_button(object_rows,"存入箱子",func():transfer(current_object,index,int(amount.value),false))
	ui_button(object_rows,"取消",func():object_panel.hide())
func inventory_action(action:String,index:int,extra:Dictionary={})->void:
	var response:Dictionary=await Network.call_api("inventory",{"request_id":request_id(),"action":action,"index":index}.merged(extra,true))
	if response.get("ok",false):own_character=response.character;render_hotbar();render_bag();object_panel.hide()
	else:notice.text=response.get("error","操作失败")
func interact_object()->void:
	if not actors.has(Network.profile.player_id):return
	var p:Vector2=actors[Network.profile.player_id].position
	var nearest:Dictionary={};var distance:=120.0
	for item in nearby_objects:
		var d:=p.distance_to(Vector2(item.x,item.y))
		if d<distance:nearest=item;distance=d
	if nearest.is_empty():return
	current_object=nearest;clear_rows(object_rows);object_panel.show()
	var title:=Label.new();title.text="遗产" if str(nearest.id).begins_with("legacy:") else "储物箱" if nearest.kind=="storage" else "地面物品";object_rows.add_child(title)
	for i in nearest.contents.size():
		var stack:Dictionary=nearest.contents[i]
		if stack.is_empty():continue
		ui_button(object_rows,"%s ×%d"%[db.item(stack.item_id).name,int(stack.count)],func():transfer(nearest,i,1,true))
	if nearest.kind=="storage":ui_button(object_rows,"背包",open_bag)
	ui_button(object_rows,"关闭",func():object_panel.hide())
func transfer(object:Dictionary,index:int,amount:int,taking:bool)->void:
	var response:Dictionary=await Network.call_api("pickup" if object.kind=="drops" else "storage",{"request_id":request_id(),"object_id":object.id,"index":index,"amount":amount,"taking":taking})
	if response.get("ok",false):own_character=response.character;render_hotbar();object_panel.hide();if_bag_refresh()
	else:notice.text=response.get("error","操作失败")
func if_bag_refresh()->void:
	if bag_panel.visible:render_bag()
func finish_typing()->void:
	typing=false;entry.clear();entry.release_focus();entry.hide()
func send_chat(text:String)->void:
	finish_typing()
	var response:Dictionary=await Network.call_api("chat",{"text":text})
	if not stopping and not response.get("ok",false):notice.text=response.get("error","发送失败")
func close_world()->void:
	if stopping:return
	stopping=true;typing=true
	await Network.call_api("leave_lobby",{})
	returned.emit();queue_free()
func network_close()->void:
	stopping=true
