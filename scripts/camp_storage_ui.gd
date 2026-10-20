extends Control
const CampSkin = preload("res://scripts/item_ui_style.gd")
var service: Node
var current := ""
var panel := Panel.new()
var cells: Array=[]
var player_cells: Array=[]
var actions := PopupMenu.new()
var action_index := -1
var action_snapshot: Dictionary={}
var quantity := PopupPanel.new()
var amount := LineEdit.new()
var split_confirm := Button.new()
var legacy_button := Button.new()
var legacy_page := false

func configure(items: Node) -> void:
	service=items;mouse_filter=Control.MOUSE_FILTER_IGNORE;theme=CampSkin.theme()
	panel.size=Vector2(156,184);panel.z_index=8
	panel.add_theme_stylebox_override("panel",CampSkin.section(8));add_child(panel);panel.hide()
	var title := Label.new();title.text="木箱";title.name="ChestTitle";title.position=Vector2(26,12);title.size=Vector2(104,20);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(title)
	var close := Button.new();close.text="×";close.set_meta("audio_window_close",true);close.position=Vector2(128,9);close.size=Vector2(22,24);close.add_theme_stylebox_override("normal",CampSkin.button_style("normal",true));close.add_theme_stylebox_override("hover",CampSkin.button_style("hover",true));close.add_theme_stylebox_override("pressed",CampSkin.button_style("pressed",true));panel.add_child(close);close.pressed.connect(close_panel)
	var chest := GridContainer.new();chest.name="ChestGrid";chest.columns=3;chest.position=Vector2(8,38);chest.add_theme_constant_override("h_separation",4);chest.add_theme_constant_override("v_separation",4);panel.add_child(chest)
	for i in 24:
		var cell := preload("res://scripts/camp_storage_slot.gd").new();cell.owner_ui=self;cell.index=i;chest.add_child(cell);cells.append(cell)
	legacy_button.position=Vector2(8,184);legacy_button.size=Vector2(140,28);legacy_button.text="取回旧箱物品";panel.add_child(legacy_button)
	legacy_button.pressed.connect(func():legacy_page=not legacy_page;refresh())
	service.inventory.changed.connect(refresh)
	add_child(actions);actions.add_item("取出到背包",0);actions.add_item("使用 / 装备",1);actions.add_item("销毁",2)
	actions.id_pressed.connect(func(id: int):
		if not preload("res://scripts/food_freshness.gd").matches(contents(action_index),action_snapshot): report("原物品已变化，请重新选择");return
		if id==0: take(action_index)
		else: report(service.builds.chest_edit(current,action_index,action_snapshot,"use" if id==1 else "destroy")))
	add_child(quantity);quantity.theme=CampSkin.theme()
	quantity.theme.set_stylebox("panel","PopupPanel",StyleBoxEmpty.new())
	var wrap := PanelContainer.new();wrap.add_theme_stylebox_override("panel",CampSkin.frame());quantity.add_child(wrap)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",10);column.custom_minimum_size=Vector2(286,0);wrap.add_child(column)
	var split_title := Label.new();split_title.text="拆分数量（保留原格至少1件）";column.add_child(split_title)
	column.add_child(amount);amount.placeholder_text="输入拆分数量";amount.select_all_on_focus=true
	var buttons := HBoxContainer.new();column.add_child(buttons);split_confirm.text="拆分";buttons.add_child(split_confirm)
	var cancel := Button.new();cancel.text="取消";buttons.add_child(cancel);cancel.pressed.connect(func():quantity.hide())
	amount.text_changed.connect(func(value: String): split_confirm.disabled=not value.is_valid_int() or int(value)<1 or int(value)>=int(action_snapshot.get("count",0)))
	split_confirm.pressed.connect(func():
		if split_confirm.disabled: return
		report(service.builds.chest_edit(current,action_index,action_snapshot,"split",-1,int(amount.text)));quantity.hide())

func open(id: String) -> void:
	if service.body.sleeping: return
	if current==id and panel.visible: close_panel();return
	var reason: String=service.builds.set_chest_open(id,true)
	if not reason.is_empty(): service.notice.emit(reason);return
	service.world.player.cancel_action();current=id;legacy_page=false;panel.show();refresh()
func close_panel() -> void:
	if not current.is_empty() and service.builds.states.has(current):
		var reason: String=service.builds.set_chest_open(current,false)
		if not reason.is_empty(): service.notice.emit(reason);return
	hide_panel()
func hide_panel() -> void:
	actions.hide();quantity.hide();panel.hide();current=""
	service.world.item_ui.update_input_block()
func refresh() -> void:
	if not panel.visible: return
	var overflow := false
	for i in range(9,12) if service.builds.states[current].kind=="wood_chest" else []:
		if not contents(i).is_empty(): overflow=true
	if not overflow: legacy_page=false
	legacy_button.visible=overflow
	legacy_button.text="返回九宫格" if legacy_page else "取回旧箱物品"
	var cap: int=service.builds.storage_capacity(current)
	var cols := 6 if cap==24 else 3
	panel.get_node("ChestGrid").columns=cols
	panel.size.x=16+cols*44+ (cols-1)*4
	panel.get_node("ChestTitle").size.x=panel.size.x-52
	panel.get_child(1).position.x=panel.size.x-28
	panel.get_node("ChestTitle").text=service.builds.definitions[service.builds.states[current].kind].name
	panel.size.y=220 if overflow else 38+int(ceil(float(cap)/cols))*48+2
	for i in cells.size():
		var cell: Control=cells[i]
		cell.index=i+9 if legacy_page else i
		cell.visible=(not legacy_page and i<cap) or (legacy_page and i<3)
		cell.refresh()
func contains_pointer(at: Vector2) -> bool:
	return panel.visible and panel.get_global_rect().has_point(at)
func report(reason: String) -> void:
	if not reason.is_empty(): service.notice.emit(reason)
	refresh()
func take(index: int) -> void:
	for i in range(8,40):
		if service.inventory.slots[i].is_empty():
			report(service.builds.transfer(current,index,i,contents(index),{}));return
	report("背包已满，请先留出空格")
func contents(index: int) -> Dictionary:
	return service.builds.states.get(current,{}).get("contents",[{},{},{},{},{},{},{},{},{},{},{},{}])[index] if index>=0 and index<service.builds.states.get(current,{}).get("contents",[]).size() else {}
func menu(index: int, at: Vector2) -> void:
	if contents(index).is_empty(): return
	action_index=index;action_snapshot=contents(index).duplicate(true)
	var definition: Dictionary=service.database.item(action_snapshot.item_id)
	actions.set_item_disabled(1,not definition.get("equippable",false) and definition.get("use_action","") not in ["eat","unpack"])
	actions.position=Vector2i(at);actions.popup()
func split(index: int) -> void:
	if contents(index).is_empty() or int(contents(index).count)<2: return
	action_index=index;action_snapshot=contents(index).duplicate(true)
	amount.text="1";split_confirm.disabled=false
	quantity.popup_centered(Vector2i(320,170));amount.grab_focus();amount.select_all()
func _process(_dt: float) -> void:
	# Follow the persisted chest, never the player or a reconstructed visual node.
	if not panel.visible:
		for id in service.builds.states:
			var row: Dictionary=service.builds.states[id]
			if service.builds.storage_kind(row.kind) and row.open:
				current=id;panel.show();refresh();break
		return
	if not service.builds.states.has(current) or not service.builds.states[current].open:
		hide_panel();return
	var row: Dictionary=service.builds.states[current]
	var anchor: Vector2=get_viewport().get_canvas_transform()*Vector2(row.x,row.y)
	panel.position=anchor+Vector2(-panel.size.x*.5,-panel.size.y-45)
	panel.position=panel.position.clamp(Vector2(8,8),get_viewport_rect().size-panel.size-Vector2(8,8))
func _input(event: InputEvent) -> void:
	if panel.visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
		close_panel();get_viewport().set_input_as_handled()
