extends SceneTree
## Only the changed UI and its required existing interactions; isolated temporary world.
const OUT := "res://reports/ui-rework-v1/"
var world: Node
var ui: Control
var service: Node
var checks: Array=[]
var pointer := Vector2.ZERO
var text_failures: Array[String]=[]
var geometry_failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func frames(n: int=3) -> void:
	for i in n:await process_frame
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func key(code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
		root.push_input(event,true);await frames(2)
func motion(at: Vector2, held: bool=false) -> void:
	var event := InputEventMouseMotion.new();event.position=at;event.global_position=at;event.relative=at-pointer;event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	pointer=at;root.push_input(event,true);await frames(2)
func mouse(at: Vector2, pressed: bool, code: int=MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=code;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed and code==MOUSE_BUTTON_LEFT else 0
	root.push_input(event,true);await frames(2)
func click(control: Control, code: int=MOUSE_BUTTON_LEFT) -> void:
	var at := control.get_global_rect().get_center();await motion(at);await mouse(at,true,code);await mouse(at,false,code)
func shot(name_value: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+name_value+".png")
func text_bounds(node: Node) -> void:
	if node is Control and not node.is_visible_in_tree():return
	if node is Button and not node.text.is_empty():
		var font: Font=node.get_theme_font("font")
		var font_size: int=node.get_theme_font_size("font_size")
		var box: StyleBox=node.get_theme_stylebox("normal")
		var width: float=node.size.x-box.get_content_margin(SIDE_LEFT)-box.get_content_margin(SIDE_RIGHT)
		if node.icon:
			width-=mini(node.get_theme_constant("icon_max_width") if node.get_theme_constant("icon_max_width")>0 else 36,36)+node.get_theme_constant("h_separation")
		for line in node.text.split("\n"):
			if font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width+1:text_failures.append("Button: "+node.text)
	if node is Label and node.autowrap_mode==TextServer.AUTOWRAP_OFF and not node.text.is_empty():
		var font: Font=node.get_theme_font("font");var point_size: int=node.get_theme_font_size("font_size")
		for line in node.text.split("\n"):
			if font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size).x>node.size.x+1:text_failures.append("Label: "+line)
	for child in node.get_children():text_bounds(child)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.max_fps=60;Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	ui=world.item_ui;service=world.item_service;world.player.automated=true
	world.environment_view.simulation.set_time(10);world.environment_view.simulation.paused=true
	for pair in [["wild_berry",18],["branch",27],["plant_fiber",34],["stone",12],["flint",9],["wood",7],["broad_leaf",8],["wild_carrot",6],["bone_fragment",3],["relic_fragment",4],["stone_axe",1],["stone_pickaxe",1],["simple_shovel",1]]:service.inventory.add(pair[0],pair[1])
	service.inventory.move_slot(8,0)
	service.inventory.move_slot(18,1)
	service.inventory.move_slot(19,2)
	await key(KEY_2)
	await key(KEY_B);await frames(8)
	check(ui.bag.visible and not world.player.input_blocked,"B opens original moving bag")
	check(ui.bag.get_theme_stylebox("panel").texture.resource_path.contains("rework_v1"),"new main art is formally referenced")
	check(ui.cells[8].get_theme_stylebox("panel").texture.resource_path.ends_with("slot.png"),"normal linen slot uses actual new texture")
	check(ui.cells[1].get_theme_stylebox("panel").texture.resource_path.ends_with("slot_selected.png"),"selected hotbar uses separate painted state")
	check(ui.cells[1].equipped_marker.visible,"equipped tool reference has visual status")
	text_bounds(ui.bag);text_bounds(ui.dock)
	var fixed_bag_size: Vector2=ui.bag.size
	var fixed_bag_scale: Vector2=ui.bag.scale
	for cell in [ui.cells[0],ui.cells[1],ui.cells[10]]:
		await motion(cell.get_global_rect().get_center());await mouse(cell.get_global_rect().get_center(),true);await mouse(cell.get_global_rect().get_center(),false)
		check(ui.bag.size==fixed_bag_size and ui.bag.scale==fixed_bag_scale,"bag hover/click keeps frame and scale "+str(cell.index))
	await shot("inventory-1280")
	await motion(ui.cells[10].get_global_rect().get_center());await create_timer(.2).timeout;await frames(3)
	check(is_instance_valid(ui.hover_card),"native hover shows tooltip")
	check(ui.hover_card.get_theme_stylebox("panel").texture.resource_path.ends_with("tooltip.png"),"tooltip uses distinct paper note")
	check(root.get_visible_rect().encloses(ui.hover_card.get_global_rect()),"tooltip stays in screen")
	text_bounds(ui.hover_card);await shot("tooltip-1280")
	await motion(Vector2(1250,680));await frames(3)
	check(not is_instance_valid(ui.hover_card),"moving pointer hides tooltip")
	# Native item drag uses original hit areas after art/layout changes.
	var source: Vector2=ui.cells[9].get_global_rect().get_center()
	await motion(source);await mouse(source,true);await motion(source+Vector2(18,0),true)
	check(root.gui_is_dragging(),"original native item drag begins")
	await motion(ui.cells[4].get_global_rect().get_center(),true);await mouse(ui.cells[4].get_global_rect().get_center(),false)
	check(service.inventory.get_slot(4).get("item_id","")=="branch" and service.inventory.slots[9].is_empty(),"native drag transfers stack without changing inventory logic")
	await click(ui.cells[0],MOUSE_BUTTON_RIGHT)
	check(ui.item_menu.visible and not ui.use_button.disabled,"right-click existing food use menu remains usable")
	await click(ui.use_button)
	check(service.inventory.slots[0].count==17,"original food use consumes one")
	await key(KEY_3)
	check(service.inventory.has_capability("mine") and ui.cells[2].equipped_marker.visible,"hotbar switches original tool and visual marker")
	await shot("equipment-and-hotbar")
	ui.close_panels();await frames(3);await shot("hud-selected")
	await key(KEY_C);await frames(5)
	check(ui.craft_panel.visible and world.player.input_blocked,"C opens original crafting input guard")
	var fixed_craft_rect: Rect2=ui.craft_panel.panel.get_global_rect()
	var fixed_craft_scale: Vector2=ui.craft_panel.panel.scale
	ui.craft_panel.choose_category("工具");ui.craft_panel.select_recipe("hand_stone_axe")
	# Display genuine insufficient state by temporarily using an otherwise empty existing inventory.
	var original: Array=service.inventory.slots.duplicate(true)
	for i in 40:service.inventory.slots[i]={}
	service.inventory.changed.emit();await frames(5)
	check(ui.craft_panel.once.disabled and ui.craft_panel.status.text.contains("材料不足"),"insufficient state remains correctly disabled")
	text_bounds(ui.craft_panel);await shot("craft-insufficient")
	service.inventory.restore(original)
	ui.craft_panel.quantity.value=1
	await frames(5)
	await click(ui.craft_panel.once);await create_timer(1.65).timeout;await frames(4)
	check(ui.craft_panel.status.text.contains("制作成功"),"native painted button executes existing crafting")
	text_bounds(ui.craft_panel);await shot("craft-success")
	ui.craft_panel.choose_category("野外用品");ui.craft_panel.select_recipe("hand_supply_pouch");await frames(5)
	text_bounds(ui.craft_panel);await shot("craft-five-materials")
	for category in service.craft_book.categories():
		ui.craft_panel.choose_category(category);await frames(3)
		check(ui.craft_panel.current_category==category and not ui.craft_panel.recipe_buttons.is_empty(),"existing data-driven category "+category)
		for recipe_id in ui.craft_panel.recipe_buttons:
			ui.craft_panel.select_recipe(recipe_id);await frames(3);text_bounds(ui.craft_panel)
			for amount in [1,99]:
				ui.craft_panel.quantity.value=amount;await frames(2)
				if ui.craft_panel.panel.get_global_rect()!=fixed_craft_rect or ui.craft_panel.panel.scale!=fixed_craft_scale:geometry_failures.append(category+":"+recipe_id+":"+str(amount))
	check(geometry_failures.is_empty(),"recipe/category/quantity/feedback changes never resize or stretch crafting")
	FileAccess.open(OUT+"geometry-layout.json",FileAccess.WRITE).store_string(JSON.stringify(geometry_failures,"  "))
	var skin := preload("res://scripts/item_ui_style.gd")
	var state_margins: Array=[]
	for state in ["normal","hover","pressed","disabled","focus"]:
		var box: StyleBox=skin.button_style(state)
		var margins: Array=[]
		for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:margins.append(box.get_content_margin(side))
		state_margins.append(margins)
	check(state_margins.all(func(value):return value==state_margins[0]),"all button states reserve identical geometry")
	check(text_failures.is_empty(),"all visible titles, quantities, recipe names and button texts fit allocated width")
	FileAccess.open(OUT+"text-layout.json",FileAccess.WRITE).store_string(JSON.stringify(text_failures,"  "))
	await key(KEY_ESCAPE);check(not ui.craft_panel.visible and not world.player.input_blocked,"closing restores original player input")
	for dimensions in [Vector2i(960,540),Vector2i(1600,900)]:
		root.content_scale_size=dimensions;await frames(5)
		ui.toggle_bag();await frames(5)
		check(root.get_visible_rect().encloses(ui.bag.get_global_rect()),"bag fits logical viewport "+str(dimensions))
		await shot("inventory-"+str(dimensions.x));ui.close_panels()
		ui.toggle_craft();await frames(5)
		check(root.get_visible_rect().encloses(ui.craft_panel.panel.get_global_rect()),"crafting fits logical viewport "+str(dimensions))
		await shot("craft-"+str(dimensions.x));ui.close_panels()
	root.content_scale_size=Vector2i(1280,720)
	var failed := checks.filter(func(row):return not row.pass).size()
	var mode := "headless" if DisplayServer.get_name()=="headless" else "window"
	FileAccess.open(OUT+mode+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("UI REWORK ",mode,": ",checks.size()," checks; ",failed," failures")
	service.dirty=false;world.queue_free();await frames(5)
	quit(0 if failed==0 else 1)
