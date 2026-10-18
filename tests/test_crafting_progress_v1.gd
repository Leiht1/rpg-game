extends SceneTree
const OUT := "res://reports/crafting-progress-v1/"
const Service = preload("res://scripts/item_service.gd")
var checks: Array=[]
var finished: Array=[]
var progress_values: Array=[]
var world: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n: int=3) -> void:
	for i in n:await process_frame
func recipe_materials(service: Node, id: String, batches: int) -> void:
	var row: Dictionary=service.craft_book.recipe(id)
	for material in row.materials:service.inventory.add(str(material),int(row.materials[material])*batches)
func unit_checks() -> void:
	var service := Service.new()
	service.craft_finished.connect(func(id,times,reason):finished.append({"id":id,"times":times,"reason":reason}))
	service.craft_progress.connect(func(value):progress_values.append(value))
	check(service.craft_book.errors.is_empty(),"timed recipe definitions valid")
	for bad_time in [0,-1,"fast",31,INF]:
		var row: Dictionary=service.craft_book.recipe("hand_leaf_fiber");row.craft_time=bad_time
		check(not service.craft_book.validate(row).is_empty(),"invalid craft duration rejected "+str(bad_time))
	for pair in [["missing",1],["hand_leaf_fiber",0],["hand_leaf_fiber",100],["hand_stone_axe",1]]:
		check(not service.start_craft(pair[0],pair[1]).is_empty() and service.craft_job.is_empty(),"invalid/missing-material request never starts "+str(pair))
	recipe_materials(service,"hand_leaf_fiber",10)
	var before: Array=service.inventory.slots.duplicate(true)
	check(service.start_craft("hand_leaf_fiber",3).is_empty(),"batch begins progress")
	check(service.inventory.slots==before and progress_values.back()==0.0,"start does not consume or produce")
	service.advance_craft(.7)
	check(service.inventory.slots==before and progress_values.back()>0 and progress_values.back()<1,"partial progress does not change inventory")
	var elapsed: float=service.craft_job.elapsed
	for i in 5:check(not service.start_craft("hand_leaf_fiber",1).is_empty() and service.craft_job.elapsed==elapsed,"repeated starts cannot reset or duplicate job "+str(i))
	service.advance_craft(.8)
	check(service.craft_job.is_empty() and progress_values.back()==1.0 and service.inventory.count_item("plant_fiber")==9 and service.inventory.count_item("broad_leaf")==14,"full bar atomically commits exact complete batch")
	check(finished.size()==1 and finished.back().reason.is_empty(),"success is emitted exactly once")
	before=service.inventory.slots.duplicate(true);service.advance_craft(10);service.advance_craft(10)
	check(service.inventory.slots==before and finished.size()==1,"future frames cannot produce again")
	service.start_craft("hand_leaf_fiber",1);service.advance_craft(.5);service.cancel_craft();service.advance_craft(10)
	check(service.inventory.slots==before and finished.size()==2 and not finished.back().reason.is_empty(),"cancel before completion leaves exact inventory")
	service.start_craft("hand_leaf_fiber",1)
	for i in 40:
		if service.inventory.slots[i].get("item_id","")=="broad_leaf":service.inventory.slots[i]={}
	before=service.inventory.slots.duplicate(true);service.advance_craft(2)
	check(service.inventory.slots==before and finished.back().reason.contains("材料不足"),"completion rechecks changed ingredients without partial edits")
	for i in range(8,40):service.inventory.slots[i]={}
	service.inventory.add("broad_leaf",4);service.start_craft("hand_leaf_fiber",1)
	for i in range(9,40):service.inventory.slots[i]={"item_id":"wood","count":99}
	before=service.inventory.slots.duplicate(true);service.advance_craft(2)
	check(service.inventory.slots==before and finished.back().reason.contains("空间不足"),"completion rechecks capacity without consuming ingredients")
	for i in range(8,40):service.inventory.slots[i]={}
	service.inventory.add("broad_leaf",4);service.start_craft("hand_leaf_fiber",1);service.writable=false
	before=service.inventory.slots.duplicate(true);service.advance_craft(2)
	check(service.inventory.slots==before and finished.back().reason.contains("存档受保护"),"protected save at completion blocks exchange")
	service.writable=true
	# Progress callbacks may synchronously cancel; completion must not survive that cancellation.
	service.start_craft("hand_leaf_fiber",1)
	var cancel_on_full := func(value):
		if value>=1.0:service.cancel_craft()
	service.craft_progress.connect(cancel_on_full)
	before=service.inventory.slots.duplicate(true);service.advance_craft(2)
	check(service.inventory.slots==before and service.craft_job.is_empty(),"cancel during full-progress signal prevents stale commit")
	service.craft_progress.disconnect(cancel_on_full)
	service.free()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.max_fps=60;unit_checks();Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	var service: Node=world.item_service
	var ui: Control=world.item_ui
	world.environment_view.simulation.set_time(10);world.environment_view.simulation.paused=true
	ui.toggle_craft();ui.craft_panel.choose_category("材料加工")
	recipe_materials(service,"hand_leaf_fiber",8);await frames(5)
	var rect: Rect2=ui.craft_panel.panel.get_global_rect()
	var before: Array=service.inventory.slots.duplicate(true)
	ui.craft_panel.quantity.value=2;ui.craft_panel.submit_selected();await create_timer(.55).timeout
	check(ui.craft_panel.progress.value>0 and ui.craft_panel.progress.value<1 and service.inventory.slots==before,"actual process advances visible bar before inventory changes")
	check(ui.craft_panel.once.disabled and ui.craft_panel.batch.disabled and not ui.craft_panel.quantity.editable,"in-progress UI blocks repeated buttons and quantity changes")
	var selected: String=ui.craft_panel.selected;ui.craft_panel.choose_category("工具");ui.craft_panel.select_recipe("hand_stone_axe")
	check(ui.craft_panel.selected==selected and ui.craft_panel.current_category=="材料加工","in-progress selection stays locked")
	check(ui.craft_panel.panel.get_global_rect()==rect,"progress start keeps panel geometry")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"making.png")
	await create_timer(1.1).timeout;await frames()
	check(service.inventory.count_item("plant_fiber")==6 and ui.craft_panel.progress.value==1.0 and ui.craft_panel.status.text.contains("制作成功"),"actual clock completion produces batch and success at full bar")
	check(ui.craft_panel.panel.get_global_rect()==rect and not ui.craft_panel.once.disabled,"completion keeps frame size and restores controls")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"complete.png")
	ui.craft_panel.next_submit_ms=0;ui.craft_panel.submit(1);await create_timer(.2).timeout;before=service.inventory.slots.duplicate(true)
	ui.close_panels();await create_timer(1.6).timeout
	check(service.craft_job.is_empty() and service.inventory.slots==before and ui.craft_panel.progress.value==0,"closing UI cancels timer and preserves materials")
	check(not world.player.input_blocked,"closing timed crafting restores original world input")
	ui.toggle_craft();await frames()
	check(not ui.craft_panel.once.disabled and ui.craft_panel.progress.value==0,"reopening is idle with usable original recipe")
	var editor: LineEdit=ui.craft_panel.quantity.get_line_edit()
	editor.grab_focus();await frames(2);editor.select_all()
	var typed := InputEventKey.new();typed.physical_keycode=KEY_3;typed.keycode=KEY_3;typed.unicode=51;typed.pressed=true
	root.push_input(typed,true);await frames(2)
	check(editor.text=="3","native quantity typing reaches the focused field instead of hotbar")
	ui.craft_panel.next_submit_ms=0;ui.craft_panel.batch.pressed.emit()
	check(int(service.craft_job.get("batches",0))==3,"focused quantity text is applied before timed batch start")
	ui.close_panels()
	var failed := checks.filter(func(row):return not row.pass).size()
	var mode := "headless" if DisplayServer.get_name()=="headless" else "window"
	FileAccess.open(OUT+mode+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("CRAFT PROGRESS ",mode,": ",checks.size()," checks; ",failed," failures")
	service.dirty=false;world.queue_free();await frames(5);quit(0 if failed==0 else 1)
