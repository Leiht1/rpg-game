extends Control
const CampSkin = preload("res://scripts/item_ui_style.gd")
var world: Node
var manager: RefCounted
var panel := Panel.new()
var status := Label.new()
var feedback := Label.new()
var progress := ProgressBar.new()
var cook_button := Button.new()
var claim_button := Button.new()
var recipes: Array[Button]=[]
var recipe_keys: Array[String]=[]
var mode := "book"
var book_scroll: ScrollContainer
var free_box := VBoxContainer.new()
var ingredient_ids: Array[String]=["","","",""]
var ingredient_counts: Array[int]=[1,1,1,1]
var ingredient_choices: Array[OptionButton]=[]
var ingredient_spins: Array[SpinBox]=[]
var current_options: Array[String]=[]
var current := ""
var selected := "roast_carrot"
var sign_dialog := ConfirmationDialog.new()
var sign_input := LineEdit.new()
var pending_sign: Dictionary={}
var placing := false
var building_id := ""
var expected_slots: Array=[]
var source_slot := -1
var source_stack: Dictionary={}
var bag_placing := false
var ghost: Node2D
var ghost_build: RefCounted
var placement_tip := Label.new()
var refresh_clock := 0.0
var build_vertical := false
var build_inward := true
var build_facing := 0
var painting := false
var painted: Dictionary={}
var paint_last := Vector2.INF

var details_box := VBoxContainer.new()
var output_icon := TextureRect.new()
var output_text := Label.new()
var last_detail := ""

func image(id: String, dimension: int) -> TextureRect:
	var node := TextureRect.new();node.texture=world.item_service.texture(id,"icon")
	node.custom_minimum_size=Vector2(dimension,dimension);node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return node

func text(value: String, font_size: int = 14) -> Label:
	var node := Label.new();node.text=value;node.add_theme_font_size_override("font_size",font_size)
	node.custom_minimum_size.x=520
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return node

func configure(owner_world: Node) -> void:
	world=owner_world;manager=world.item_service.camps
	theme=CampSkin.theme();mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel);panel.size=Vector2(1030,560);panel.add_theme_stylebox_override("panel",CampSkin.frame());panel.hide()
	var title := text("野外烹饪",24);title.position=Vector2(48,24);title.size=Vector2(700,40);panel.add_child(title)
	var close := Button.new();close.text="E / Esc 关闭";close.set_meta("audio_window_close",true);close.position=Vector2(820,24);close.size=Vector2(170,40);panel.add_child(close);close.pressed.connect(close_panel)
	for entry in [["食谱册","book",28],["自由搭配","free",184]]:
		var tab := Button.new();tab.text=entry[0];tab.position=Vector2(entry[2],78);tab.size=Vector2(148,36);panel.add_child(tab)
		tab.pressed.connect(func(): mode=entry[1];last_detail="";refresh())
	var scroll := ScrollContainer.new();book_scroll=scroll;scroll.position=Vector2(28,124);scroll.size=Vector2(310,400);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	var list := VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	for id in manager.rules.recipes:
		var recipe: Dictionary=manager.rules.recipes[id]
		if recipe.get("legacy_only",false) or recipe.get("fallback_only",false): continue
		recipe_keys.append(id)
		var button := Button.new();button.text=recipe.name+(" · 尚未解锁" if not recipe.get("default_unlocked",true) else "")
		button.icon=world.item_service.texture(recipe.output,"icon");button.expand_icon=true;button.add_theme_constant_override("icon_max_width",40)
		button.custom_minimum_size=Vector2(290,66);button.toggle_mode=true
		button.modulate=Color.WHITE if recipe.get("default_unlocked",true) else Color(.65,.65,.65)
		button.pressed.connect(func(): selected=id;last_detail="";refresh());list.add_child(button);recipes.append(button)
	for i in 2:
		var mystery := Button.new();mystery.text="？   神秘食物 · 尚未揭晓";mystery.disabled=true;mystery.custom_minimum_size=Vector2(290,66);list.add_child(mystery)
	setup_ingredients()
	var detail_scroll := ScrollContainer.new();detail_scroll.position=Vector2(370,84);detail_scroll.size=Vector2(610,235);detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(detail_scroll)
	details_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details_box.add_theme_constant_override("separation",7);detail_scroll.add_child(details_box)
	status.position=Vector2(370,327);status.size=Vector2(610,44);panel.add_child(status)
	progress.position=Vector2(370,375);progress.size=Vector2(610,14);progress.show_percentage=false;panel.add_child(progress)
	preload("res://scripts/item_ui_style.gd").progress_style(progress)
	var output := HBoxContainer.new();output.position=Vector2(370,402);output.size=Vector2(610,54);panel.add_child(output)
	output_icon.custom_minimum_size=Vector2(48,48);output_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;output_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	output.add_child(output_icon);output.add_child(output_text)
	for entry in [[cook_button,"开始烹饪",Vector2(370,466),"cook"],[claim_button,"领取",Vector2(690,466),"claim"]]:
		var button: Button=entry[0];button.text=entry[1];button.position=entry[2];button.size=Vector2(290,42);panel.add_child(button);button.pressed.connect(func(): command(entry[3]))
	feedback.position=Vector2(370,512);feedback.size=Vector2(610,32);feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(feedback)
	placement_tip.add_theme_stylebox_override("normal",CampSkin.target_hint());placement_tip.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(placement_tip);placement_tip.hide()
	sign_dialog.theme=CampSkin.theme()
	sign_dialog.borderless=true
	sign_dialog.transparent_bg=true
	sign_dialog.transparent=true
	sign_dialog.add_theme_stylebox_override("panel",CampSkin.frame())
	for border_name in ["embedded_border","embedded_unfocused_border"]:
		var border:=CampSkin.frame()
		border.content_margin_top=36
		sign_dialog.add_theme_stylebox_override(border_name,border)
	sign_dialog.add_theme_color_override("title_color",Color("4e493d"))
	sign_dialog.add_theme_color_override("title_outline_modulate",Color.TRANSPARENT)
	sign_dialog.add_theme_constant_override("title_outline_size",0)
	add_child(sign_dialog);sign_dialog.title="路标文字 · 确认后不可修改"
	sign_dialog.min_size=Vector2i(400,180);sign_dialog.ok_button_text="确认建造";sign_dialog.cancel_button_text="取消"
	sign_input.max_length=6;sign_input.placeholder_text="填写1至6个字";sign_input.custom_minimum_size=Vector2(330,42)
	for state in ["normal","focus","read_only"]:
		var plain := StyleBoxEmpty.new()
		for edge in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:plain.set_content_margin(edge,10)
		sign_input.add_theme_stylebox_override(state,plain)
	sign_input.add_theme_color_override("selection_color",Color.TRANSPARENT)
	sign_input.add_theme_color_override("font_selected_color",Color("454b37"))
	sign_input.add_theme_color_override("caret_color",Color("454b37"))
	var sign_title:=Label.new();sign_title.text="路标文字 · 确认后不可修改"
	var sign_fields:=VBoxContainer.new();sign_fields.add_theme_constant_override("separation",12)
	sign_dialog.add_child(sign_fields);sign_fields.add_child(sign_title);sign_fields.add_child(sign_input)
	sign_dialog.register_text_enter(sign_input)
	sign_input.text_changed.connect(func(value):sign_dialog.get_ok_button().disabled=not world.item_service.builds.valid_sign_text(value))
	sign_dialog.confirmed.connect(confirm_sign)
	sign_dialog.canceled.connect(cancel_sign)
	get_viewport().size_changed.connect(fit);fit()

func fit() -> void:
	var area := get_viewport_rect().size
	var factor: float=minf(1.0,minf((area.y-80)/560.0,(area.x-32)/1030.0))
	panel.scale=Vector2.ONE*factor;panel.position=(area-panel.size*factor)*.5
	placement_tip.position=Vector2(maxf(12,area.x*.5-220),50)

func open(id: String) -> void:
	world.item_ui.close_panels()
	if world.map_view.visible: world.map_view.close_map()
	current=id;panel.show();world.environment_view.dial.hide();feedback.text=""
	world.player.cancel_action();world.item_ui.update_input_block();refresh()

func close_panel() -> void:
	if panel.visible: world.environment_view.dial.show()
	panel.hide();current="";cancel_placement();world.item_ui.update_input_block()

func begin_placement(index: int) -> void:
	world.item_ui.close_panels()
	if not world.item_service.writable: world.item_service.notice.emit("存档受保护，不能放置");return
	building_id=""
	cancel_placement()
	source_slot=index;source_stack=world.item_service.inventory.slots[index].duplicate(true);placing=true
	ghost=Sprite2D.new();ghost.set("texture",load("res://assets/campfire/v1/base.png"));ghost.scale=Vector2.ONE*float(manager.rules.display_width)/256.0
	world.object_root.add_child(ghost);placement_tip.show();world.player.cancel_action();world.item_ui.update_input_block()

func cancel_placement() -> void:
	pending_sign.clear();sign_dialog.hide()
	if is_instance_valid(sign_input):sign_input.release_focus()
	bag_placing=false
	painting=false;painted.clear();paint_last=Vector2.INF
	placing=false;building_id="";expected_slots=[];placement_tip.hide()
	if is_instance_valid(ghost): ghost.queue_free()
	ghost=null

func setup_ingredients() -> void:
	free_box.position=Vector2(28,124);free_box.size=Vector2(310,430);free_box.add_theme_constant_override("separation",10);panel.add_child(free_box)
	for i in 4:
		var label := Label.new();label.text="主料" if i==0 else "搭配 %d"%i;free_box.add_child(label)
		var line := HBoxContainer.new();free_box.add_child(line)
		var choice := OptionButton.new();choice.fit_to_longest_item=false;choice.clip_text=true;choice.custom_minimum_size=Vector2(202,42);choice.expand_icon=true;choice.add_theme_constant_override("icon_max_width",18);line.add_child(choice);ingredient_choices.append(choice)
		var quantity := SpinBox.new();quantity.min_value=1;quantity.max_value=1;quantity.step=1;quantity.custom_minimum_size=Vector2(98,42);line.add_child(quantity);ingredient_spins.append(quantity)
		choice.item_selected.connect(func(index: int): ingredient_ids[i]=current_options[index];ingredient_counts[i]=1;last_detail="";refresh())
		quantity.value_changed.connect(func(value: float): ingredient_counts[i]=int(value);last_detail="";refresh())

func selected_materials() -> Dictionary:
	var result := {}
	for i in 4:
		if ingredient_ids[i].is_empty(): continue
		if result.has(ingredient_ids[i]): return {}
		result[ingredient_ids[i]]=ingredient_counts[i]
	return result

func refresh_ingredients() -> void:
	var ids: Array[String]=[""]
	var inventory: ItemInventory=world.item_service.inventory
	for definition in manager.rules.recipes.values():
		if definition.get("legacy_only",false): continue
		for id in definition.materials:
			if inventory.count_item(id)>0 and not ids.has(id): ids.append(id)
	# Keep a removed source visible so stale selections fail validation without silently changing.
	for id in ingredient_ids:
		if not ids.has(id): ids.append(id)
	current_options=ids
	for i in 4:
		var choice: OptionButton=ingredient_choices[i];choice.clear()
		for id in ids:
			if id.is_empty(): choice.add_item("— 选择 / 移除 —")
			else: choice.add_icon_item(world.item_service.texture(id,"icon"),world.item_service.database.item(id).name+" ×"+str(inventory.count_item(id)))
			choice.get_popup().set_item_icon_max_width(choice.item_count-1,18)
		choice.select(ids.find(ingredient_ids[i]))
		for j in ids.size():
			choice.set_item_disabled(j,not ids[j].is_empty() and ids[j]!=ingredient_ids[i] and ingredient_ids.has(ids[j]))
		var spin: SpinBox=ingredient_spins[i];spin.set_block_signals(true)
		var available: int=inventory.count_item(ingredient_ids[i]) if not ingredient_ids[i].is_empty() else 0
		spin.min_value=1 if available>0 else 0;spin.max_value=available;spin.value=ingredient_counts[i]
		ingredient_counts[i]=int(spin.value);spin.editable=available>0;spin.set_block_signals(false)

func command(action: String) -> void:
	for spin in ingredient_spins:
		if spin.get_line_edit().has_focus(): spin.apply()
	var reason: String=manager.act(current,"experiment" if action=="cook" and mode=="free" else action,selected,selected_materials())
	feedback.text=reason if not reason.is_empty() else {"cook":"食材已投入，关闭面板也会继续烹饪","claim":"成品已放入背包"}.get(action,"")
	refresh()

func refresh() -> void:
	if not panel.visible or not manager.states.has(current): return
	var row: Dictionary=manager.states[current]
	var db: ItemDatabase=world.item_service.database
	var inventory: ItemInventory=world.item_service.inventory
	book_scroll.visible=mode=="book";free_box.visible=mode=="free"
	var material_selection := selected_materials()
	var chosen: String=selected if mode=="book" else manager.experiment_recipe(material_selection)
	var recipe: Dictionary=manager.rules.recipes.get(chosen,{})
	var revealed: bool=manager.known(chosen)
	var counts := {}
	for definition in manager.rules.recipes.values():
		if definition.get("legacy_only",false):continue
		for id in definition.materials:counts[id]=inventory.count_item(id)
	var signature := mode+chosen+str(manager.discovered)+str(counts)+str(material_selection)
	var enough := not recipe.is_empty()
	if mode=="free":
		for id in material_selection:
			if material_selection[id]<1 or inventory.count_item(id)<int(material_selection[id]):enough=false
	for id in recipe.get("materials",{}):
		if inventory.count_item(id)<int(recipe.materials[id]): enough=false
	if last_detail!=signature:
		last_detail=signature
		if mode=="free": refresh_ingredients()
		for child in details_box.get_children(): details_box.remove_child(child);child.queue_free()
		if revealed:
			var heading := HBoxContainer.new();heading.add_child(image(recipe.output,48));heading.add_child(text(recipe.name,21));details_box.add_child(heading)
			details_box.add_child(text("所需时间：%d秒 · 饥饿 +%d · 成品 ×1"%[recipe.seconds,db.item(recipe.output).effects.hunger]))
			for id in recipe.materials:
				var line := HBoxContainer.new();line.add_child(image(id,28))
				var have: int=inventory.count_item(id);var need: int=int(recipe.materials[id])
				var caption := text("%s  拥有 %d / 需要 %d%s"%[db.item(id).name,have,need," · 缺少材料" if have<need else ""])
				line.add_child(caption);details_box.add_child(line)
		elif mode=="free":
			details_box.add_child(text("这组材料将煮成杂烩" if recipe.get("fallback_only",false) else "似乎可以组合成一种新料理" if not recipe.is_empty() else "请选择食材和数量",20))
			details_box.add_child(text("只有真正完成烹饪才会揭晓并记录食谱。" if not recipe.get("fallback_only",false) else "没有对应食谱时仍可烹饪成固定杂烩。"))
		else: details_box.add_child(text("？ 神秘食物 · 尚未揭晓",21))
		if mode=="free" and not recipe.is_empty() and not enough:
			details_box.add_child(text("食材不足，请重新选择数量。"))
		elif mode=="free":
			for id in material_selection:
				if material_selection[id]<1 or inventory.count_item(id)<material_selection[id]:
					details_box.add_child(text("所选食材不足，请替换材料或调整数量。"));break
	for i in recipes.size():
		var key: String=recipe_keys[i]
		var definition: Dictionary=manager.rules.recipes[key]
		var unlocked: bool=manager.known(key)
		recipes[i].set_pressed_no_signal(key==selected)
		recipes[i].text=definition.name if unlocked else "？ 神秘食物 · 尚未揭晓"
		recipes[i].icon=world.item_service.texture(definition.output,"icon") if unlocked else null
		recipes[i].modulate=Color.WHITE if unlocked else Color(.65,.65,.65)
	var active: bool=not row.recipe.is_empty()
	status.text=("已点燃" if row.lit else "已熄灭")+" · "+("可领取" if row.ready else ("烹饪中" if row.lit else "烹饪暂停") if active else "等待烹饪")
	progress.value=100*float(row.elapsed)/float(manager.rules.recipes[row.recipe].seconds) if active else 0
	output_icon.visible=active;output_text.visible=active
	if active:
		var output: String=manager.rules.recipes[row.recipe].output
		var visible_output: bool=row.ready or manager.known(row.recipe) or manager.rules.recipes[row.recipe].get("legacy_only",false)
		var output_stack: Dictionary=row.get("output",{"item_id":output,"count":1})
		output_icon.texture=world.item_service.stack_texture(output_stack,"icon") if visible_output else null
		output_text.text=("%s ×1 · 饥饿 +%d · %s"%[world.item_service.stack_name(output_stack),db.item(output).effects.hunger,"可领取" if row.ready else "制作中"]) if visible_output else "？ 神秘料理 · 制作中"
	cook_button.disabled=active or not row.lit or not enough or (mode=="book" and not revealed)
	claim_button.disabled=not row.ready

func handle_input(event: InputEvent) -> bool:
	if sign_dialog.visible:
		if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:cancel_sign();return true
		# Let the native text field receive characters and dialog buttons receive clicks.
		return false
	if placing:
		if bag_placing:
			if event is InputEventMouseButton and event.pressed:
				if event.button_index==MOUSE_BUTTON_RIGHT: close_panel();return true
				if event.button_index==MOUSE_BUTTON_LEFT:
					var row: Dictionary=world.item_service.builds.candidate("sleeping_bag",get_viewport().get_canvas_transform().affine_inverse()*event.position,false,true,0)
					var error: String=world.item_service.builds.place_bag(row,source_slot,source_stack)
					if error.is_empty(): close_panel()
					else: world.item_service.notice.emit(error)
					return true
			if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_E,KEY_ESCAPE]: close_panel();return true
			return false
		if not building_id.is_empty() and world.item_service.builds.definitions.has(manager.build_book.recipe(building_id).get("output_id","")):
			if event is InputEventMouseButton:
				if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed: close_panel();return true
				if event.button_index==MOUSE_BUTTON_LEFT:
					painting=event.pressed;painted.clear();paint_last=Vector2.INF
					if painting: paint_at(get_viewport().get_canvas_transform().affine_inverse()*event.position)
					return true
			if event is InputEventMouseMotion and painting:
				paint_at(get_viewport().get_canvas_transform().affine_inverse()*event.position);return true
			if event is InputEventKey and event.pressed and not event.echo:
				var definition: Dictionary=world.item_service.builds.definitions[manager.build_book.recipe(building_id).output_id]
				if event.physical_keycode==KEY_R and (definition.layer=="edge" or definition.get("sleep",false) or manager.build_book.recipe(building_id).output_id=="rain_shelter"): build_vertical=not build_vertical
				if event.physical_keycode==KEY_F: build_inward=not build_inward
				if event.physical_keycode in [KEY_E,KEY_ESCAPE]: close_panel()
				return true
			return false
		if event is InputEventMouseButton and event.pressed:
			if event.button_index==MOUSE_BUTTON_RIGHT: close_panel()
			elif event.button_index==MOUSE_BUTTON_LEFT:
				var at: Vector2=get_viewport().get_canvas_transform().affine_inverse()*event.position
				var reason: String=manager.build(at,building_id,expected_slots) if not building_id.is_empty() else manager.place(at,source_slot,source_stack)
				if reason.is_empty(): close_panel();world.item_service.notice.emit("篝火已放置，靠近按E烹饪")
				else: world.item_service.notice.emit(reason)
			return true
		if event is InputEventKey and event.pressed:
			if event.physical_keycode in [KEY_E,KEY_ESCAPE]: close_panel()
			return true
	if panel.visible and event is InputEventKey and event.pressed:
		if get_viewport().gui_get_focus_owner() is LineEdit and event.physical_keycode not in [KEY_E,KEY_ESCAPE,KEY_B,KEY_C,KEY_V,KEY_M]: return false
		if event.physical_keycode in [KEY_E,KEY_ESCAPE]: close_panel()
		elif event.physical_keycode in [KEY_B,KEY_C,KEY_V,KEY_M]:
			close_panel()
			return false
		return true
	return false

func _process(delta: float) -> void:
	if world==null: return
	if placing and is_instance_valid(ghost) and not sign_dialog.visible:
		var at: Vector2=get_viewport().get_canvas_transform().affine_inverse()*world.item_ui.drag_pointer;ghost.position=at+Vector2(0,-24)
		if bag_placing:
			var row: Dictionary=world.item_service.builds.candidate("sleeping_bag",at,false,true,0)
			ghost.position=at;ghost_build.states["preview"]=row;ghost.queue_redraw()
			var issue: String=world.item_service.builds.reason(row)
			ghost.modulate=Color(1,1,1,.7) if issue.is_empty() else Color(1,.55,.45,.65)
			placement_tip.text=("可以放置" if issue.is_empty() else issue)+" · WASD移动 / 左键放置睡袋 / Esc取消"
			return
		if not building_id.is_empty() and world.item_service.builds.definitions.has(manager.build_book.recipe(building_id).get("output_id","")):
			var row := build_row(at)
			ghost.position=Vector2(row.x,row.y)
			ghost_build.states["preview"]=row
			ghost.ground_neighbors=world.item_service.builds.states
			ghost.gate_angle=PI*.5 if row.vertical else 0.0
			ghost.z_index=-1 if row.layer=="ground" else 0
			ghost.queue_redraw()
			var issue: String=world.item_service.builds.reason(row)
			ghost.modulate=Color(1,1,1,.7) if issue.is_empty() else Color(1,.55,.45,.65)
			placement_tip.text=("可以放置" if issue.is_empty() else issue)+" · WASD移动 / 左键建造 / Esc取消"+(" / R横纵 / 开门自动选侧" if row.layer=="edge" else " / R横竖" if ghost_build.definitions[row.kind].get("sleep",false) else "")
			return
		var reason: String=manager.placement_reason(at)
		if not building_id.is_empty():
			if not preload("res://scripts/food_freshness.gd").matches_slots(world.item_service.inventory.slots,expected_slots): reason="背包已变化，请取消后重新建造"
			elif not manager.build_check(building_id).is_empty(): reason=manager.build_check(building_id)
		ghost.modulate=Color(.65,1,.65,.75) if reason.is_empty() else Color(1,.55,.45,.7)
		placement_tip.text=("可以放置" if reason.is_empty() else reason)+" · 左键放置 / 右键或E取消"
	if panel.visible:
		if not manager.states.has(current) or world.player.position.distance_to(Vector2(manager.states[current].x,manager.states[current].y))>float(manager.rules.interaction_range): close_panel();return
		refresh_clock+=delta
		if refresh_clock>=.2: refresh_clock=0;refresh()


func begin_build(id: String) -> void:
	var reason: String=manager.build_check(id)
	if not reason.is_empty(): world.item_service.notice.emit(reason);return
	world.item_ui.close_panels()
	cancel_placement()
	building_id=id;expected_slots=world.item_service.inventory.slots.duplicate(true);placing=true
	ghost=Sprite2D.new();ghost.set("texture",load("res://assets/campfire/v1/base.png"));ghost.scale=Vector2.ONE*float(manager.rules.display_width)/256.0
	if world.item_service.builds.definitions.has(manager.build_book.recipe(id).get("output_id","")):
		ghost.free()
		ghost_build=preload("res://scripts/camp_buildings.gd").new()
		ghost_build.states["preview"]=build_row(world.player.position)
		ghost_build.textures=world.item_service.builds.textures
		ghost=preload("res://scripts/camp_building.gd").new()
		ghost.manager=ghost_build;ghost.building_id="preview";ghost.preview=true
		ghost.ground_neighbors=world.item_service.builds.states
	world.object_root.add_child(ghost);placement_tip.show();world.player.cancel_action();world.item_ui.update_input_block()

func build_row(at: Vector2) -> Dictionary:
	return world.item_service.builds.candidate(str(manager.build_book.recipe(building_id).output_id),at,build_vertical,build_inward,build_facing)

func begin_sleeping_bag(index: int) -> void:
	if world.item_service.body.sleep_active() or not world.item_service.writable: return
	if preload("res://scripts/sleep_controller.gd").art_path("sleeping_bag").is_empty(): world.item_service.notice.emit("睡眠设施美术待确认，请使用独立预览");return
	world.item_ui.close_panels();cancel_placement()
	source_slot=index;source_stack=world.item_service.inventory.slots[index].duplicate(true)
	placing=true;bag_placing=true
	ghost_build=preload("res://scripts/camp_buildings.gd").new();ghost_build.textures=world.item_service.builds.textures
	ghost_build.states["preview"]=world.item_service.builds.candidate("sleeping_bag",world.player.position,false,true,0)
	ghost=preload("res://scripts/camp_building.gd").new();ghost.manager=ghost_build;ghost.building_id="preview";ghost.preview=true
	world.object_root.add_child(ghost);placement_tip.show();world.item_ui.update_input_block()

func paint_at(at: Vector2) -> void:
	var first := at if paint_last==Vector2.INF else paint_last
	var steps := maxi(1,ceili(first.distance_to(at)/24.0))
	for i in range(steps+1):
		var row := build_row(first.lerp(at,float(i)/steps))
		if row.kind=="signpost":
			var issue: String=world.item_service.builds.reason(row)
			painting=false
			if not issue.is_empty():world.item_service.notice.emit(issue);return
			pending_sign=row.duplicate(true);sign_input.text="";sign_dialog.get_ok_button().disabled=true
			sign_dialog.popup_centered();sign_input.grab_focus();world.item_ui.update_input_block();return
		var key := str(row.x)+":"+str(row.y)
		if painted.has(key): continue
		painted[key]=true
		var issue: String=world.item_service.builds.place(row,expected_slots)
		if issue.is_empty():
			expected_slots=world.item_service.inventory.slots.duplicate(true)
			if row.layer=="free" or world.item_service.builds.definitions[row.kind].get("door",false): close_panel();return
		elif issue.begins_with("材料不足") or issue.begins_with("保存失败") or issue.begins_with("背包已变化"):
			world.item_service.notice.emit(issue);painting=false;return
		else: world.item_service.notice.emit(issue)
	paint_last=at


func cancel_sign() -> void:
	close_panel();sign_input.release_focus();world.item_ui.update_input_block()

func confirm_sign() -> void:
	if pending_sign.is_empty() or not world.item_service.builds.valid_sign_text(sign_input.text):
		cancel_sign();return
	var row := pending_sign.duplicate(true);row.text=sign_input.text
	var issue: String=world.item_service.builds.place(row,expected_slots)
	close_panel();sign_input.release_focus();world.item_ui.update_input_block()
	if not issue.is_empty():world.item_service.notice.emit(issue)
