extends Control
const Slot = preload("res://scripts/item_slot.gd")
const ItemSkin = preload("res://scripts/item_ui_style.gd")
const NavButton = preload("res://scripts/item_nav_button.gd")
var service: Node
var world: Node
var bag := PanelContainer.new()
var equipment_panel := PanelContainer.new()
var catalog := PanelContainer.new()
var cells: Array[Control] = []
var message := Label.new()
var message_time := 0.0
var catalog_rows := VBoxContainer.new()
var filter := LineEdit.new()
var bag_button := NavButton.new()
var organize_button := Button.new()
var map_button := NavButton.new()
var hover_index := -1
var hover_wait := 0.0
var hover_card: Control
var ground_drop := preload("res://scripts/item_ground_drop.gd").new()
var dock: HBoxContainer
var modal := Control.new()
var item_menu := PanelContainer.new()
var use_button := Button.new()
var destroy_button := Button.new()
var split_panel := PanelContainer.new()
var split_title := Label.new()
var split_amount := LineEdit.new()
var split_error := Label.new()
var split_confirm := Button.new()
var modal_index := -1
var modal_stack: Dictionary = {}
var quantity_action := "split"
var quantity_camp := ""
var equip_button := Button.new()
var preview_actor: Node2D
var portrait_held_tool := preload("res://scripts/held_tool.gd").new()
var portrait_appearance := preload("res://scripts/equipment_appearance.gd").new()
var portrait_clock := 0.0
var preview_view: SubViewport
var target_tip := PanelContainer.new()
var target_caption := Label.new()
const TARGET_TIP_SECONDS := 2.0
var target_tip_id := 0
var target_tip_time := 0.0
var bag_dragging := false
var craft_panel := preload("res://scripts/craft_ui.gd").new()
var craft_button := Button.new()
var build_button := Button.new()
var obtained := preload("res://scripts/item_obtained_ui.gd").new()
var hud_accent := TextureRect.new()
var body_ui: Control
var drag_pointer := Vector2.ZERO

func configure(owner_world: Node, items: Node) -> void:
	world = owner_world
	name="ItemUI"
	service = items
	theme = ItemSkin.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground_drop.screen=self
	ground_drop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ground_drop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground_drop)
	dock = HBoxContainer.new()
	dock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dock.set_anchors_preset(Control.PRESET_TOP_LEFT)
	dock.position=Vector2(-340,-86)
	dock.add_theme_constant_override("separation",8)
	add_child(dock)
	var base := PanelContainer.new()
	base.add_theme_stylebox_override("panel",ItemSkin.hotbar())
	dock.add_child(base)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation",6)
	base.add_child(bar)
	for i in 8: add_slot(bar,i)
	bag_button.tooltip_text="背包 · B"
	bag_button.pressed.connect(toggle_bag)
	dock.add_child(bag_button)
	map_button.symbol="map"
	map_button.tooltip_text="地图 · M"
	map_button.pressed.connect(toggle_map)
	dock.add_child(map_button)
	craft_button.text="C  制作"
	craft_button.custom_minimum_size=Vector2(86,52)
	craft_button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	craft_button.pressed.connect(toggle_craft)
	dock.add_child(craft_button)
	build_button.text="V  建造"
	build_button.custom_minimum_size=craft_button.custom_minimum_size
	build_button.size_flags_vertical=craft_button.size_flags_vertical
	build_button.pressed.connect(toggle_build)
	dock.add_child(build_button)
	hud_accent.texture=ItemSkin.art("accent")
	hud_accent.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	hud_accent.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hud_accent.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud_accent.size=Vector2(30,28)
	add_child(hud_accent)
	hud_accent.hide()
	body_ui=preload("res://scripts/body_ui.gd").new()
	add_child(body_ui)
	body_ui.configure(self)
	bag.position = Vector2(280,130)
	bag.custom_minimum_size = Vector2(280,0)
	bag.z_index=12
	bag.add_theme_stylebox_override("panel",ItemSkin.frame())
	add_child(bag)
	var layout := VBoxContainer.new()
	bag.add_child(layout)
	layout.add_theme_constant_override("separation",10)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := Label.new()
	heading.text = "背包"
	heading.add_theme_font_size_override("font_size",21)
	heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	organize_button.text="整理"
	organize_button.tooltip_text="合并并排列背包道具，保留快捷栏与装备"
	organize_button.focus_mode=Control.FOCUS_NONE
	organize_button.pressed.connect(organize_bag)
	header.add_child(organize_button)
	var close := Button.new()
	close.text="关闭"
	close.pressed.connect(close_panels)
	header.add_child(close)
	# Main paper's upper-right binding is outside the button/text safety region.
	var header_clearance := Control.new()
	header_clearance.custom_minimum_size.x=8
	header.add_child(header_clearance)
	var line := HSeparator.new()
	layout.add_child(line)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	var contents := HBoxContainer.new()
	contents.add_theme_constant_override("separation",20)
	layout.add_child(contents)
	var grid_margin := MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_top",10)
	grid_margin.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	contents.add_child(grid_margin)
	grid_margin.add_child(grid)
	for row in 8:
		for col in 4: add_slot(grid,8+row*4+col)
	var equipment_frame := PanelContainer.new()
	equipment_frame.name="EquipmentSection"
	var section_style := StyleBoxEmpty.new()
	equipment_frame.add_theme_stylebox_override("panel",section_style)
	equipment_panel.z_index=12
	equipment_panel.add_theme_stylebox_override("panel",ItemSkin.frame())
	add_child(equipment_panel)
	equipment_panel.add_child(equipment_frame)
	equipment_panel.hide()
	var equipment_body := HBoxContainer.new()
	equipment_body.add_theme_constant_override("separation",14)
	equipment_frame.add_child(equipment_body)
	var equipment_stack := VBoxContainer.new()
	equipment_stack.add_theme_constant_override("separation",12)
	equipment_body.add_child(equipment_stack)
	var ordered: Array=[]
	for i in service.inventory.equipment_slots.size(): ordered.append(i)
	ordered.sort_custom(func(a,b): return int(service.inventory.equipment_slots[a].get("ui_order",a))<int(service.inventory.equipment_slots[b].get("ui_order",b)))
	for index in ordered:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation",3)
		equipment_stack.add_child(row)
		var label := Label.new()
		label.text=service.inventory.equipment_slots[index].name
		label.add_theme_font_size_override("font_size",12)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		# Keep logical indices stable for old saves and existing drag operations.
		var slot := Slot.new()
		slot.index=40+index
		slot.screen=self
		row.add_child(slot)
		row.add_child(label)
		while cells.size()<=slot.index: cells.append(null)
		cells[slot.index]=slot
	var portrait_column := VBoxContainer.new()
	portrait_column.add_theme_constant_override("separation",4)
	equipment_body.add_child(portrait_column)
	var equipment_title := Label.new()
	equipment_title.name="EquipmentTitle"
	equipment_title.text="角色装备"
	equipment_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	portrait_column.add_child(equipment_title)
	var portrait := SubViewportContainer.new()
	portrait.name="CharacterPortrait"
	portrait.custom_minimum_size=Vector2(156,228)
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait_column.add_child(portrait)
	preview_view=SubViewport.new()
	preview_view.size=Vector2i(156,228)
	preview_view.transparent_bg=true
	preview_view.render_target_update_mode=SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	portrait.add_child(preview_view)
	preview_actor=load("res://assets/hero/cartoon/character.tscn").instantiate()
	preview_actor.position=Vector2(14,44)
	preview_actor.scale=Vector2.ONE
	preview_actor.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	preview_actor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	preview_view.add_child(preview_actor)
	preview_actor.get_node("AnimationPlayer").callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	refresh_equipment_preview()
	var note := Label.new()
	note.text = "拖动存放 · 右键管理
Ctrl+左键拆分 · B 关闭"
	note.add_theme_font_size_override("font_size",12)
	note.add_theme_color_override("font_color",Color("89816a"))
	var footer_safe := MarginContainer.new()
	footer_safe.add_theme_constant_override("margin_left",8)
	layout.add_child(footer_safe)
	footer_safe.add_child(note)
	bag.hide()
	catalog.position = Vector2(260,120)
	catalog.custom_minimum_size = Vector2(760,490)
	catalog.add_theme_stylebox_override("panel",ItemSkin.frame())
	add_child(catalog)
	var cat_layout := VBoxContainer.new()
	catalog.add_child(cat_layout)
	var cat_title := Label.new()
	cat_title.text = "物品图鉴 / 调试管理  ·  F6 关闭" if OS.has_feature("debug") else "物品图鉴"
	cat_layout.add_child(cat_title)
	if OS.has_feature("debug"):
		var debug_actions := HBoxContainer.new()
		cat_layout.add_child(debug_actions)
		var ore_button := Button.new()
		ore_button.text="脚边放置测试矿点（燧石）"
		ore_button.pressed.connect(func(): service.debug_ore())
		debug_actions.add_child(ore_button)
		var animal_button := Button.new()
		animal_button.name="SpawnAnimal"
		animal_button.text="附近生成动物 +1"
		animal_button.pressed.connect(func(): service.animals.debug_spawn_near())
		debug_actions.add_child(animal_button)
	filter.placeholder_text = "搜索名称、ID 或分类（food / material / natural）"
	cat_layout.add_child(filter)
	filter.text_changed.connect(func(_text): rebuild_catalog())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720,410)
	cat_layout.add_child(scroll)
	catalog_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(catalog_rows)
	rebuild_catalog()
	catalog.hide()
	message.position = Vector2(440,558)
	message.add_theme_font_size_override("font_size",19)
	message.add_theme_color_override("font_color",Color("fff4cf"))
	message.add_theme_color_override("font_shadow_color",Color("43452e"))
	message.add_theme_constant_override("shadow_outline_size",4)
	add_child(message)
	target_tip.add_theme_stylebox_override("panel",ItemSkin.target_hint())
	target_tip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	target_caption.add_theme_font_size_override("font_size",14)
	target_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	target_tip.add_child(target_caption)
	add_child(target_tip)
	service.inventory.changed.connect(refresh)
	service.notice.connect(show_notice)
	setup_item_actions()
	add_child(craft_panel)
	craft_panel.configure(self)
	add_child(obtained);obtained.configure(service)
	get_viewport().size_changed.connect(fit_core_ui)
	dock.resized.connect(fit_core_ui)
	call_deferred("fit_core_ui")
	if not service.writable: show_notice("物品存档格式异常，原文件已保留；本次不覆盖")

func category_name(id: String) -> String:
	return {"food":"食物","material":"基础材料","natural":"自然收集物","tool":"工具","utility":"探索用品","weapon":"武器","headwear":"头饰","outfit":"服装套装"}.get(id,id)

func organize_bag() -> void:
	if not bag.visible or bag_dragging or item_modal_open() or get_viewport().gui_is_dragging(): return
	hide_item_hover()
	var reason: String=service.organize_bag()
	show_notice("背包已整理" if reason.is_empty() else reason)

func make_item_card(index: int) -> Control:
	var card := PanelContainer.new()
	card.theme=ItemSkin.theme()
	card.add_theme_stylebox_override("panel",ItemSkin.tooltip(22))
	card.custom_minimum_size=Vector2(310,0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	card.add_child(column)
	var slot: Dictionary=service.inventory.get_slot(index)
	if slot.is_empty():
		var empty := Label.new()
		empty.text="空快捷格\n从背包拖入物品" if index<8 else ("空装备槽\n拖入匹配装备" if index>=40 else "空背包格\n可拖入物品整理")
		column.add_child(empty)
		return card
	var definition: Dictionary=service.database.item(slot.item_id)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var image := TextureRect.new()
	image.texture=service.texture(slot.item_id,"icon")
	image.custom_minimum_size=Vector2(40,40)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heading.add_child(image)
	var title := Label.new()
	title.text=definition.name+"\n"+category_name(definition.category)
	title.add_theme_font_size_override("font_size",16)
	heading.add_child(title)
	column.add_child(HSeparator.new())
	var description := Label.new()
	description.text=definition.description
	description.custom_minimum_size.x=274
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	var detail := Label.new()
	detail.text="数量  %d / %d\n获取  %s" % [slot.count,definition.max_stack,definition.drop_rules.source]
	if definition.get("durability")!=null:
		detail.text+="\n耐久度：%d / %d"%[int(slot.get("durability",definition.durability)) if slot.get("durability")!=null else int(definition.durability),int(definition.durability)]
	detail.add_theme_font_size_override("font_size",12)
	detail.add_theme_color_override("font_color",Color("8d7854"))
	column.add_child(detail)
	column.add_child(HSeparator.new())
	var action := Label.new()
	action.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	action.custom_minimum_size.x=274
	var options := "装备 / 销毁" if definition.get("equippable",false) else ("打开 / 关闭 / 销毁" if definition.get("use_action","")=="light" else "使用 / 销毁" if definition.get("usable",false) else "销毁（材料不能直接使用）")
	action.text=("右键卸下 · 可拖回背包" if index>=40 else "右键："+options+"\n拖到地面丢弃  ·  Ctrl+左键拆分")
	if definition.get("equippable",false):
		var abilities: Array[String]=[]
		for capability in definition.capabilities:
			abilities.append({"chop":"砍伐","mine":"开采","dig":"挖掘","shear":"剪羊毛","attack":"攻击"}.get(capability,"扩展能力"))
		action.text+="\n能力："+"、".join(abilities)
	action.add_theme_color_override("font_color",Color("668056"))
	column.add_child(action)
	return card

func add_slot(parent: Node, index: int) -> void:
	var slot := Slot.new()
	slot.index = index
	slot.screen = self
	parent.add_child(slot)
	while cells.size()<=index: cells.append(null)
	cells[index]=slot

func refresh() -> void:
	for cell in cells: cell.refresh()
	refresh_equipment_preview()
	if hover_index>=0: show_item_hover(hover_index,hover_anchor)

var hover_anchor: Control
func show_item_hover(index: int, anchor: Control = null) -> void:
	hide_item_hover()
	if item_modal_open() or get_viewport().gui_is_dragging() or bag_dragging: return
	hover_anchor=anchor if anchor!=null else cells[index]
	hover_index=index
	hover_wait=0.15

func hide_item_hover(index: int = -1) -> void:
	if index>=0 and hover_index!=index: return
	hover_index=-1
	if is_instance_valid(hover_card): hover_card.queue_free()
	hover_card=null

func show_notice(text: String) -> void:
	message.text = text
	message_time = 3.0

func _process(delta: float) -> void:
	equipment_panel.visible=bag.visible
	message_time = maxf(0,message_time-delta)
	if bag.visible: update_portrait(delta)
	update_target_tip(world.player.selected_target(),delta)
	message.visible = message_time > 0
	if hover_index>=0 and not is_instance_valid(hover_card):
		hover_wait-=delta
		if hover_wait<=0:
			hover_card=make_item_card(hover_index)
			hover_card.z_index=20
			add_child(hover_card)
			ignore_card_mouse(hover_card)
	if is_instance_valid(hover_card):
		var cell: Control=hover_anchor if is_instance_valid(hover_anchor) else cells[hover_index]
		var rect := cell.get_global_rect()
		var at := Vector2(rect.end.x+10,rect.position.y)
		if at.x+hover_card.size.x>get_viewport_rect().size.x-12: at.x=rect.position.x-hover_card.size.x-10
		hover_card.position=at.clamp(Vector2(12,12),get_viewport_rect().size-hover_card.size-Vector2(12,12))

func update_target_tip(target: Node2D, delta: float) -> void:
	if service.body.sleep_active(): target_tip.hide();return
	var current_id := target.get_instance_id() if is_instance_valid(target) else 0
	if current_id!=0 and target.has_meta("animal_id") and target.manager.caption(target.animal_id).is_empty(): current_id=0
	if current_id != target_tip_id:
		target_tip_id = current_id
		target_tip_time = TARGET_TIP_SECONDS if current_id != 0 else 0.0
	else:
		target_tip_time = maxf(0.0,target_tip_time-delta)
	# Progress/caption changes and opening panels do not restart this encounter.
	target_tip.visible = not (is_instance_valid(world.camp_ui) and (world.camp_ui.panel.visible or world.camp_ui.placing)) and current_id != 0 and target_tip_time > 0.0 and not bag.visible and not catalog.visible and not craft_panel.visible and not item_modal_open() and not world.map_view.visible
	if target_tip.visible:
		var name_text := "树木"
		if target.is_in_group("drops"): name_text=service.database.item(str(target.get_meta("item_id","wood"))).get("name","物品")
		elif target.has_meta("display_name"): name_text=str(target.get_meta("display_name"))
		target_caption.text=name_text+" · "+preload("res://scripts/world_interaction.gd").caption(target,service.inventory)
		target_tip.reset_size()
		target_tip.position=(get_viewport().get_canvas_transform()*target.position+Vector2(18,-38)).clamp(Vector2(8,8),get_viewport_rect().size-target_tip.size-Vector2(8,8))

func ignore_card_mouse(node: Node) -> void:
	if node is Control: node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): ignore_card_mouse(child)

func rebuild_catalog() -> void:
	for child in catalog_rows.get_children(): child.queue_free()
	for id in service.database.ids():
		var definition: Dictionary = service.database.item(id)
		if not filter.text.is_empty() and not (str(definition)+category_name(definition.category)).to_lower().contains(filter.text.to_lower()): continue
		var row := HBoxContainer.new()
		catalog_rows.add_child(row)
		var icon := TextureRect.new()
		icon.texture = service.texture(id,"icon")
		icon.custom_minimum_size = Vector2(42,42)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var text := Label.new()
		text.text = "%s  ·  %s  ·  %s  ·  上限%d\n%s\n获取：%s" % [definition.name,id,category_name(definition.category),definition.max_stack,definition.description,definition.drop_rules.source]
		text.add_theme_font_size_override("font_size",13)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		if OS.has_feature("debug"):
			var grant := Button.new()
			grant.text = "+99"
			grant.pressed.connect(func():
				var left: int = service.inventory.add(id,99)
				show_notice("背包已满" if left > 0 else "调试添加："+str(definition.name)))
			row.add_child(grant)

func close_panels() -> void:
	if is_instance_valid(service.planting_ui): service.planting_ui.close_panel()
	service.craft_station_id=""
	if is_instance_valid(world.camp_ui): world.camp_ui.close_panel()
	if is_instance_valid(body_ui): body_ui.overlay.hide()
	close_item_actions()
	bag_dragging=false
	hide_item_hover()
	bag.hide()
	equipment_panel.hide()
	catalog.hide()
	craft_panel.hide()
	craft_panel.quantity.get_line_edit().release_focus()
	world.environment_view.dial.show()
	dock.show()
	hud_accent.visible=false
	world.player.input_blocked = world.map_view.visible or service.body.sleep_active()

func toggle_bag() -> void:
	if world.map_view.visible: world.map_view.close_map()
	var next := not bag.visible
	close_panels()
	bag.visible=next
	equipment_panel.visible=next
	update_input_block()
	if next:
		world.player.cancel_action()
		world.player.moving=false
		world.player.update_animation()

func navigation_contains(point: Vector2) -> bool:
	return bag_button.get_global_rect().has_point(point) or map_button.get_global_rect().has_point(point) or craft_button.get_global_rect().has_point(point) or build_button.get_global_rect().has_point(point)

func toggle_craft(station_id: String="") -> void:
	if world.map_view.visible: world.map_view.close_map()
	var next := not craft_panel.visible or craft_panel.building
	close_panels()
	service.craft_station_id=station_id if service.workbench_valid(station_id) else ""
	craft_panel.visible=next
	world.environment_view.dial.visible=not next
	dock.visible=not next
	hud_accent.visible=false
	if next:
		world.player.cancel_action()
		craft_panel.set_mode(false)
		craft_panel.rebuild_context()
	update_input_block()

func toggle_build() -> void:
	if world.map_view.visible: world.map_view.close_map()
	var next := not craft_panel.visible or not craft_panel.building
	close_panels()
	craft_panel.visible=next
	world.environment_view.dial.visible=not next
	dock.visible=not next
	hud_accent.visible=false
	if next:
		world.player.cancel_action()
		craft_panel.set_mode(true)
	update_input_block()

func fit_core_ui() -> void:
	var area := get_viewport_rect().size
	var factor := minf(1.0,(area.y-110)/maxf(1,bag.size.y))
	bag.scale=Vector2.ONE*factor
	bag.position=Vector2(area.x-16-bag.size.x*factor,maxf(16,(area.y-86-bag.size.y*factor)*.5))
	equipment_panel.scale=Vector2.ONE
	equipment_panel.position=Vector2(16,maxf(100,(area.y-equipment_panel.size.y)*.5-30))
	var dock_left := 248.0 # 16px margin + 220px body HUD + 12px gap.
	var dock_factor := minf(1.0,(area.x-dock_left-16)/maxf(680,dock.size.x))
	dock.scale=Vector2.ONE*dock_factor
	dock.position=Vector2(maxf(dock_left,(area.x-dock.size.x*dock_factor)*.5),area.y-86*dock_factor)
	hud_accent.size=Vector2(30,28)*dock_factor
	hud_accent.position=dock.position+Vector2(-34,18)*dock_factor
	hud_accent.visible=false

func toggle_map() -> void:
	var next: bool = not world.map_view.visible
	close_panels()
	if next: world.map_view.open_map()
	else: world.map_view.close_map()

func setup_item_actions() -> void:
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	modal.z_index=30
	add_child(modal)
	modal.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed: close_item_actions(); get_viewport().set_input_as_handled())
	item_menu.add_theme_stylebox_override("panel",ItemSkin.tooltip(14))
	modal.add_child(item_menu)
	var options := VBoxContainer.new()
	item_menu.add_child(options)
	use_button.text="使用"
	destroy_button.text="销毁"
	destroy_button.tooltip_text="删除此格全部物品，不掉到地面"
	for button in [equip_button,use_button,destroy_button]:
		button.custom_minimum_size=Vector2(112,34)
		options.add_child(button)
	equip_button.pressed.connect(func():
		if not stack_unchanged(): close_item_actions(); return
		var index := modal_index
		var equipped_index := equipped_action_index(index)
		if equipped_index!=int(equip_button.get_meta("equipment_index",-1)): close_item_actions();return
		close_item_actions()
		var ok: bool=service.inventory.unequip(equipped_index) if equipped_index>=40 else service.inventory.equip(index)
		if not ok: show_notice("背包已满，装备保持原位" if equipped_index>=40 else "装备类型不匹配")
		service.save_state())
	use_button.pressed.connect(func():run_item_action(false))
	destroy_button.pressed.connect(func():run_item_action(true))
	split_panel.custom_minimum_size=Vector2(320,0)
	split_panel.add_theme_stylebox_override("panel",ItemSkin.frame())
	modal.add_child(split_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	split_panel.add_child(column)
	column.add_child(split_title)
	split_amount.placeholder_text="输入拆分数量"
	split_amount.select_all_on_focus=true
	column.add_child(split_amount)
	split_error.add_theme_font_size_override("font_size",12)
	column.add_child(split_error)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	split_confirm.text="拆分"
	buttons.add_child(split_confirm)
	var cancel := Button.new()
	cancel.text="取消"
	buttons.add_child(cancel)
	split_confirm.pressed.connect(confirm_split)
	cancel.pressed.connect(close_item_actions)
	split_amount.text_changed.connect(func(_value):validate_split())
	split_amount.text_submitted.connect(func(_value):confirm_split())
	modal.hide()
	item_menu.hide()
	split_panel.hide()

func item_modal_open() -> bool:
	return service.body.sleep_active() or (is_instance_valid(world.camp_ui) and world.camp_ui.sign_dialog.visible) or (is_instance_valid(modal) and modal.visible)

func update_input_block() -> void:
	if is_instance_valid(service.industry_ui) and service.industry_ui.visible:world.player.input_blocked=true;return
	if is_instance_valid(service.planting_ui) and service.planting_ui.visible:
		world.player.input_blocked=true;return
	world.player.input_blocked=service.body.sleep_active() or (is_instance_valid(world.camp_ui) and world.camp_ui.panel.visible) or (is_instance_valid(body_ui) and body_ui.overlay.visible) or craft_panel.visible or catalog.visible or world.map_view.visible or item_modal_open() or get_viewport().gui_is_dragging() or get_viewport().gui_get_focus_owner() is LineEdit

func close_item_actions() -> void:
	modal.hide()
	item_menu.hide()
	split_panel.hide()
	split_amount.release_focus()
	modal_index=-1
	modal_stack={}
	quantity_action="split";quantity_camp=""
	update_input_block()

func choose_stack(index: int) -> bool:
	close_item_actions()
	hide_item_hover()
	if index<0 or index>=cells.size() or service.inventory.get_slot(index).is_empty(): return false
	modal_index=index
	modal_stack=service.inventory.get_slot(index).duplicate(true)
	world.player.cancel_action()
	return true

func stack_unchanged() -> bool:
	return modal_index>=0 and preload("res://scripts/food_freshness.gd").matches(service.inventory.get_slot(modal_index),modal_stack)

func open_item_menu(index: int, at: Vector2) -> void:
	if not choose_stack(index): return
	modal.show()
	item_menu.show()
	equip_button.visible=index>=40 or bool(service.database.item(modal_stack.item_id).get("equippable",false))
	equip_button.set_meta("equipment_index",equipped_action_index(index))
	equip_button.text="卸下" if equipped_action_index(index)>=40 else "装备"
	use_button.text=("关闭" if is_instance_valid(service.lantern) and service.lantern.visible and modal_stack.get("lamp_id","")==service.active_lamp else "打开") if service.database.item(modal_stack.item_id).get("use_action","")=="light" else "使用"
	use_button.visible=index<40
	destroy_button.visible=index<40 and not (index<8 and service.inventory.slots[index].is_empty())
	use_button.disabled=not service.database.item(modal_stack.item_id).usable
	item_menu.reset_size()
	item_menu.position=at.clamp(Vector2(8,8),get_viewport_rect().size-Vector2(150,160))
	update_input_block()

func run_item_action(destroy: bool) -> void:
	if not stack_unchanged(): close_item_actions(); return
	var index := modal_index
	var item_name: String=service.database.item(modal_stack.item_id).name
	close_item_actions()
	if destroy:
		if service.inventory.destroy_slot(index): show_notice("已销毁 "+item_name)
	elif not service.inventory.use_slot(index): show_notice(use_failure(index))
	service.save_state()

func use_failure(index: int) -> String:
	var slot: Dictionary=service.inventory.get_slot(index)
	if service.database.item(str(slot.get("item_id",""))).get("use_action","")=="unpack": return "背包空间不足，补给包保持原样"
	if service.database.item(str(slot.get("item_id",""))).get("use_action","")=="eat": return "身体已饱足，暂时无需进食"
	return "这件物品暂时不能直接使用"

func open_split(index: int) -> void:
	if not choose_stack(index): return
	split_confirm.text="拆分";split_amount.placeholder_text="输入拆分数量"
	if int(modal_stack.count)<2: show_notice("数量至少为2才能拆分"); return
	modal.show()
	split_panel.show()
	split_title.text="拆分 · %s（共%d个）"%[service.database.item(modal_stack.item_id).name,modal_stack.count]
	split_amount.text=str(maxi(1,int(modal_stack.count)/2))
	split_panel.position=(get_viewport_rect().size-Vector2(320,190))*.5
	validate_split()
	split_amount.grab_focus()
	split_amount.select_all()
	update_input_block()

func split_value() -> int:
	if not split_amount.text.is_valid_int(): return -1
	return int(split_amount.text)

func validate_split() -> void:
	if modal_stack.is_empty(): return
	var value := split_value()
	var limit := quantity_limit()
	var valid := value>=1 and value<=limit
	split_confirm.disabled=not valid
	split_error.text=("可填写 1–%d，原格至少保留1个"%limit if quantity_action=="split" else "可投放 1–%d 个，余量留在原格"%limit) if valid else "请输入 1–%d 的整数"%limit

func quantity_limit() -> int:
	if modal_stack.is_empty(): return 0
	if quantity_action=="split": return int(modal_stack.count)-1
	if quantity_action=="fuel":
		if not service.camps.states.has(quantity_camp): return 0
		return service.camps.feed_amount(quantity_camp,modal_stack)
	return int(modal_stack.count)

func open_drop_quantity(index: int, camp_id: String = "") -> void:
	if not choose_stack(index): return
	quantity_action="ground" if camp_id.is_empty() else "fuel";quantity_camp=camp_id
	modal.show();split_panel.show();split_confirm.text="投放";split_amount.placeholder_text="输入投放数量"
	split_title.text=("投向地面" if camp_id.is_empty() else "投入篝火")+" · "+str(service.database.item(modal_stack.item_id).name)
	split_amount.text="1";split_panel.position=(get_viewport_rect().size-Vector2(320,190))*.5
	validate_split();split_amount.grab_focus();split_amount.select_all();update_input_block()

func confirm_split() -> void:
	if not stack_unchanged(): close_item_actions(); return
	var value := split_value()
	if value<1 or value>quantity_limit(): validate_split(); return
	if quantity_action!="split":
		var index := modal_index;var expected := modal_stack.duplicate(true);var camp := quantity_camp
		if not service.writable: show_notice("存档受保护，不能投放");close_item_actions();return
		close_item_actions()
		if not camp.is_empty():
			var reason: String=world.player.camp_throw.start(world.player,camp,index,expected,value)
			if not reason.is_empty(): show_notice(reason)
		else: service.discard(index,value)
		return
	if service.inventory.split_slot(modal_index,value)<0:
		split_error.text="背包没有空格，物品数量未改变"
		return
	close_item_actions()
	service.save_state()

func valid_drag(data: Variant) -> bool:
	if not data is Dictionary or data.get("inventory")!=service.inventory or not data.has("slot"): return false
	var index := int(data.slot)
	if index<0 or index>=cells.size() or service.inventory.get_slot(index).is_empty(): return false
	var slot: Dictionary=service.inventory.get_slot(index)
	return data.get("item_id",slot.item_id)==slot.item_id and int(data.get("count",slot.count))==int(slot.count) and preload("res://scripts/food_freshness.gd").matches(data.get("snapshot",slot),slot)

func inventory_contains(at: Vector2) -> bool:
	return bag.visible and (bag.get_global_rect().has_point(at) or equipment_panel.get_global_rect().has_point(at))

func can_drop_on_ground(at: Vector2, data: Variant) -> bool:
	if not valid_drag(data) or int(data.slot)>=40 or (int(data.slot)<8 and service.inventory.slots[int(data.slot)].is_empty()) or item_modal_open() or world.map_view.visible or catalog.visible or craft_panel.visible: return false
	if inventory_contains(at) or service.storage_ui.contains_pointer(at): return false
	if dock.get_global_rect().has_point(at): return false
	var position_world: Vector2=get_viewport().get_canvas_transform().affine_inverse()*at
	if not service.animals.target_at(position_world).is_empty():return true
	var camp_id: String=service.camps.target_at(position_world)
	# A camp hit always belongs to fuel handling, including rejected items; never discard it as a ground drop.
	if not camp_id.is_empty(): return true
	return world.stream.has_ground(position_world) and world.generator.can_walk(position_world,2)

func drop_on_ground(data: Variant, at: Vector2 = Vector2.INF) -> void:
	if item_modal_open(): return
	if at!=Vector2.INF and (inventory_contains(at) or service.storage_ui.contains_pointer(at)): return
	if at!=Vector2.INF and valid_drag(data):
		var position_world: Vector2=get_viewport().get_canvas_transform().affine_inverse()*at
		var animal_id: String=service.animals.target_at(position_world)
		if not animal_id.is_empty():
			var reason: String=world.player.animal_feed.start(world.player,animal_id,int(data.slot),data.snapshot)
			if not reason.is_empty():show_notice(reason)
			return
		var camp_id: String=service.camps.target_at(position_world)
		if not camp_id.is_empty():
			var rejected: String=service.camps.feed_check(camp_id,int(data.slot),data.snapshot)
			if not rejected.is_empty(): show_notice(rejected);return
			if int(data.count)>1: open_drop_quantity(int(data.slot),camp_id);return
			var reason: String=world.player.camp_throw.start(world.player,camp_id,int(data.slot),data.snapshot)
			if not reason.is_empty(): show_notice(reason)
			return
	if valid_drag(data) and int(data.slot)<40:
		if not service.writable: show_notice("存档受保护，不能投放");return
		if int(service.inventory.get_slot(int(data.slot)).count)>1: open_drop_quantity(int(data.slot))
		else: service.discard(int(data.slot),1)

func _notification(what: int) -> void:
	if what==NOTIFICATION_DRAG_BEGIN:
		hide_item_hover()
		ground_drop.mouse_filter=Control.MOUSE_FILTER_STOP
		world.player.cancel_action()
		update_input_block()
	elif what==NOTIFICATION_DRAG_END:
		ground_drop.mouse_filter=Control.MOUSE_FILTER_IGNORE

		call_deferred("update_input_block")

func _input(event: InputEvent) -> void:
	if is_instance_valid(service.industry_ui) and service.industry_ui.visible:return
	if is_instance_valid(service.planting_ui) and service.planting_ui.handle_input(event):
		get_viewport().set_input_as_handled();return
	if is_instance_valid(service.sleep_ui) and service.sleep_ui.handle_input(event):
		get_viewport().set_input_as_handled();return

	if service.body.sleep_active():
		# Camera framing remains available while actor actions stay locked.
		world.player.zoom_from_wheel(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton: drag_pointer=event.position
	if is_instance_valid(world.camp_ui) and world.camp_ui.sign_dialog.visible:
		if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:world.camp_ui.cancel_sign();get_viewport().set_input_as_handled()
		return
	if is_instance_valid(world.camp_ui) and world.camp_ui.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(body_ui) and body_ui.overlay.visible:
		body_ui._input(event)
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if craft_panel.visible:
		if event.physical_keycode==KEY_ESCAPE: close_panels()
		elif event.physical_keycode==KEY_C: toggle_craft()
		elif event.physical_keycode==KEY_V: toggle_build()
		elif event.physical_keycode==KEY_M: toggle_map()
		elif event.physical_keycode==KEY_B: toggle_bag()
		elif get_viewport().gui_get_focus_owner()==craft_panel.quantity.get_line_edit() and (event.physical_keycode in [KEY_BACKSPACE,KEY_DELETE,KEY_LEFT,KEY_RIGHT,KEY_ENTER,KEY_KP_ENTER,KEY_HOME,KEY_END] or (event.physical_keycode>=KEY_0 and event.physical_keycode<=KEY_9)): return
		get_viewport().set_input_as_handled()
		return
	if item_modal_open():
		if event.physical_keycode==KEY_ESCAPE:
			close_item_actions()
			get_viewport().set_input_as_handled()
		elif not split_panel.visible:
			get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_N,KEY_E,KEY_M,KEY_B,KEY_F6]:
			get_viewport().set_input_as_handled()
		# Split numbers/Enter reach only the focused LineEdit, never hotbar use.
		return
	if get_viewport().gui_is_dragging():
		if event.physical_keycode==KEY_ESCAPE: return # Let Godot cancel the native drag.
		get_viewport().set_input_as_handled()
		return
	if get_viewport().gui_get_focus_owner() is LineEdit and not catalog.visible: return
	var key: int = event.physical_keycode
	if key==KEY_V and not catalog.visible:
		toggle_build()
		get_viewport().set_input_as_handled()
		return
	if key==KEY_C and not catalog.visible:
		toggle_craft()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_B:
		toggle_bag()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_F6 and OS.has_feature("debug"):
		if world.map_view.visible: world.map_view.close_map()
		var panel: Control = catalog
		var next := not panel.visible
		close_panels()
		panel.visible = next
		world.player.input_blocked = next
		if next: world.player.cancel_action(); world.player.moving = false; world.player.update_animation()
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE and (bag.visible or catalog.visible):
		close_panels()
		get_viewport().set_input_as_handled()
	elif ((bag.visible or catalog.visible) and key in [KEY_M,KEY_N]) or (catalog.visible and key==KEY_E):
		get_viewport().set_input_as_handled()
	elif key >= KEY_1 and key <= KEY_8 and not catalog.visible:
		service.inventory.selected = key-KEY_1
		service.dirty = true
		refresh()
		var selected: int=service.inventory.selected
		if not service.inventory.get_slot(selected).is_empty() and not service.database.item(str(service.inventory.get_slot(selected).item_id)).tags.has("seed"):
			if not service.inventory.use_slot(selected): show_notice(use_failure(selected))
		get_viewport().set_input_as_handled()


func refresh_equipment_preview() -> void:
	if service==null: return
	world.player.set_equipment(service.inventory)
	update_portrait(0.0)

func update_portrait(delta: float) -> void:
	if not is_instance_valid(preview_actor): return
	# Equipment display uses its own front-facing idle pose, never the world pose.
	portrait_held_tool.release_pose()
	var animation: AnimationPlayer=preview_actor.get_node("AnimationPlayer")
	var clip := animation.get_animation("front_breathe")
	portrait_clock=fposmod(portrait_clock+delta,clip.length)
	if animation.current_animation!="front_breathe": animation.play("front_breathe")
	animation.seek(portrait_clock,true)
	var visual: Node2D=preview_actor.get_node("Visual")
	visual.scale=Vector2.ONE
	visual.position=Vector2.ZERO
	portrait_appearance.apply(preview_actor,service.inventory,"front")
	portrait_held_tool.apply(preview_actor,service.inventory,"front","")
	preload("res://scripts/body_shape.gd").apply(preview_actor,service.body.build)

func sync_portrait(source: Node, target: Node) -> void:
	# Keep the portrait origin, but mirror the complete live drawing state.
	# Animation can change draw-behind-parent without changing the pose/texture.
	if source is CanvasItem and target is CanvasItem:
		target.show_behind_parent=source.show_behind_parent
		target.z_index=source.z_index
		target.z_as_relative=source.z_as_relative
		target.texture_filter=source.texture_filter
		target.texture_repeat=source.texture_repeat
		target.self_modulate=source.self_modulate
	for old in target.get_children():
		if (str(old.name).begins_with("EquipmentVisual") or str(old.name)=="HeldTool") and source.get_node_or_null(NodePath(str(old.name)))==null:
			old.queue_free()
	for child in source.get_children():
		if child is AnimationPlayer: continue
		var twin := target.get_node_or_null(NodePath(str(child.name)))
		if twin==null:
			if child is Sprite2D:
				twin=child.duplicate()
				target.add_child(twin)
				target.move_child(twin,child.get_index())
			else: continue
		if child is Node2D and twin is Node2D:
			twin.transform=child.transform
			twin.visible=child.visible
			twin.modulate=child.modulate
		if child is Sprite2D and twin is Sprite2D:
			twin.texture=child.texture
			twin.centered=child.centered
			twin.offset=child.offset
			twin.flip_h=child.flip_h
			twin.flip_v=child.flip_v
		sync_portrait(child,twin)



func equipped_action_index(index: int) -> int:
	if index>=ItemInventory.SLOT_COUNT: return index
	if index<0 or index>=ItemInventory.HOTBAR_COUNT or not service.inventory.slots[index].is_empty(): return -1
	var instance: Dictionary=service.inventory.get_slot(index)
	if instance.is_empty(): return -1
	for i in service.inventory.equipment_slots.size():
		var key: String=service.inventory.equipment_slots[i].id
		if service.inventory.equipment.get(key,{}).get("instance_id","")==instance.get("instance_id",""):
			return ItemInventory.SLOT_COUNT+i
	return -1
