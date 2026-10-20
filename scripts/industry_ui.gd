extends Control
const IndustrySkin=preload("res://scripts/item_ui_style.gd")
var service: Node
var current := ""
var panel := Panel.new()
var column := VBoxContainer.new()
var title := Label.new()
var status := Label.new()
var feed_summary := HFlowContainer.new()
var fuel_bar := ProgressBar.new()
var fuel_section := VBoxContainer.new()
var fuel_cards := GridContainer.new()
var fuel_buttons: Dictionary={}
var selected_fuel := ""
var amount := SpinBox.new()
var add := Button.new()
var fuel_window := PopupPanel.new()
var fuel_confirm := Button.new()
var separator := HSeparator.new()
var switches := HBoxContainer.new()
var ignite := Button.new()
var extinguish := Button.new()
var rows := VBoxContainer.new()
var slot_buttons: Array=[]
var bars: Array=[]
var ore_cards := HBoxContainer.new()
var recipe_buttons: Dictionary={}
var selected_recipe := ""
var start := Button.new()
var queue_button := Button.new()
var completed_button := Button.new()
var claim_all := Button.new()
var ingredient_window := PopupPanel.new()
var ingredient_choices: Array=[]
var ingredient_counts: Array=[]
var ingredient_ids: Array=[]
var selected_slot := -1
var cook := Button.new()
var tray := PopupPanel.new()
var tray_rows := VBoxContainer.new()
var tray_title := Label.new()
var tray_mode := ""
var tray_fingerprint := ""
var refresh_clock := 0.0
var last_area := Vector2.ZERO
func button(text_value: String, callback: Callable) -> Button:
	var value := Button.new();value.text=text_value;value.pressed.connect(callback);return value
func clear(node: Node) -> void:
	for child in node.get_children():node.remove_child(child);child.queue_free()
func popup_frame(popup: PopupPanel) -> VBoxContainer:
	add_child(popup);popup.theme=theme;popup.transparent=true;popup.transparent_bg=true;popup.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var frame := PanelContainer.new();frame.add_theme_stylebox_override("panel",IndustrySkin.frame(18));popup.add_child(frame)
	var content := VBoxContainer.new();content.add_theme_constant_override("separation",8);frame.add_child(content);return content
func configure(owner_service: Node) -> void:
	service=owner_service;theme=IndustrySkin.theme();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_IGNORE;z_index=15
	add_child(panel);panel.add_theme_stylebox_override("panel",IndustrySkin.frame(18));panel.add_child(column);column.position=Vector2(20,18);column.add_theme_constant_override("separation",8)
	var header := HBoxContainer.new();column.add_child(header);title.size_flags_horizontal=SIZE_EXPAND_FILL;header.add_child(title);header.add_child(button("关闭",close_panel))
	column.add_child(status);column.add_child(feed_summary);column.add_child(fuel_section)
	var fuel_line := HBoxContainer.new();fuel_section.add_child(fuel_line);var caption := Label.new();caption.text="燃料";fuel_line.add_child(caption)
	fuel_bar.max_value=float(service.industry.rules.max_fuel);fuel_bar.show_percentage=false;fuel_bar.size_flags_horizontal=SIZE_EXPAND_FILL;fuel_bar.custom_minimum_size=Vector2(0,18);fuel_line.add_child(fuel_bar)
	fuel_section.add_child(switches)
	var add_line := HBoxContainer.new();fuel_section.add_child(add_line)
	add.text="添加燃料";add_line.add_child(add);add.pressed.connect(open_fuel_window)
	var fuel_content := popup_frame(fuel_window);var fuel_heading := Label.new();fuel_heading.text="选择物品";fuel_content.add_child(fuel_heading)
	fuel_cards.columns=2;fuel_content.add_child(fuel_cards)
	var quantity_line := HBoxContainer.new();fuel_content.add_child(quantity_line);var quantity_label := Label.new();quantity_label.text="数量";quantity_line.add_child(quantity_label)
	amount.min_value=1;amount.max_value=99;amount.step=1;amount.rounded=true;amount.custom_minimum_size=Vector2(100,32);quantity_line.add_child(amount)
	var fuel_actions := HBoxContainer.new();fuel_content.add_child(fuel_actions);fuel_confirm.text="确认添加";fuel_actions.add_child(fuel_confirm);fuel_confirm.pressed.connect(add_fuel);fuel_actions.add_child(button("取消",func():fuel_window.hide()))
	column.add_child(separator)
	ignite.text="开火";extinguish.text="关火";switches.add_child(ignite);switches.add_child(extinguish)
	ignite.pressed.connect(func():command("ignite"));extinguish.pressed.connect(func():command("extinguish"))
	column.add_child(rows);rows.add_theme_constant_override("separation",8)
	for i in 4:
		var line := HBoxContainer.new();rows.add_child(line)
		var icon := button("+",select_slot.bind(i));icon.custom_minimum_size=Vector2(72,54);icon.expand_icon=true;icon.add_theme_constant_override("icon_max_width",56);line.add_child(icon);slot_buttons.append(icon)
		var progress := ProgressBar.new();progress.max_value=1;progress.show_percentage=false;progress.custom_minimum_size=Vector2(380,18);progress.size_flags_horizontal=SIZE_EXPAND_FILL;progress.size_flags_vertical=SIZE_SHRINK_CENTER;line.add_child(progress);bars.append(progress)
		IndustrySkin.progress_style(progress)
	column.add_child(ore_cards);ore_cards.add_theme_constant_override("separation",8)
	start.text="加入加工队列";column.add_child(start);start.pressed.connect(submit)
	var footer := HBoxContainer.new();column.add_child(footer)
	queue_button.text="查看队列";completed_button.text="查看已完成产物";claim_all.text="一键领取"
	for entry in [queue_button,completed_button,claim_all]:footer.add_child(entry)
	queue_button.pressed.connect(show_tray.bind("queue"));completed_button.pressed.connect(show_tray.bind("completed"));claim_all.pressed.connect(func():command("claim_all"))
	var ingredients := popup_frame(ingredient_window);var label := Label.new();label.text="添加材料";ingredients.add_child(label)
	for i in 4:
		var line := HBoxContainer.new();ingredients.add_child(line)
		var choice := OptionButton.new();choice.custom_minimum_size=Vector2(300,32);choice.add_theme_constant_override("icon_max_width",20);line.add_child(choice);ingredient_choices.append(choice)
		var count := SpinBox.new();count.min_value=1;count.max_value=99;count.step=1;count.rounded=true;line.add_child(count);ingredient_counts.append(count)
	var actions := HBoxContainer.new();ingredients.add_child(actions);cook.text="加入加工队列";actions.add_child(cook);cook.pressed.connect(submit);actions.add_child(button("取消",func():ingredient_window.hide()))
	ingredient_window.popup_hide.connect(func():selected_slot=-1)
	var content := popup_frame(tray);content.add_child(tray_title)
	var scroll := ScrollContainer.new();scroll.custom_minimum_size=Vector2(420,260);content.add_child(scroll);tray_rows.size_flags_horizontal=SIZE_EXPAND_FILL;scroll.add_child(tray_rows)
	var tray_actions := HBoxContainer.new();content.add_child(tray_actions);tray_actions.add_child(button("一键领取",func():command("claim_all")));tray_actions.add_child(button("关闭",func():tray.hide()))
	service.inventory.changed.connect(refresh_choices);get_viewport().size_changed.connect(fit_layout);hide()
func fit_layout() -> void:
	var kind := str(service.builds.states.get(current,{}).get("kind",""))
	var dimensions := Vector2(600,600 if kind=="copper_oven" else 540 if kind=="stone_furnace" else 370)
	panel.size=dimensions;column.size=dimensions-Vector2(40,36)
	var area := get_viewport_rect().size;var factor := minf(1.0,minf((area.x-24)/dimensions.x,(area.y-24)/dimensions.y))
	panel.scale=Vector2.ONE*factor;panel.position=(area-dimensions*factor)*.5;last_area=area
func open(id: String) -> void:
	var reason: String=service.industry.check(id)
	if not reason.is_empty():service.notice.emit(reason);return
	service.world.item_ui.close_panels();service.world.camp_ui.close_panel()
	current=id;selected_slot=-1;selected_recipe="";selected_fuel="";tray.hide();ingredient_window.hide();fuel_window.hide()
	# Establish geometry before the first visible frame; state refresh never recenters it.
	fit_layout();show();service.world.player.cancel_action();refresh_choices();refresh();service.world.item_ui.update_input_block()
func close_panel() -> void:
	ingredient_window.hide();tray.hide();fuel_window.hide();hide();current="";service.world.item_ui.update_input_block()
func command(action: String,index: int=0,key: String="",count: int=1,materials: Dictionary={}) -> String:
	var reason: String=service.industry.act(current,action,index,key,count,materials)
	if not reason.is_empty():service.notice.emit(reason)
	refresh_choices();refresh();refresh_tray();return reason
func open_fuel_window() -> void:
	selected_fuel="";amount.value=1;refresh_choices();fuel_window.reset_size();fuel_window.popup_centered()
func add_fuel() -> void:
	amount.apply()
	if selected_fuel.is_empty():return
	if command("feed" if service.builds.states[current].kind=="feed_trough" else "fuel",0,selected_fuel,int(amount.value)).is_empty():fuel_window.hide()
func select_slot(i: int) -> void:
	if service.builds.states[current].kind!="copper_oven":return
	selected_slot=i
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
	elif not selected_recipe.is_empty():command("start",0,selected_recipe)
func choose_fuel(id: String) -> void:
	selected_fuel="" if selected_fuel==id else id;refresh()
func choose_recipe(id: String) -> void:
	selected_recipe="" if selected_recipe==id else id;refresh()
func refresh_choices() -> void:
	if not visible or not service.builds.states.has(current):return
	var row: Dictionary=service.builds.states[current]
	clear(fuel_cards);fuel_buttons.clear();clear(ore_cards);recipe_buttons.clear()
	var fuels: Array=service.industry.rules.fuel_items.keys()
	if row.kind=="feed_trough":
		fuels=[]
		for id in service.database.ids():
			if service.industry.feed_allowed(id):fuels.append(id)
	for id in fuels:
		var card := button(service.database.item(id).name+" ×%d"%service.inventory.count_item(id),choose_fuel.bind(str(id)))
		card.icon=service.texture(id,"icon");card.expand_icon=true;card.add_theme_constant_override("icon_max_width",32);card.custom_minimum_size=Vector2(190,52);card.toggle_mode=true;fuel_cards.add_child(card);fuel_buttons[id]=card
	var previous_ids: Array=ingredient_ids.duplicate()
	ingredient_ids=[]
	for id in service.database.ids():
		if service.database.item(id).get("food_kind","")=="raw" and service.inventory.count_item(id)>0:ingredient_ids.append(id)
	for choice in ingredient_choices:
		var old_id: String=choice.get_meta("selected_id","")
		if choice.selected>0 and choice.selected-1<previous_ids.size():old_id=previous_ids[choice.selected-1]
		choice.clear();choice.add_item("—")
		for id in ingredient_ids:choice.add_item(service.database.item(id).name+" ×%d"%service.inventory.count_item(id))
		choice.select(ingredient_ids.find(old_id)+1 if old_id in ingredient_ids else 0)
	if row.kind=="stone_furnace":
		for id in service.industry.rules.recipes:
			var r: Dictionary=service.industry.rules.recipes[id]
			if r.station!="stone_furnace":continue
			var mineral: String=r.materials.keys()[0]
			var card := button(service.database.item(mineral).name+" ×%d"%int(r.materials[mineral])+"\n持有 %d"%service.inventory.count_item(mineral),choose_recipe.bind(str(id)))
			card.icon=service.texture(mineral,"icon");card.expand_icon=true;card.alignment=HORIZONTAL_ALIGNMENT_LEFT;card.add_theme_constant_override("icon_max_width",36);card.custom_minimum_size=Vector2(180,66);card.toggle_mode=true;ore_cards.add_child(card);recipe_buttons[id]=card
	refresh()
func refresh() -> void:
	if not visible or not service.builds.states.has(current):return
	var row: Dictionary=service.builds.states[current];var m: Dictionary=row.machine;var burner: bool=service.industry.burner(row.kind)
	title.text=service.builds.definitions[row.kind].name
	status.text="已开火" if burner and service.industry.burning(row) else "已关火" if burner else ""
	if m.completed.size()>=int(service.industry.rules.completed_limit):status.text+=" · 产物已满"
	if row.kind=="feed_trough":
		status.hide()
	feed_summary.visible=row.kind=="feed_trough"
	clear(feed_summary)
	if row.kind=="feed_trough":
		for id in m.feed:
			var line := HBoxContainer.new();feed_summary.add_child(line)
			var icon := TextureRect.new();icon.texture=service.texture(id,"icon");icon.custom_minimum_size=Vector2(24,24);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;line.add_child(icon)
			var label := Label.new();label.text=service.database.item(id).name+" ×%d"%int(m.feed[id]);line.add_child(label)
		if m.feed.is_empty():
			var label := Label.new();label.text="暂无饲料";feed_summary.add_child(label)
	else:status.show()
	fuel_section.visible=burner or row.kind=="feed_trough";fuel_bar.get_parent().visible=burner;add.text="添加饲料" if row.kind=="feed_trough" else "添加燃料";fuel_bar.value=float(m.fuel)
	IndustrySkin.progress_style(fuel_bar,true,service.industry.burning(row))
	separator.visible=burner;switches.visible=burner;ignite.disabled=m.enabled or float(m.fuel)+float(m.legacy_fuel)<=0;extinguish.disabled=not m.enabled
	for id in fuel_buttons:fuel_buttons[id].set_pressed_no_signal(id==selected_fuel)
	add.disabled=false
	fuel_confirm.disabled=selected_fuel.is_empty() or service.inventory.count_item(selected_fuel)<int(amount.value)
	rows.visible=row.kind!="feed_trough"
	for i in 4:
		slot_buttons[i].get_parent().visible=i<m.jobs.size()
		if i>=m.jobs.size():continue
		var j: Dictionary=m.jobs[i]
		slot_buttons[i].text="+" if j.is_empty() else "";slot_buttons[i].icon=null if j.is_empty() else service.texture(j.output.item_id,"icon");slot_buttons[i].disabled=row.kind!="copper_oven"
		bars[i].value=0 if j.is_empty() else float(j.elapsed)/float(service.industry.recipe(row.kind,j.recipe).seconds)
	ore_cards.visible=row.kind=="stone_furnace";start.visible=ore_cards.visible;start.disabled=selected_recipe.is_empty()
	for id in recipe_buttons:recipe_buttons[id].set_pressed_no_signal(id==selected_recipe)
	for entry in [queue_button,completed_button,claim_all]:entry.visible=row.kind!="feed_trough"
	queue_button.text="查看队列 (%d)"%(m.queue.size()+m.legacy_queue.size());completed_button.text="已完成产物 (%d)"%m.completed.size();claim_all.disabled=m.completed.is_empty()
	if last_area!=get_viewport_rect().size:fit_layout()
	refresh_tray()
func show_tray(mode: String) -> void:
	tray_mode=mode;tray_fingerprint="";refresh_tray();tray.reset_size();tray.popup_centered()
func refresh_tray() -> void:
	if tray_mode.is_empty() or not service.builds.states.has(current):return
	var m: Dictionary=service.builds.states[current].machine
	var jobs: Array=m.completed if tray_mode=="completed" else m.queue+m.legacy_queue
	var fingerprint := JSON.stringify(jobs)+tray_mode
	if fingerprint==tray_fingerprint:return
	tray_fingerprint=fingerprint;clear(tray_rows);tray_title.text="已完成产物" if tray_mode=="completed" else "加工队列"
	if jobs.is_empty():
		var empty := Label.new();empty.text="暂无";tray_rows.add_child(empty)
	for j in jobs:
		var line := HBoxContainer.new();tray_rows.add_child(line);var image := TextureRect.new();image.texture=service.stack_texture(j.output,"icon");image.custom_minimum_size=Vector2(40,40);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;line.add_child(image)
		var label := Label.new();label.text=service.stack_name(j.output)+" ×%d"%int(j.output.count);line.add_child(label)
func _process(dt: float) -> void:
	if not visible:return
	if not service.builds.states.has(current) or service.body.sleep_active() or service.world.player.position.distance_to(Vector2(service.builds.states[current].x,service.builds.states[current].y))>100:close_panel();return
	refresh_clock+=dt
	if refresh_clock>.2:refresh_clock=0;refresh()
func _input(event: InputEvent) -> void:
	if ingredient_window.visible or tray.visible or fuel_window.visible:return
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE,KEY_E]:close_panel();get_viewport().set_input_as_handled()
