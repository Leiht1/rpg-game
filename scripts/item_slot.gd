extends PanelContainer
const ItemSkin = preload("res://scripts/item_ui_style.gd")
var index := 0
var screen: Control
var icon := TextureRect.new()
var amount := Label.new()
var shortcut := Label.new()
var fallback := Label.new()
var hovered := false
var durability_bar := ProgressBar.new()
var equipped_marker := Label.new()
var dev_symbol := preload("res://scripts/item_dev_symbol.gd").new()

func _ready() -> void:
	custom_minimum_size = Vector2(48,48)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(48,48)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left=7; icon.offset_top=6; icon.offset_right=-7; icon.offset_bottom=-7
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(icon)
	dev_symbol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(dev_symbol)
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	fallback.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fallback.add_theme_font_size_override("font_size",20)
	fallback.add_theme_color_override("font_color",Color("62513c"))
	canvas.add_child(fallback)
	amount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	amount.offset_right=-4; amount.offset_bottom=-1
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount.add_theme_font_size_override("font_size",12)
	amount.add_theme_color_override("font_color",Color("554735"))
	amount.add_theme_constant_override("shadow_outline_size",0)
	canvas.add_child(amount)
	shortcut.position=Vector2(4,0)
	shortcut.add_theme_font_size_override("font_size",11)
	shortcut.add_theme_color_override("font_color",Color("65543f"))
	shortcut.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(shortcut)
	equipped_marker.text="✓"
	equipped_marker.position=Vector2(35,-1)
	equipped_marker.add_theme_font_size_override("font_size",11)
	equipped_marker.add_theme_color_override("font_color",Color("4c6a48"))
	equipped_marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(equipped_marker)
	durability_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	durability_bar.offset_left=5;durability_bar.offset_right=-5
	durability_bar.offset_top=-5;durability_bar.offset_bottom=-2
	durability_bar.scale=Vector2(1,.36)
	durability_bar.show_percentage=false;durability_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new();track.bg_color=Color("c6baa4")
	durability_bar.add_theme_stylebox_override("background",track)
	canvas.add_child(durability_bar)
	gui_input.connect(on_input)
	mouse_entered.connect(func(): hovered=true; refresh(); screen.show_item_hover(index,self))
	mouse_exited.connect(func(): hovered=false; refresh(); screen.hide_item_hover(index))
	refresh()

func refresh() -> void:
	var slot: Dictionary = screen.service.inventory.get_slot(index)
	icon.texture = null
	dev_symbol.visible=false
	amount.text = ""
	fallback.text=""
	shortcut.text = str(index+1) if index < 8 else ""
	tooltip_text = ""
	durability_bar.hide()
	if not slot.is_empty():
		icon.texture = screen.service.stack_texture(slot,"icon")
		dev_symbol.visible=icon.texture==null
		dev_symbol.symbol=screen.service.database.ids().find(slot.item_id)
		dev_symbol.queue_redraw()
		var definition: Dictionary=screen.service.database.item(slot.item_id)
		if definition.get("durability")!=null:
			durability_bar.show();durability_bar.max_value=float(definition.durability)
			durability_bar.value=float(slot.get("durability",definition.durability)) if slot.get("durability")!=null else float(definition.durability)
			var fill := StyleBoxFlat.new()
			var ratio := durability_bar.value/durability_bar.max_value
			fill.bg_color=Color("b55745").lerp(Color("c4aa53"),ratio*2) if ratio<.5 else Color("c4aa53").lerp(Color("71895d"),(ratio-.5)*2)
			durability_bar.add_theme_stylebox_override("fill",fill)
		if icon.texture==null and definition.get("equippable",false):
			dev_symbol.visible=false
			fallback.text={"chop":"斧","mine":"镐","dig":"铲"}.get(definition.get("action_id",""),"装")
		amount.text = str(slot.count)
	var equipped := false
	if slot.has("instance_id"):
		for item in screen.service.inventory.equipment.values():
			if item.get("instance_id","")==slot.instance_id: equipped=true
	equipped_marker.visible=equipped
	var disabled := false
	var drag = get_viewport().gui_get_drag_data()
	if drag is Dictionary and drag.get("inventory")==screen.service.inventory and drag.has("slot"):
		disabled=not screen.service.inventory.accepts(index,screen.service.inventory.get_slot(int(drag.slot)))
	add_theme_stylebox_override("panel",ItemSkin.slot(index==screen.service.inventory.selected,hovered,equipped,disabled))

func _notification(what: int) -> void:
	if what in [NOTIFICATION_DRAG_BEGIN,NOTIFICATION_DRAG_END] and is_instance_valid(screen): call_deferred("refresh")

func on_input(event: InputEvent) -> void:
	if index<8 and screen.world.get_meta("network_game",false) and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not event.ctrl_pressed:
		screen.service.inventory.selected=index;screen.refresh()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and event.ctrl_pressed:
		screen.open_split(index) if index<40 else screen.show_notice("装备槽不拆分")
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		screen.open_item_menu(index,get_global_transform()*event.position)
		accept_event()

func _get_drag_data(_position: Vector2) -> Variant:
	var slot: Dictionary = screen.service.inventory.get_slot(index)
	if slot.is_empty() or Input.is_key_pressed(KEY_CTRL) or screen.item_modal_open(): return null
	screen.hide_item_hover()
	var preview := PanelContainer.new()
	# Native drag previews are top-level: they must also draw above the bag (Z=12).
	preview.z_index=100
	preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
	preview.name="InventoryDragPreview"
	preview.add_theme_stylebox_override("panel",ItemSkin.slot(true,true))
	var image := TextureRect.new()
	image.texture=icon.texture
	image.custom_minimum_size=Vector2(42,42)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.add_child(image)
	if icon.texture==null:
		if not fallback.text.is_empty():
			var label := Label.new()
			label.text=fallback.text
			label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			label.add_theme_font_size_override("font_size",20)
			image.add_child(label)
		else:
			var symbol := preload("res://scripts/item_dev_symbol.gd").new()
			symbol.symbol=dev_symbol.symbol
			symbol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			image.add_child(symbol)
	set_drag_preview(preview)
	return {"inventory":screen.service.inventory,"slot":index,"item_id":slot.item_id,"count":slot.count,"snapshot":slot.duplicate(true)}

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("chest"):
		return index<43 and data.get("storage")==screen.service.storage_ui and data.chest==data.storage.current and data.storage.panel.visible
	return screen.valid_drag(data) and not screen.item_modal_open() and screen.service.inventory.accepts(index,screen.service.inventory.get_slot(int(data.slot))) and screen.service.inventory.accepts(int(data.slot),screen.service.inventory.get_slot(index))

func _drop_data(_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("chest"):
		data.storage.report(screen.service.builds.transfer(str(data.chest),int(data.chest_slot),index,data.snapshot,screen.service.inventory.get_slot(index).duplicate(true)))
		return
	screen.service.inventory.move_slot(int(data.slot),index)

