extends Control
var service: Node
var current := ""
var panel := Panel.new()
var title := Label.new()
var status := Label.new()
var progress := ProgressBar.new()
var choices := VBoxContainer.new()
var fingerprint := ""
var timer := 0.0
var scroll := ScrollContainer.new()
var close := Button.new()
var fuel_window := PopupPanel.new()
var fuel_cards := GridContainer.new()
var fuel_amount := SpinBox.new()
var fuel_confirm := Button.new()
var selected_fuel := ""
var stored := VBoxContainer.new()

func configure(items: Node) -> void:
	service=items;theme=preload("res://scripts/item_ui_style.gd").theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_STOP;z_index=15
	add_child(panel);panel.size=Vector2(600,520);panel.add_theme_stylebox_override("panel",preload("res://scripts/item_ui_style.gd").frame(18))
	title.position=Vector2(28,20);title.add_theme_font_size_override("font_size",23);panel.add_child(title)
	close.text="关闭";close.set_meta("audio_window_close",true);close.position=Vector2(500,20);close.size=Vector2(72,36);close.pressed.connect(close_panel);panel.add_child(close)
	status.position=Vector2(28,65);status.size=Vector2(540,48);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(status)
	progress.position=Vector2(28,118);progress.size=Vector2(544,16);progress.max_value=1;progress.show_percentage=false;panel.add_child(progress);preload("res://scripts/item_ui_style.gd").progress_style(progress)
	scroll.position=Vector2(28,148);scroll.size=Vector2(544,342);panel.add_child(scroll)
	choices.size_flags_horizontal=SIZE_EXPAND_FILL;choices.add_theme_constant_override("separation",8);scroll.add_child(choices)
	stored.position=Vector2(18,56);stored.size.x=384;stored.add_theme_constant_override("separation",4);panel.add_child(stored)
	add_child(fuel_window);fuel_window.theme=theme;fuel_window.transparent=true;fuel_window.transparent_bg=true;fuel_window.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var frame := PanelContainer.new();frame.add_theme_stylebox_override("panel",preload("res://scripts/item_ui_style.gd").frame(18));fuel_window.add_child(frame)
	var content := VBoxContainer.new();content.add_theme_constant_override("separation",8);frame.add_child(content)
	var heading := Label.new();heading.text="投入燃料";content.add_child(heading)
	fuel_cards.columns=2;content.add_child(fuel_cards)
	var line := HBoxContainer.new();content.add_child(line);var caption := Label.new();caption.text="数量";line.add_child(caption)
	fuel_amount.min_value=1;fuel_amount.max_value=99;fuel_amount.step=1;fuel_amount.rounded=true;fuel_amount.custom_minimum_size=Vector2(100,32);line.add_child(fuel_amount)
	var actions := HBoxContainer.new();content.add_child(actions);fuel_confirm.text="确认投入";actions.add_child(fuel_confirm);fuel_confirm.pressed.connect(deposit_fuel)
	var cancel := Button.new();cancel.text="取消";actions.add_child(cancel);cancel.pressed.connect(func():fuel_window.hide())
	hide()

func open_fuel_window() -> void:
	selected_fuel="";fuel_amount.value=1
	for child in fuel_cards.get_children():fuel_cards.remove_child(child);child.queue_free()
	for id in service.industry.rules.fuel_items:
		var card := Button.new();card.text=service.database.item(id).name+" ×%d"%service.inventory.count_item(id)
		card.icon=service.texture(id,"icon");card.expand_icon=true;card.add_theme_constant_override("icon_max_width",32);card.custom_minimum_size=Vector2(190,52);card.toggle_mode=true
		card.set_meta("fuel_id",id);card.pressed.connect(func():
			selected_fuel="" if selected_fuel==id else str(id)
			for other in fuel_cards.get_children():other.set_pressed_no_signal(other.get_meta("fuel_id")==selected_fuel)
		);fuel_cards.add_child(card)
	fuel_window.reset_size();fuel_window.popup_centered()
	# A fading-out popup is still visible; explicitly reopen its input/animation state.
	var fade := get_node_or_null("/root/UIFade")
	if fade!=null:fade.window_open(fuel_window)

func deposit_fuel() -> void:
	fuel_amount.apply()
	if selected_fuel.is_empty():return
	var reason: String=service.expansion.act(current,"deposit",-1,{},selected_fuel,int(fuel_amount.value))
	if reason.is_empty():fuel_window.hide()
	else:service.notice.emit(reason)
	fingerprint="";refresh()

func layout_for(kind: String) -> void:
	var compact := kind in ["compost_bin","advanced_smokehouse","fuel_supply_box"]
	panel.size=Vector2(420,232 if kind=="compost_bin" else 220 if kind=="fuel_supply_box" else 144) if compact else Vector2(600,520)
	title.position=Vector2(18,14) if compact else Vector2(28,20)
	close.position=Vector2(panel.size.x-90,12 if compact else 20)
	status.position=Vector2(18,58) if compact else Vector2(28,65)
	status.size=Vector2(panel.size.x-36,24) if compact else Vector2(540,48)
	progress.position=Vector2(18,88) if compact else Vector2(28,118)
	progress.size=Vector2(panel.size.x-36,10) if compact else Vector2(544,16)
	scroll.position=Vector2(18,108) if compact else Vector2(28,148)
	scroll.size=Vector2(panel.size.x-36,panel.size.y-126) if compact else Vector2(544,342)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	if kind=="advanced_smokehouse":
		progress.position.y=58;scroll.position.y=78;scroll.size.y=panel.size.y-96
	if kind=="fuel_supply_box":scroll.position.y=panel.size.y-68;scroll.size.y=50
	scroll.scroll_vertical=0

func open(id: String) -> bool:
	var reason: String=service.expansion.check(id)
	if not reason.is_empty():service.notice.emit(reason);return false
	service.world.item_ui.close_panels();service.world.camp_ui.close_panel();service.industry_ui.close_panel()
	current=id;layout_for(str(service.builds.states[id].kind));fingerprint="";show();service.world.player.cancel_action();refresh();service.world.item_ui.update_input_block();return true

func close_panel() -> void:
	fuel_window.hide();hide();current="";service.world.item_ui.update_input_block()

func command(action: String,index: int=-1,expected: Dictionary={},key: String="",count: int=1) -> void:
	var reason: String=service.expansion.act(current,action,index,expected,key,count)
	if not reason.is_empty():service.notice.emit(reason)
	fingerprint="";refresh()

func add_choice(text_value: String,icon_id: String,callback: Callable) -> void:
	var button := Button.new();button.text=text_value;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.custom_minimum_size=Vector2(0,48);button.clip_text=true;button.size_flags_horizontal=SIZE_EXPAND_FILL;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.icon=service.texture(icon_id,"icon") if not icon_id.is_empty() else null;button.expand_icon=true;button.add_theme_constant_override("icon_max_width",36);button.pressed.connect(callback);choices.add_child(button)

func cost_text(cost: Dictionary) -> String:
	var text: Array[String]=[]
	for id in cost:text.append(service.database.item(id).name+" ×%d"%int(cost[id]))
	return "、".join(text)

func refresh() -> void:
	if not visible or not service.builds.states.has(current):return
	var row: Dictionary=service.builds.states[current]
	title.text=service.builds.definitions[row.kind].name
	status.visible=row.kind not in ["advanced_smokehouse","fuel_supply_box"];stored.visible=row.kind=="fuel_supply_box"
	var job: Dictionary=row.get("expansion",{}).get("job",{})
	progress.visible=not job.is_empty()
	if not job.is_empty():progress.value=float(job.minutes)/float(service.expansion.rules.processes[row.kind].minutes)
	status.text="选择磨损工具进行维修。" if row.kind=="precision_repair_bench" else "只向附近熔炉和烤箱补给燃料，需手动开火。" if row.kind=="fuel_supply_box" else "原料 ×3 → 肥料 ×1" if row.kind=="compost_bin" else "烤鱼 ×1、木材 ×1 → 熏制烤鱼 ×1" if row.kind=="advanced_smokehouse" else "肥料 ×1，本季作物生长速度提高 25%。"
	if not job.is_empty():status.text="成品可领取" if job.ready else "正在发酵" if row.kind=="compost_bin" else "正在熏制"
	var stable_slots: Array=service.inventory.slots.duplicate(true)
	for v in stable_slots:
		if v.has("spoilage"):v.spoilage=1 if preload("res://scripts/food_freshness.gd").rotten(v) else 0
	var next := JSON.stringify([row,stable_slots,service.inventory.equipment])
	# Progress ages every frame; choices only depend on ready state, not elapsed time or spoilage fractions.
	var compact := next
	if not job.is_empty():compact=JSON.stringify([row.kind,job.ready,preload("res://scripts/food_freshness.gd").rotten(job.output),stable_slots,service.inventory.equipment])
	if compact==fingerprint:return
	fingerprint=compact
	for child in choices.get_children():choices.remove_child(child);child.queue_free()
	match row.kind:
		"precision_repair_bench":
			var seen := {}
			for i in 43:
				var value: Dictionary=service.inventory.get_slot(i)
				var cost: Dictionary=service.expansion.repair_cost(value)
				if cost.is_empty() or seen.has(value.get("instance_id","")):continue
				seen[value.instance_id]=true
				var maximum: int=int(service.database.item(value.item_id).durability)
				if int(value.durability)>=maximum:continue
				add_choice("%s  %d/%d → %d\n%s"%[service.database.item(value.item_id).name,int(value.durability),maximum,maximum,cost_text(cost)],value.item_id,command.bind("repair",i,value.duplicate(true)))
		"fuel_supply_box":
			for child in stored.get_children():stored.remove_child(child);child.queue_free()
			var total := 0
			for count in row.expansion.fuel_items.values():total+=int(count)
			var caption := Label.new();caption.text="已投入材料总量：%d / %d"%[total,int(service.expansion.rules.supply_capacity)];stored.add_child(caption)
			var materials := GridContainer.new();materials.columns=2;materials.add_theme_constant_override("h_separation",20);stored.add_child(materials)
			for key in row.expansion.fuel_items:
				var line := HBoxContainer.new();materials.add_child(line)
				var icon := TextureRect.new();icon.texture=service.texture(key,"icon");icon.custom_minimum_size=Vector2(24,24);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;line.add_child(icon)
				var label := Label.new();label.text=service.database.item(key).name+" ×%d"%int(row.expansion.fuel_items[key]);line.add_child(label)
			add_choice("投入材料","",open_fuel_window)
		"compost_bin", "advanced_smokehouse":
			if not job.is_empty():
				if job.ready:
					add_choice("领取 "+service.stack_name(job.output),job.output.item_id,command.bind("claim"))
					choices.get_child(choices.get_child_count()-1).icon=service.stack_texture(job.output,"icon")
			elif row.kind=="advanced_smokehouse":add_choice("开始熏制：烤鱼 ×1、木材 ×1","smoked_fish",command.bind("process"))
			else:
				for i in 40:
					var value: Dictionary=service.inventory.slots[i]
					if service.expansion.compost_allowed(value) and int(value.count)>=3:
						add_choice("投入 %s ×3   持有 %d"%[service.stack_name(value),int(value.count)],value.item_id,command.bind("process",i,value.duplicate(true)))
						choices.get_child(choices.get_child_count()-1).icon=service.stack_texture(value,"icon")
		"tilled_soil":add_choice("施肥：肥料 ×1","compost_fertilizer",command.bind("fertilize"))
	if choices.get_child_count()==0:
		var label := Label.new();label.text="暂无可用物品" if job.is_empty() else "加工中";choices.add_child(label)

func handle_input(event: InputEvent) -> bool:
	if not visible:return false
	if event is InputEventKey:
		if fuel_window.visible and (event.physical_keycode in [KEY_BACKSPACE,KEY_DELETE,KEY_LEFT,KEY_RIGHT,KEY_HOME,KEY_END,KEY_ENTER,KEY_KP_ENTER,KEY_TAB] or (event.physical_keycode>=KEY_0 and event.physical_keycode<=KEY_9) or (event.ctrl_pressed and event.physical_keycode==KEY_A)):return false
		if event.pressed and not event.echo and event.physical_keycode in [KEY_E,KEY_ESCAPE]:
			if fuel_window.visible:fuel_window.hide()
			else:close_panel()
		return true
	return false

func _process(delta: float) -> void:
	if not visible:return
	fuel_confirm.disabled=selected_fuel.is_empty() or service.inventory.count_item(selected_fuel)<int(fuel_amount.value)
	if not service.expansion.check(current).is_empty():close_panel();return
	var factor := minf(1,(get_viewport_rect().size.y-24)/panel.size.y);panel.scale=Vector2.ONE*factor;panel.position=(get_viewport_rect().size-panel.size*factor)*.5
	timer+=delta
	if timer>.4:timer=0;refresh()
