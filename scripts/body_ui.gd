extends Control
const BodySkin = preload("res://scripts/item_ui_style.gd")
var items: Control
var state: RefCounted
var hud := Button.new()
var summary := Label.new()
var bars: Array[ProgressBar] = []
var numbers: Array[Label] = []
var overlay := Control.new()
var paper := PanelContainer.new()
var details := Label.new()
var lamp := PanelContainer.new()
var fuel := ProgressBar.new()
var lamp_icon := TextureRect.new()
var refresh_clock := 0.0

func configure(owner_ui: Control) -> void:
	items=owner_ui
	state=items.service.body
	theme=BodySkin.theme()
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	hud.size=Vector2(220,169)
	hud.focus_mode=Control.FOCUS_NONE
	for style in ["normal","hover","pressed","focus"]: hud.add_theme_stylebox_override(style,BodySkin.section(10))
	var box := VBoxContainer.new()
	box.position=Vector2(12,10);box.size=Vector2(196,149)
	box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(box)
	for entry in [["health","生命","c47568"],["hunger","饥饿","c9a15c"],["stamina","体力","8b9b69"],["energy","精力","a293b9"]]:
		var row := HBoxContainer.new()
		row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		box.add_child(row)
		var icon := TextureRect.new()
		if entry[0]=="energy":
			var path: String=Engine.get_meta("energy_icon_preview","res://assets/ui/body_v2/energy.png")
			if Engine.has_meta("energy_icon_preview") and FileAccess.file_exists(path):
				icon.texture=ImageTexture.create_from_image(Image.load_from_file(path))
			elif ResourceLoader.exists(path): icon.texture=load(path)
			icon.tooltip_text="精力 · 通过睡眠恢复"
		else: icon.texture=load("res://assets/ui/body_v1/"+entry[0]+".png")
		icon.custom_minimum_size=Vector2(26,26)
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var bar := ProgressBar.new()
		bar.custom_minimum_size=Vector2(119,15);bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		bar.show_percentage=false;bar.tooltip_text=entry[1]
		style_bar(bar,Color(entry[2]))
		row.add_child(bar);bars.append(bar)
		var number := Label.new()
		number.custom_minimum_size.x=33;number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(number);numbers.append(number)
	box.add_child(summary)
	summary.add_theme_font_size_override("font_size",12)
	summary.clip_text=true
	summary.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	items.ignore_card_mouse(box)
	hud.pressed.connect(toggle)
	add_child(lamp)
	lamp.add_theme_stylebox_override("panel",BodySkin.hotbar())
	lamp.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var lamp_row := HBoxContainer.new()
	lamp.add_child(lamp_row)
	lamp_icon.texture=items.service.texture("field_lantern","icon")
	lamp_icon.custom_minimum_size=Vector2(30,30);lamp_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;lamp_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lamp_row.add_child(lamp_icon)
	fuel.custom_minimum_size=Vector2(130,12);fuel.size_flags_vertical=Control.SIZE_SHRINK_CENTER;fuel.show_percentage=false
	preload("res://scripts/item_ui_style.gd").progress_style(fuel,true,false);lamp_row.add_child(fuel)
	items.ignore_card_mouse(lamp)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_STOP
	overlay.add_child(paper)
	paper.add_theme_stylebox_override("panel",BodySkin.frame())
	paper.size=Vector2(520,450)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",18)
	paper.add_child(content)
	var title := Label.new();title.text="身体状态";title.add_theme_font_size_override("font_size",23);content.add_child(title)
	content.add_child(details)
	details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.custom_minimum_size=Vector2(460,276)
	var close := Button.new();close.text="关闭 · Esc";close.set_meta("audio_window_close",true);content.add_child(close);close.pressed.connect(close_panel)
	overlay.hide()
	refresh()

func style_bar(bar: ProgressBar, color: Color) -> void:
	var background := StyleBoxFlat.new();background.bg_color=Color("d9d0b9");background.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new();fill.bg_color=color;fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background",background);bar.add_theme_stylebox_override("fill",fill)

func toggle() -> void:
	if state.sleeping: return
	if overlay.visible: close_panel();return
	items.close_panels()
	if items.world.map_view.visible: items.world.map_view.close_map()
	items.world.player.cancel_action()
	overlay.show();items.dock.hide();items.update_input_block();refresh()

func close_panel() -> void:
	overlay.hide();items.dock.show();items.update_input_block()

func _input(event: InputEvent) -> void:
	if not overlay.visible: return
	if event is InputEventKey:
		if event.pressed and event.physical_keycode==KEY_ESCAPE: close_panel()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if items==null: return
	var area := get_viewport_rect().size
	# Share the dock's bottom baseline while keeping a dedicated left-hand lane.
	hud.position=Vector2(16,items.dock.get_global_rect().end.y-hud.size.y)
	hud.visible=not overlay.visible and not items.world.map_view.visible and not items.craft_panel.visible
	var torch: Dictionary=items.service.inventory.equipment.get("main_hand",{})
	var has_torch: bool=torch.get("item_id")=="solar_flashlight"
	var lamp_on: bool=bool(torch.state.on) if has_torch else is_instance_valid(items.service.lantern) and items.service.lantern.visible
	lamp.visible=hud.visible and items.dock.visible and lamp_on
	preload("res://scripts/item_ui_style.gd").progress_style(fuel,true,lamp_on)
	lamp.position=Vector2(items.dock.position.x+items.dock.size.x*.5-94,items.dock.position.y-54)
	var active: Dictionary=items.service.lamp_slot()
	var lifetime := float(items.service.database.item(str(active.get("item_id",""))).get("lamp_lifetime",state.rules.lantern_seconds))
	fuel.value=items.service.lantern_remaining/lifetime*100.0
	if not active.is_empty(): lamp_icon.texture=items.service.texture(str(active.item_id),"icon")
	if has_torch:
		lamp_icon.texture=items.service.texture("solar_flashlight","icon");fuel.value=float(torch.state.energy)
		style_bar(fuel,Color("8fe4ef"))
	var factor := minf(1.0,minf((area.x-24)/paper.size.x,(area.y-24)/paper.size.y))
	paper.scale=Vector2.ONE*factor;paper.position=(area-paper.size*factor)*.5
	refresh_clock+=delta
	if refresh_clock>=.2: refresh_clock=0;refresh()

func refresh() -> void:
	var values := [state.health,state.hunger,state.stamina,state.energy]
	for i in 4: bars[i].value=values[i];numbers[i].text=str(roundi(values[i]))
	summary.text="身体状态："+("休养中" if state.down else state.status())
	style_bar(bars[3],Color("b77768") if state.energy<float(state.rules.energy_severe) else Color("c5a464") if state.energy<float(state.rules.energy_tired) else Color("a293b9"))
	if state.sleeping: summary.text=state.energy_status()+" · %.1f小时"%(state.sleep_elapsed/60.0)
	if not overlay.visible: return
	details.text="%s\n\n生命  %.0f / 100     饥饿  %.0f / 100     体力  %.0f / 100\n精力  %.0f / 100 · %s\n体力恢复效率  %.0f%%\n\n疾病与疲劳：%s\n\n体型：%s\n长期饮食与活动缓慢影响脸部和衣身轮廓。\n\n%s"%[state.status(),state.health,state.hunger,state.stamina,state.energy,state.energy_status(),state.recovery_factor()*100,state.status(),state.body_description(),state.advice()]

