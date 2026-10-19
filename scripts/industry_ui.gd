extends Control
const IndustrySkin=preload("res://scripts/item_ui_style.gd")
var service: Node
var current := ""
var panel := PanelContainer.new()
var column := VBoxContainer.new()
var title := Label.new()
var status := Label.new()
var fuel := OptionButton.new()
var amount := SpinBox.new()
var add := Button.new()
var fuel_line := HBoxContainer.new()
var rows := VBoxContainer.new()
var recipe_choice := OptionButton.new()
var queue_status := Label.new()
var start := Button.new()
var selection := VBoxContainer.new()
var ingredient_window := PopupPanel.new()
var cook := Button.new()
var ingredient_choices: Array=[]
var ingredient_counts: Array=[]
var selected_slot := -1
var slot_buttons: Array=[]
var bars: Array=[]
var claims: Array=[]
var fuel_ids: Array=[]
var recipe_ids: Array=[]
var ingredient_ids: Array=[]
var refresh_clock := 0.0

func configure(owner_service: Node) -> void:
	service=owner_service;theme=IndustrySkin.theme();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_IGNORE;z_index=15
	add_child(panel);panel.add_theme_stylebox_override("panel",IndustrySkin.frame(14));panel.custom_minimum_size=Vector2(470,0);panel.add_child(column);column.add_theme_constant_override("separation",8)
	var header := HBoxContainer.new();column.add_child(header);title.size_flags_horizontal=SIZE_EXPAND_FILL;header.add_child(title)
	var close := Button.new();close.text="关闭";header.add_child(close);close.pressed.connect(close_panel)
	column.add_child(status);column.add_child(fuel_line);fuel.custom_minimum_size=Vector2(190,32);fuel_line.add_child(fuel)
	amount.min_value=1;amount.max_value=99;amount.custom_minimum_size=Vector2(80,32);fuel_line.add_child(amount);add.text="添加";fuel_line.add_child(add)
	add.pressed.connect(func():
		if fuel.selected>=0 and fuel.selected<fuel_ids.size():command("feed" if service.builds.states[current].kind=="feed_trough" else "fuel",0,fuel_ids[fuel.selected],int(amount.value)))
	column.add_child(rows);rows.add_theme_constant_override("separation",8)
	for i in 4:
		var line := HBoxContainer.new();rows.add_child(line)
		var icon := Button.new();icon.text="+";icon.custom_minimum_size=Vector2(58,54);icon.expand_icon=true;icon.add_theme_constant_override("icon_max_width",40);line.add_child(icon);slot_buttons.append(icon)
		icon.pressed.connect(select_slot.bind(i))
		var bar := ProgressBar.new();bar.custom_minimum_size=Vector2(250,18);bar.size_flags_horizontal=SIZE_EXPAND_FILL;bar.size_flags_vertical=SIZE_SHRINK_CENTER;bar.max_value=1;bar.show_percentage=false;line.add_child(bar);bars.append(bar)
		var claim := Button.new();claim.text="领取";claim.custom_minimum_size=Vector2(70,38);line.add_child(claim);claims.append(claim);claim.pressed.connect(func():command("claim",i))
	column.add_child(queue_status);column.add_child(recipe_choice);recipe_choice.custom_minimum_size.y=34
	add_child(ingredient_window);ingredient_window.theme=theme
	ingredient_window.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var ingredient_frame := PanelContainer.new();ingredient_frame.add_theme_stylebox_override("panel",IndustrySkin.frame(14));ingredient_window.add_child(ingredient_frame)
	var ingredient_column := VBoxContainer.new();ingredient_column.add_theme_constant_override("separation",8);ingredient_frame.add_child(ingredient_column)
	var ingredient_title := Label.new();ingredient_title.text="添加材料";ingredient_column.add_child(ingredient_title)
	ingredient_column.add_child(selection)
	for i in 4:
		var line := HBoxContainer.new();selection.add_child(line)
		var choice := OptionButton.new();choice.custom_minimum_size=Vector2(300,32);line.add_child(choice);ingredient_choices.append(choice)
		var count := SpinBox.new();count.min_value=1;count.max_value=99;line.add_child(count);ingredient_counts.append(count)
	var ingredient_buttons := HBoxContainer.new();ingredient_column.add_child(ingredient_buttons)
	cook.text="开始烹饪";cook.size_flags_horizontal=SIZE_EXPAND_FILL;ingredient_buttons.add_child(cook);cook.pressed.connect(submit)
	var cancel := Button.new();cancel.text="取消";ingredient_buttons.add_child(cancel);cancel.pressed.connect(func():ingredient_window.hide())
	ingredient_window.popup_hide.connect(func():selected_slot=-1)
	start.text="加入加工队列";column.add_child(start);start.pressed.connect(submit)
	service.inventory.changed.connect(refresh_choices)
	hide()

func open(id: String) -> void:
	var reason: String=service.industry.check(id)
	if not reason.is_empty():service.notice.emit(reason);return
	service.world.item_ui.close_panels();service.world.camp_ui.close_panel()
	current=id;selected_slot=-1;show();service.world.player.cancel_action();refresh_choices();refresh();service.world.item_ui.update_input_block()

func close_panel() -> void:
	ingredient_window.hide();hide();current="";service.world.item_ui.update_input_block()

func command(action: String, index: int=0, key: String="", count: int=1, materials: Dictionary={}) -> String:
	var reason: String=service.industry.act(current,action,index,key,count,materials)
	if not reason.is_empty():service.notice.emit(reason)
	refresh_choices();refresh()
	return reason

func select_slot(i: int) -> void:
	var row: Dictionary=service.builds.states[current]
	if row.kind!="copper_oven" or not row.machine.jobs[i].is_empty():return
	selected_slot=i;refresh_choices();refresh()
	for count in ingredient_counts:count.value=1
	ingredient_window.reset_size();ingredient_window.popup_centered()

func submit() -> void:
	var row: Dictionary=service.builds.states[current]
	if row.kind=="copper_oven":
		var materials := {}
		for i in 4:
			var index: int=ingredient_choices[i].selected
			if index<=0:continue
			var id: String=ingredient_ids[index-1]
			if materials.has(id):service.notice.emit("请勿重复选择食材");return
			materials[id]=int(ingredient_counts[i].value)
		if command("start",selected_slot,"",1,materials).is_empty():ingredient_window.hide()
	elif recipe_choice.selected>=0 and recipe_choice.selected<recipe_ids.size():command("start",0,recipe_ids[recipe_choice.selected])

func refresh_choices() -> void:
	if not visible or not service.builds.states.has(current):return
	var row: Dictionary=service.builds.states[current]
	fuel_ids=[];fuel.clear();recipe_ids=[];recipe_choice.clear();ingredient_ids=[]
	var seen := {}
	for v in service.inventory.slots:
		if v.is_empty() or seen.has(v.item_id):continue
		seen[v.item_id]=true
		if (row.kind=="feed_trough" and service.industry.feed_allowed(v.item_id)) or (row.kind!="feed_trough" and service.industry.rules.fuel_items.has(v.item_id)):
			fuel_ids.append(v.item_id);fuel.add_item(service.database.item(v.item_id).name+" ×"+str(service.inventory.count_item(v.item_id)))
	for id in seen:
		if service.database.item(id).get("food_kind","")=="raw":ingredient_ids.append(id)
	for choice in ingredient_choices:
		choice.clear();choice.add_item("—")
		for id in ingredient_ids:choice.add_item(service.database.item(id).name+" ×"+str(service.inventory.count_item(id)))
	for id in service.industry.rules.recipes:
		var r: Dictionary=service.industry.rules.recipes[id]
		if r.station!=row.kind:continue
		recipe_ids.append(id)
		var line: String=service.database.item(r.output).name+" ×"+str(r.count)+"  "
		for key in r.materials:line+=service.database.item(key).name+"×"+str(r.materials[key])+" "
		recipe_choice.add_item(line)
	add.disabled=fuel_ids.is_empty()

func refresh() -> void:
	if not visible or not service.builds.states.has(current):return
	var row: Dictionary=service.builds.states[current];var m: Dictionary=row.machine
	title.text=service.builds.definitions[row.kind].name
	status.text="燃料 %d"%int(m.fuel) if row.kind in ["stone_furnace","copper_oven"] else ""
	if row.kind=="feed_trough":
		var labels: Array=[]
		for id in m.feed:labels.append(service.database.item(id).name+" ×"+str(m.feed[id]))
		status.text="  ".join(labels) if not labels.is_empty() else "0"
	fuel_line.visible=row.kind in ["stone_furnace","copper_oven","feed_trough"]
	rows.visible=row.kind!="feed_trough"
	for i in 4:
		slot_buttons[i].get_parent().visible=i<m.jobs.size()
		if i>=m.jobs.size():continue
		var j: Dictionary=m.jobs[i]
		slot_buttons[i].text="+" if j.is_empty() else "";slot_buttons[i].icon=null if j.is_empty() else service.texture(j.output.item_id,"icon")
		slot_buttons[i].disabled=not j.is_empty() or row.kind!="copper_oven"
		bars[i].value=0 if j.is_empty() else float(j.elapsed)/float(service.industry.recipe(row.kind,j.recipe).seconds)
		claims[i].disabled=j.is_empty() or not j.ready
	queue_status.visible=row.kind in ["stone_furnace","metal_workbench"];queue_status.text="队列 ×"+str(m.queue.size())
	recipe_choice.visible=row.kind in ["stone_furnace","metal_workbench"]
	start.visible=recipe_choice.visible;start.text="加入加工队列"
	panel.reset_size();panel.position=(get_viewport_rect().size-panel.size)*.5

func _process(dt: float) -> void:
	if not visible:return
	if not service.builds.states.has(current) or service.body.sleep_active() or service.world.player.position.distance_to(Vector2(service.builds.states[current].x,service.builds.states[current].y))>100:close_panel();return
	refresh_clock+=dt
	if refresh_clock>.2:refresh_clock=0;refresh()

func _input(event: InputEvent) -> void:
	if ingredient_window.visible:return
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE,KEY_E]:close_panel();get_viewport().set_input_as_handled()
