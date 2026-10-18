extends Control
## Presentation only. ItemService owns all validation, exchange and persistence.
const ItemSkin = preload("res://scripts/item_ui_style.gd")
var screen: Control
var service: Node
var panel := PanelContainer.new()
var categories := VBoxContainer.new()
var rows := VBoxContainer.new()
var detail := VBoxContainer.new()
var quantity := SpinBox.new()
var status := Label.new()
var once: Button
var batch: Button
var current_category := "全部"
var selected := ""
var recipe_buttons: Dictionary = {}
var category_buttons: Dictionary = {}
var next_submit_ms := 0
var close_button: Button
var mode_title: Label
var mode_hint: Label
var mode_footer: Label
var amount_row: HBoxContainer
var building := false
var book: RefCounted
var progress := ProgressBar.new()

func configure(owner_screen: Control) -> void:
	screen=owner_screen
	service=screen.service
	book=service.craft_book
	name="CraftingUI"
	theme=ItemSkin.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	z_index=10
	add_child(panel)
	panel.add_theme_stylebox_override("panel",ItemSkin.frame(22))
	panel.custom_minimum_size=Vector2(1030,600)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",14)
	panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title := label("野外制作",24)
	mode_title=title
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(button("制作",set_mode.bind(false)))
	header.add_child(button("建造",set_mode.bind(true)))
	header.add_theme_constant_override("separation",20)
	mode_hint=label("徒手制作 · 进度满后完成",13)
	header.add_child(mode_hint)
	var close := button("C / Esc  关闭",screen.close_panels)
	close_button=close
	header.add_child(close)
	var corner_clearance := Control.new()
	corner_clearance.custom_minimum_size.x=28
	header.add_child(corner_clearance)
	body.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.size_flags_vertical=Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",18)
	body.add_child(columns)
	categories.custom_minimum_size.x=124
	categories.add_theme_constant_override("separation",10)
	columns.add_child(categories)
	categories.add_child(label("分类",13))
	for category in book.categories():
		var tab := button(category,choose_category.bind(category))
		tab.toggle_mode=true
		category_buttons[category]=tab
		categories.add_child(tab)
	var middle := VBoxContainer.new()
	middle.custom_minimum_size.x=270
	columns.add_child(middle)
	middle.add_child(label("配方",13))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(scroll)
	rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",8)
	scroll.add_child(rows)
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel",ItemSkin.section(16))
	sheet.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	columns.add_child(sheet)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x=390
	right.add_theme_constant_override("separation",8)
	sheet.add_child(right)
	# Dynamic descriptions/material rows scroll inside a fixed panel; they never resize it.
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name="RecipeDetailScroll"
	detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(detail_scroll)
	detail_scroll.add_child(detail)
	detail.add_theme_constant_override("separation",9)
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	amount_row=HBoxContainer.new()
	right.add_child(amount_row)
	amount_row.add_child(label("制作次数",14))
	quantity.min_value=1; quantity.max_value=99; quantity.step=1; quantity.value=1
	quantity.custom_minimum_size=Vector2(115,34)
	amount_row.add_child(quantity)
	quantity.value_changed.connect(func(_value): refresh())
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size=Vector2(365,44)
	status.add_theme_font_size_override("font_size",13)
	right.add_child(status)
	# Reserve the same space at idle, during crafting and after completion.
	progress.custom_minimum_size=Vector2(0,14)
	progress.max_value=1.0
	progress.show_percentage=false
	progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color=Color("e5dcc6");track.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color=Color("b6bd87");fill.set_corner_radius_all(4)
	progress.add_theme_stylebox_override("background",track)
	progress.add_theme_stylebox_override("fill",fill)
	right.add_child(progress)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",10)
	right.add_child(actions)
	once=button("制作一次",submit.bind(1))
	batch=button("制作所选数量",submit_selected)
	for action in [once,batch]:
		action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		actions.add_child(action)
	var footer_safe := MarginContainer.new()
	footer_safe.add_theme_constant_override("margin_left",40)
	body.add_child(footer_safe)
	mode_footer=label("材料统计包含背包与快捷栏；成品优先补已有堆叠，再放入背包。",12)
	footer_safe.add_child(mode_footer)
	service.inventory.changed.connect(inventory_changed)
	service.craft_progress.connect(update_progress)
	service.craft_finished.connect(finish_craft)
	visibility_changed.connect(func():
		if not visible:
			if is_instance_valid(service): service.cancel_craft()
			progress.value=0)
	resized.connect(fit_panel)
	choose_category("全部")
	fit_panel()
	hide()

func fit_panel() -> void:
	# Only viewport changes call this. Clicks and recipe contents keep this geometry.
	panel.size=Vector2(1030,600)
	var factor := minf(1.0,minf((size.x-32)/panel.size.x,(size.y-40)/panel.size.y))
	panel.scale=Vector2.ONE*maxf(.35,factor)
	panel.position=(size-panel.size*panel.scale)*.5

func label(text_value: String, font_size: int = 14) -> Label:
	var node := Label.new()
	node.text=text_value
	node.add_theme_font_size_override("font_size",font_size)
	return node

func button(text_value: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text=text_value
	node.custom_minimum_size.y=36
	node.add_theme_constant_override("outline_size",0)
	node.focus_mode=Control.FOCUS_NONE
	node.pressed.connect(callback)
	return node

func image(id: String, dimension: int) -> TextureRect:
	var node := TextureRect.new()
	node.texture=service.texture(id,"icon")
	node.custom_minimum_size=Vector2(dimension,dimension)
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return node

func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func choose_category(category: String) -> void:
	if not service.craft_job.is_empty(): return
	current_category=category
	clear(rows)
	recipe_buttons.clear()
	for key in category_buttons: category_buttons[key].set_pressed_no_signal(key==category)
	var available: Array=book.available(category,not service.craft_station_id.is_empty() and not building)
	if available.is_empty(): selected=""
	elif not available.any(func(row): return row.recipe_id==selected): selected=available[0].recipe_id
	for row in available:
		var definition: Dictionary=service.database.item(row.output_id)
		var entry := button("",select_recipe.bind(str(row.recipe_id)))
		entry.toggle_mode=true
		entry.custom_minimum_size=Vector2(258,66)
		entry.icon=service.texture(row.output_id,"icon")
		entry.expand_icon=true
		entry.add_theme_constant_override("icon_max_width",36)
		entry.alignment=HORIZONTAL_ALIGNMENT_LEFT
		for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
			entry.add_theme_stylebox_override(state,ItemSkin.recipe_style(state))
		entry.text=definition.name+" ×"+str(int(row.output_count))+"\n"+str(row.category)
		entry.tooltip_text=""
		rows.add_child(entry)
		recipe_buttons[row.recipe_id]=entry
	refresh()

func select_recipe(id: String) -> void:
	if not service.craft_job.is_empty(): return
	selected=id
	refresh()

func inventory_changed() -> void:
	if visible: refresh()

func refresh() -> void:
	if service==null: return
	var making: bool=not service.craft_job.is_empty()
	if quantity.editable==making: quantity.editable=not making
	for tab in category_buttons.values(): tab.disabled=making
	clear(detail)
	var row: Dictionary=book.recipe(selected)
	if row.is_empty():
		status.text="暂无可用配方"
		once.disabled=true;batch.disabled=true
		return
	for id in recipe_buttons:
		var entry: Button=recipe_buttons[id]
		entry.set_pressed_no_signal(id==selected)
		entry.disabled=making
		# Insufficient materials are explained on the right; keep every card light/readable.
		entry.modulate=Color.WHITE
		var recipe: Dictionary=book.recipe(id)
		entry.text=service.database.item(recipe.output_id).name+" ×"+str(int(recipe.output_count))+"\n"+str(recipe.category)+(" · 已选" if id==selected else "")
	var definition: Dictionary=service.database.item(row.output_id)
	var heading := HBoxContainer.new()
	heading.add_child(image(row.output_id,48))
	heading.add_child(label(definition.name,21))
	detail.add_child(heading)
	var description := label(row.description,13)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x=365
	detail.add_child(description)
	var times := 1 if building else int(quantity.value)
	detail.add_child(label("直接放置到世界 · 成功放置后扣材料" if building else "产出  %s × %d（每次 %d）"%[definition.name,int(row.output_count)*times,int(row.output_count)],14))
	detail.add_child(HSeparator.new())
	var materials_header := HBoxContainer.new()
	var material_caption := label("材料",13)
	material_caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	materials_header.add_child(material_caption)
	materials_header.add_child(label("拥有 / 需要",13))
	detail.add_child(materials_header)
	for id in row.materials:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation",8)
		line.add_child(image(str(id),26))
		var name_label := label(service.database.item(str(id)).name,14)
		name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		var have: int=service.inventory.count_item(str(id))
		var need: int=int(row.materials[id])*times
		var count_label := label("%d / %d"%[have,need],14)
		count_label.add_theme_color_override("font_color",Color("627642") if have>=need else Color("a44832"))
		line.add_child(count_label)
		detail.add_child(line)
	var single_reason: String=service.camps.build_check(selected) if building else service.craft_check(selected,1)
	var reason: String=service.camps.build_check(selected) if building else service.craft_check(selected,times)
	once.disabled=not single_reason.is_empty()
	batch.disabled=not reason.is_empty()
	status.text=reason if not reason.is_empty() else ("材料充足 · 可进入摆放预览" if building else "材料与空间充足 · 可制作 %d 次"%times)
	if building and reason.is_empty() and service.builds.definitions.get(row.output_id,{}).has("replaces"):
		status.text="可进入摆放预览 · 替换墙段只补材料差额"
	status.add_theme_color_override("font_color",Color("a44832") if not reason.is_empty() else Color("627642"))
	if making:
		once.disabled=true;batch.disabled=true
		status.text="正在制作 · %s × %d"%[definition.name,int(row.output_count)*int(service.craft_job.batches)]
		status.add_theme_color_override("font_color",Color("627642"))

func submit_selected() -> void:
	# Apply any SpinBox text edit before reading its numeric value.
	if quantity.get_line_edit().has_focus(): quantity.apply()
	submit(int(quantity.value))

func submit(times: int) -> void:
	if building:
		screen.world.camp_ui.begin_build(selected)
		return
	if not service.craft_job.is_empty(): return
	if Time.get_ticks_msec()<next_submit_ms: return
	next_submit_ms=Time.get_ticks_msec()+180
	var reason: String=service.start_craft(selected,times)
	refresh()
	if not reason.is_empty():
		status.text=reason
		status.add_theme_color_override("font_color",Color("a44832"))

func update_progress(value: float) -> void:
	progress.value=value
	if value==0: refresh()

func finish_craft(recipe_id: String, times: int, reason: String) -> void:
	var row: Dictionary=book.recipe(recipe_id)
	refresh()
	progress.value=1.0 if reason.is_empty() else 0.0
	if reason.is_empty():
		var text_value := "制作成功 · %s × %d"%[service.database.item(row.output_id).name,int(row.output_count)*times]
		status.text=text_value
		status.add_theme_color_override("font_color",Color("627642"))

	else:
		status.text=reason
		status.add_theme_color_override("font_color",Color("a44832"))


func set_mode(value: bool) -> void:
	if building==value:
		if not building: rebuild_context()
		else: refresh()
		return
	service.cancel_craft()
	building=value
	close_button.text="V / Esc  关闭" if building else "C / Esc  关闭"
	mode_title.text="营地建造" if building else "野外制作"
	mode_hint.text="成功放置后扣材料" if building else "徒手制作 · 进度满后完成"
	mode_footer.text="合法位置确认后直接建造；右键 / E / Esc 取消，不消耗材料。" if building else "材料统计包含背包与快捷栏；成品优先补已有堆叠，再放入背包。"
	amount_row.visible=not building
	progress.visible=not building
	book=service.camps.build_book if building else service.craft_book
	selected=""
	clear(categories);category_buttons.clear()
	for category in book.categories():
		var tab := button(category,choose_category.bind(category))
		tab.toggle_mode=true;category_buttons[category]=tab;categories.add_child(tab)
	quantity.editable=not building
	once.text="建造" if building else "制作一次"
	batch.visible=not building
	choose_category("全部")
	if not building: rebuild_context()

func rebuild_context() -> void:
	if building: return
	mode_title.text="工具台制作" if not service.craft_station_id.is_empty() else "徒手制作"
	mode_hint.text="工具台 · 含徒手配方" if not service.craft_station_id.is_empty() else "徒手制作 · 进度满后完成"
	clear(categories);category_buttons.clear()
	for category in book.categories(not service.craft_station_id.is_empty()):
		var tab := button(category,choose_category.bind(category));tab.toggle_mode=true
		category_buttons[category]=tab;categories.add_child(tab)
	choose_category("全部")

func _process(_delta: float) -> void:
	if visible and not service.craft_station_id.is_empty() and not service.workbench_valid(service.craft_station_id):
		service.cancel_craft();screen.close_panels()
