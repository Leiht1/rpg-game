extends Node
signal appearance_selected(appearance: Dictionary)
var selection_only := false
const Catalog=preload("res://scripts/character_catalog.gd")
const CreationSkin=preload("res://scripts/item_ui_style.gd")
const World=preload("res://scripts/character_preview_world.gd")
var save_path := "user://character-preview-v1/state.json"
var look: Dictionary=Catalog.default_look()
var canvas := CanvasLayer.new()
var screen := Control.new()
var panel := PanelContainer.new()
var status := Label.new()
var enter := Button.new()
var hair := OptionButton.new()
var gender := OptionButton.new()
var skin_buttons: Array[Button]=[]
var preview: Node2D
var renderer=preload("res://scripts/character_look.gd").new()
var preview_facing := "front"
var view: SubViewport
var world: Node2D
var busy := false
var protected_save := false
var hair_ids: Array[String]=[]
func _ready() -> void:
	get_tree().auto_accept_quit=false
	add_child(canvas);canvas.layer=30;canvas.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);screen.theme=CreationSkin.theme()
	var bg:=ColorRect.new();bg.color=Color("728965");screen.add_child(bg);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(panel);panel.add_theme_stylebox_override("panel",CreationSkin.frame(24));panel.size=Vector2(670,420);panel.position=Vector2(305,150)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",14);panel.add_child(box)
	var title:=Label.new();title.text="创建人物";title.add_theme_font_size_override("font_size",24);box.add_child(title)
	var body:=HBoxContainer.new();body.add_theme_constant_override("separation",24);box.add_child(body)
	var preview_box:=VBoxContainer.new();body.add_child(preview_box)
	var viewport_container:=SubViewportContainer.new();viewport_container.custom_minimum_size=Vector2(250,230);preview_box.add_child(viewport_container)
	view=SubViewport.new();view.size=Vector2i(250,230);view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport_container.add_child(view)
	preview=load("res://assets/hero/cartoon/character.tscn").instantiate();preview.position=Vector2(3,-4);preview.scale=Vector2.ONE*1.9;view.add_child(preview)
	preview.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	preview.get_node("AnimationPlayer").callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var turns:=HBoxContainer.new();preview_box.add_child(turns)
	for row in [["正面","front"],["背面","back"],["侧面","right"],["左侧","left"]]:
		var button:=Button.new();button.text=row[0];turns.add_child(button);button.pressed.connect(func():preview_facing=row[1];refresh_preview())
	var choices:=VBoxContainer.new();choices.add_theme_constant_override("separation",12);choices.custom_minimum_size.x=300;body.add_child(choices)
	for row in [["性别",gender],["发型",hair]]:
		var label:=Label.new();label.text=row[0];choices.add_child(label);choices.add_child(row[1])
	gender.add_item("男性");gender.add_item("女性");gender.item_selected.connect(select_gender)
	for option in [gender,hair]:option.get_popup().theme=screen.theme
	hair.item_selected.connect(func(index):look.hair_id=hair_ids[index];refresh_preview())
	var skin_label:=Label.new();skin_label.text="肤色";choices.add_child(skin_label)
	var tones:=HBoxContainer.new();choices.add_child(tones)
	for id in Catalog.rules().skin:
		var button:=Button.new();button.custom_minimum_size=Vector2(42,36);button.text="";button.tooltip_text=Catalog.rules().skin[id].name
		var style:=StyleBoxFlat.new();style.bg_color=Color(Catalog.rules().skin[id].color);style.set_corner_radius_all(8)
		button.add_theme_stylebox_override("normal",style);button.add_theme_stylebox_override("hover",style);button.add_theme_stylebox_override("pressed",style)
		tones.add_child(button);skin_buttons.append(button);button.pressed.connect(func():look.skin_id=id;refresh_preview())
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.custom_minimum_size.x=600;box.add_child(status)
	enter.text="进入世界";enter.custom_minimum_size.y=42;box.add_child(enter);enter.pressed.connect(begin_creation)
	select_gender(0)
	if not selection_only and FileAccess.file_exists(save_path):
		var value=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if valid_session(value):
			await open_world(value.character_session,false)
		else:
			protected_save=true;enter.disabled=true;status.text="试玩存档无法读取，原文件已保留。可使用独立重置入口备份后重试。"
func select_gender(index: int) -> void:
	look.gender="male" if index==0 else "female";hair.clear();hair_ids.clear()
	for id in Catalog.rules().hair:
		hair.add_item(Catalog.rules().hair[id].name);hair_ids.append(id)
	var selected:=hair_ids.find(str(look.hair_id))
	if selected<0:selected=0
	hair.select(selected);look.hair_id=hair_ids[selected];refresh_preview()
func refresh_preview() -> void:
	if preview==null:return
	var direction: String="side" if preview_facing in ["left","right"] else preview_facing
	var animation: AnimationPlayer=preview.get_node("AnimationPlayer");animation.play(direction+"_breathe");animation.seek(0,true)
	var visual: Node2D=preview.get_node("Visual");visual.scale=Vector2(-1,1) if preview_facing=="left" else Vector2.ONE;visual.position.x=128 if preview_facing=="left" else 0
	renderer.apply(preview,look,null,preview_facing)
	preview.reset_physics_interpolation()
	for i in skin_buttons.size():skin_buttons[i].text="✓" if Catalog.rules().skin.keys()[i]==look.skin_id else ""
func valid_session(value: Variant) -> bool:
	if not value is Dictionary or not value.get("character_session") is Dictionary:return false
	if not value.get("equipment") is Dictionary or not value.equipment.get("outfit",{}) is Dictionary:return false
	var session: Dictionary=value.character_session
	if session.get("version")!=1 or not session.get("characters") is Dictionary:return false
	if not session.get("seed") is float and not session.get("seed") is int:return false
	if not is_finite(float(session.seed)) or session.seed!=floor(session.seed) or session.seed<=0 or session.seed>=2147483647:return false
	if session.get("seed")!=value.get("seed") or session.get("map_cells")!=value.get("map_cells") or (session.get("map_cells")!=1024 and session.get("map_cells")!=1536):return false
	if not session.get("active_character_id") is String or not session.get("world_id") is String:return false
	if session.active_character_id.is_empty() or session.world_id.is_empty():return false
	if value.get("player_state_owner")!=session.active_character_id:return false
	var active=session.characters.get(session.active_character_id)
	if not active is Dictionary or active.get("world_id")!=session.world_id:return false
	return active.get("test_outfit_granted")==true and Catalog.valid(active.get("appearance")) and active.get("outfit_id","") in ["","modern_outfit"] and active.get("outfit_id","")==value.equipment.get("outfit",{}).get("item_id","")
func begin_creation() -> void:
	if busy or protected_save:return
	if selection_only:
		busy=true;enter.disabled=true;appearance_selected.emit(look.duplicate(true));return
	var id:=str(ResourceUID.create_id());var world_id:=str(ResourceUID.create_id())
	var seed_value:=int(Time.get_unix_time_from_system()*1000+Time.get_ticks_usec())%2147483646+1
	var record:={"version":1,"active_character_id":id,"world_id":world_id,"seed":seed_value,"map_cells":1536,"characters":{id:{"world_id":world_id,"appearance":look.duplicate(true),"test_outfit_granted":false,"outfit_id":""}}}
	await open_world(record,true)
func open_world(record: Dictionary, creating: bool) -> bool:
	busy=true;enter.disabled=true;status.text="正在铺展原野…"
	await get_tree().process_frame
	world=World.new();world.record=record.duplicate(true);world.creating=creating;world.isolated_path=save_path
	add_child(world)
	world.player.input_blocked=true
	var service: Node=world.item_service
	if not service.writable:return fail("试玩存档数据不完整，原文件已保留。",not creating)
	if creating:
		if not world.safe_entry():return fail("未找到安全出生点，请重试。",false)
		# Legacy marker records completed initialization; no starter outfit grant.
		world.record.characters[record.active_character_id].test_outfit_granted=true
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()))
		world.persistent_world=true
		if not service.save_state():return fail("初次保存失败，选择已保留，可重试。",false)
	while not world.started:await get_tree().process_frame
	world.player.input_blocked=false;screen.hide();busy=false
	return true
func fail(message: String, protect: bool) -> bool:
	world.persistent_world=false;world.item_service.writable=false
	world.queue_free();world=null
	busy=false;protected_save=protect;status.text=message;enter.disabled=protect
	return false
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(world) and not world.item_service.save_state():
			# Keep the running world available for retry; never silently lose changes.
			world.item_ui.show_notice("保存失败，请稍后再次关闭重试")
			return
		get_tree().quit()
