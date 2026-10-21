extends SceneTree
const OUT := "res://reports/crafting-v1/"
const Service = preload("res://scripts/item_service.gd")
var checks: Array=[]
var world: Node
var ui: Control
var service: Node
var emissions := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func same(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))
func key(code: int) -> void:
	var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	root.push_input(event,true);await frames(2)
	event=InputEventKey.new();event.keycode=code;event.physical_keycode=code
	root.push_input(event,true);await frames(2)
func click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new();motion.position=at;root.push_input(motion,true)
	await frames(2)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		root.push_input(event,true);await frames(2)
func shot(name_value: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name_value+".png")
func empty() -> void:
	for i in 40: service.inventory.slots[i]={}
	service.inventory.equipment={};service.inventory.hotbar_equipment={}
	service.inventory.changed.emit()
func grant_recipe(id: String, times: int) -> void:
	var row: Dictionary=service.craft_book.recipe(id)
	for material in row.materials: service.inventory.add(str(material),int(row.materials[material])*times)
func atomic_tests() -> void:
	var s := Service.new()
	var book: RefCounted=s.craft_book
	check(s.database.errors.is_empty() and book.errors.is_empty() and book.recipes.size()==preload("res://tests/current_test_contract.gd").recipe_count(),"five valid real recipes, no invalid items")
	check(book.recipe("hand_supply_pouch").is_empty() and book.available("全部").all(func(row):return row.output_id!="supply_pouch"),"supply pouch absent from craftable list")
	check(not s.start_craft("hand_supply_pouch",1).is_empty() and s.craft_job.is_empty(),"removed pouch recipe cannot start progress")
	check(book.categories()==["全部","工具","野外用品","材料加工"],"categories derive from actual recipes")
	var bad: Dictionary=book.recipe("hand_stone_axe")
	bad.output_id="missing"
	check(not book.validate(bad).is_empty(),"invalid output rejected")
	bad=book.recipe("hand_stone_axe");bad.materials={"missing":1}
	check(not book.validate(bad).is_empty(),"invalid ingredient rejected")
	bad=book.recipe("hand_stone_axe");bad.output_count=1.5
	check(not book.validate(bad).is_empty(),"fractional output rejected")
	bad=book.recipe("hand_stone_axe");bad.materials.branch=-1
	check(not book.validate(bad).is_empty(),"negative ingredient rejected")
	for id in book.recipes:
		var inv := ItemInventory.new(s.database)
		var row: Dictionary=book.recipe(id)
		var mats := {}
		for ingredient in row.materials:
			mats[ingredient]=int(row.materials[ingredient])*3
			inv.add(str(ingredient),mats[ingredient])
		var original: Array=inv.slots.duplicate(true)
		check(inv.craft_exchange(mats,row.output_id,int(row.output_count)*3).is_empty() and inv.slots==original,"preview does not mutate "+id)
		emissions=0
		inv.changed.connect(func():emissions+=1)
		check(inv.craft_exchange(mats,row.output_id,int(row.output_count)*3,true).is_empty(),"batch commits "+id)
		check(emissions==1 and inv.count_item(row.output_id)==int(row.output_count)*3,"exact batch output and one inventory signal "+id)
		for ingredient in mats:
			if ingredient!=row.output_id: check(inv.count_item(str(ingredient))==0,"exact ingredient consumption "+id+":"+ingredient)
		if s.database.item(row.output_id).get("equippable",false):
			var ids := {}
			for slot in inv.slots:
				if slot.get("item_id","")==row.output_id: ids[slot.instance_id]=true;check(slot.count==1,"tool count remains one "+id)
			check(ids.size()==3,"three distinct instance identities "+id)
		check(inv.slots.slice(0,8).all(func(slot):return slot.is_empty()),"no automatic assignment of hotbar "+id)
	var inv: ItemInventory=s.inventory
	inv.add("broad_leaf",10)
	var original: Array=inv.slots.duplicate(true)
	for pair in [["hand_supply_pouch",1],["missing",1],["hand_leaf_fiber",0],["hand_leaf_fiber",100],["hand_stone_axe",1]]:
		check(not s.craft(str(pair[0]),int(pair[1]),s.new_craft_request()).is_empty() and inv.slots==original,"invalid/missing-material failure preserves inventory "+str(pair))
	var request: int=s.new_craft_request()
	check(s.craft("hand_leaf_fiber",2,request).is_empty(),"service transaction succeeds")
	original=inv.slots.duplicate(true)
	for i in 8: check(not s.craft("hand_leaf_fiber",2,request).is_empty() and inv.slots==original,"duplicate request cannot produce output "+str(i))
	s.writable=false
	check(not s.craft("hand_leaf_fiber",1,s.new_craft_request()).is_empty() and inv.slots==original,"protected save blocks crafting")
	s.writable=true
	book.recipes.hand_leaf_fiber.conditions=["workbench"]
	check(not s.craft_check("hand_leaf_fiber",1).is_empty(),"future facility conditions do not bypass")
	book.recipes.hand_leaf_fiber.conditions=[]
	# Full bag, including materials split over stacks. First attempt cannot partially add.
	for i in range(8,40):inv.slots[i]={"item_id":"wood","count":99}
	inv.slots[8]={"item_id":"broad_leaf","count":5};inv.slots[9]={"item_id":"plant_fiber","count":98}
	original=inv.slots.duplicate(true)
	check(not s.craft("hand_leaf_fiber",1,s.new_craft_request()).is_empty() and inv.slots==original,"full bag rollback includes would-be partial stack")
	inv.slots[8].count=2
	check(s.craft("hand_leaf_fiber",1,s.new_craft_request()).is_empty() and inv.count_item("plant_fiber")==101,"freed ingredient slot holds remainder after existing stack")
	for i in range(8,40):inv.slots[i]={"item_id":"wood","count":99}
	inv.slots[8]={"item_id":"broad_leaf","count":10};inv.slots[9]={"item_id":"plant_fiber","count":96}
	check(s.craft("hand_leaf_fiber",1,s.new_craft_request()).is_empty() and inv.slots[9].count==99,"full bag uses existing stack room")
	var reentrant := {"reason":"","count":0}
	var callback := func():
		reentrant.count+=1
		reentrant.reason=s.craft("hand_leaf_fiber",1,s.new_craft_request())
	inv.changed.connect(callback,CONNECT_ONE_SHOT)
	inv.slots[9].count=90
	check(s.craft("hand_leaf_fiber",1,s.new_craft_request()).is_empty() and not reentrant.reason.is_empty() and reentrant.count==1,"signal reentry cannot submit another transaction")
	s.free()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.max_fps=60
	atomic_tests()
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	service=world.item_service;ui=world.item_ui
	world.environment_view.simulation.set_time(10);world.environment_view.simulation.paused=true
	world.player.automated=true
	await frames(10)
	check(ui.cells.size()==43,"original 40 storage and three equipment controls retained")
	check(ui.bag.get_theme_stylebox("panel") is StyleBoxTexture and ui.cells[8].get_theme_stylebox("panel") is StyleBoxTexture,"formal bag and slots use generated texture styles")
	var card: Control=ui.make_item_card(8)
	check(card.get_theme_stylebox("panel") is StyleBoxTexture,"tooltip uses same generated panel art")
	card.free()
	await key(KEY_C)
	check(ui.craft_panel.visible and world.player.input_blocked,"C opens crafting and blocks player")
	var before_position: Vector2=world.player.position
	world.player.input_override=Vector2.RIGHT
	await key(KEY_E);await frames(6)
	check(world.player.position==before_position and world.player.action.is_empty(),"crafting blocks movement and E interaction")
	world.player.input_override=Vector2.ZERO
	await click(ui.craft_panel.category_buttons["材料加工"].get_global_rect().get_center())
	check(ui.craft_panel.current_category=="材料加工" and ui.craft_panel.recipe_buttons.size()==1,"native mouse selects data-driven category")
	check(ui.craft_panel.once.disabled and ui.craft_panel.status.text.contains("材料不足"),"insufficient ingredients disable button and explain")
	service.inventory.add("broad_leaf",12)
	await frames()
	check(not ui.craft_panel.once.disabled,"inventory signal updates recipe without polling")
	ui.craft_panel.quantity.value=3
	await click(ui.craft_panel.batch.get_global_rect().get_center())
	await create_timer(1.65).timeout
	check(service.inventory.count_item("plant_fiber")==9 and service.inventory.count_item("broad_leaf")==6,"native batch click exact quantities")
	await shot("crafting-materials")
	await frames(13)
	await click(ui.craft_panel.once.get_global_rect().get_center())
	await create_timer(1.65).timeout
	check(service.inventory.count_item("plant_fiber")==12 and service.inventory.count_item("broad_leaf")==4,"native single craft ignores selected batch size")
	ui.craft_panel.next_submit_ms=0
	ui.craft_panel.submit(1);ui.craft_panel.submit(1)
	await create_timer(1.65).timeout
	check(service.inventory.count_item("plant_fiber")==15 and service.inventory.count_item("broad_leaf")==2,"UI suppresses accidental rapid repeat")
	for row in service.craft_book.available():grant_recipe(row.recipe_id,2)
	ui.craft_panel.choose_category("全部");ui.craft_panel.select_recipe("hand_stone_axe");ui.craft_panel.quantity.value=1
	await frames(5);await shot("crafting-tools")
	await key(KEY_M)
	check(world.map_view.visible and not ui.craft_panel.visible and world.player.input_blocked,"M transitions from crafting to original map")
	await key(KEY_M);await key(KEY_C);await key(KEY_ESCAPE)
	check(not ui.craft_panel.visible and not world.player.input_blocked,"Esc restores world input")
	# Craft real tool instances, then exercise original hotbar/equipment capabilities.
	for pair in [["hand_stone_axe","stone_axe","chop"],["hand_stone_pickaxe","stone_pickaxe","mine"],["hand_simple_shovel","simple_shovel","dig"]]:
		check(service.craft(pair[0],1,service.new_craft_request()).is_empty(),"world crafts "+pair[1])
		var index := -1
		for i in range(8,40):
			if service.inventory.slots[i].get("item_id","")==pair[1]:index=i;break
		check(index>=8 and service.inventory.move_slot(index,0) and service.inventory.use_slot(0) and service.inventory.has_capability(pair[2]),"crafted tool moves to hotbar and equips original capability "+pair[2])
		check(service.inventory.get_slot(0).instance_id==service.inventory.equipment.main_hand.instance_id,"crafted tool keeps one hotbar equipment reference "+pair[1])
		service.inventory.unequip(40)
		service.inventory.move_slot(0,index)
	check(service.craft("hand_field_lantern",1,service.new_craft_request()).is_empty(),"real usable lantern crafted")
	var lamp_index := -1
	for i in 40:
		if service.inventory.slots[i].get("item_id","")=="field_lantern":lamp_index=i;break
	check(service.inventory.use_slot(lamp_index) and is_instance_valid(service.lantern) and service.lantern.visible,"original use interface turns light on")
	await frames()
	check(float(world.environment_view.material_effect.get_shader_parameter("lantern_strength"))==1.0,"lantern drives actual world illumination")
	world.environment_view.simulation.set_time(0)
	await frames(4);await shot("lantern-night")
	service.inventory.use_slot(lamp_index)
	check(not service.lantern.visible,"second use turns light off without consuming")
	world.environment_view.simulation.set_time(10)
	ui.toggle_bag();await frames(6);await shot("inventory-equipment")
	ui.show_item_hover(lamp_index);await create_timer(.22).timeout;await frames(3);await shot("tooltip")
	check(is_instance_valid(ui.hover_card) and root.get_visible_rect().encloses(ui.hover_card.get_global_rect()),"tooltip stays in viewport")
	ui.close_panels()
	# Isolated real atomic save and restore; does not touch user's normal save.
	world.persistent_world=true;service.save_path="user://test-crafting-v1-roundtrip.json"
	service.resource_hits["craft-test:buried"]=2;service.consumed["craft-test:pickup"]=true
	var snapshot: Dictionary=service.snapshot().duplicate(true)
	service.save_state()
	service.inventory.slots[8]={}
	service.load_state()
	if not service.writable:
		var debug_file := FileAccess.open(OUT+"failed-roundtrip.json",FileAccess.WRITE);debug_file.store_string(JSON.stringify(snapshot,"  "));debug_file.close()
		var restored := ItemInventory.new(service.database)
		var parsed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(service.save_path))
		print("ROUNDTRIP diagnostic slots=",restored.restore(parsed.slots)," equipment=",restored.restore_equipment(parsed.equipment)," saved keys=",parsed.keys())
	var expected_file := FileAccess.open(OUT+"roundtrip-before.json",FileAccess.WRITE);expected_file.store_string(JSON.stringify(snapshot,"  "));expected_file.close()
	var actual_file := FileAccess.open(OUT+"roundtrip-after.json",FileAccess.WRITE);actual_file.store_string(JSON.stringify(service.snapshot(),"  "));actual_file.close()
	var expected_equipment: Dictionary=snapshot.equipment.duplicate(true)
	for equip_key in expected_equipment.keys():
		if expected_equipment[equip_key].is_empty(): expected_equipment.erase(equip_key)
	check(service.writable and same(service.inventory.slots,snapshot.slots) and same(service.inventory.equipment,expected_equipment),"atomic roundtrip retains crafted inventory and equipment")
	check(same(service.resource_hits,snapshot.resource_hits) and same(service.consumed,snapshot.consumed) and same(service.loose,snapshot.loose),"crafting keeps world resource and drop state")
	world.persistent_world=false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.save_path))
	# Rendering and hit areas at smaller and larger logical viewport dimensions.
	for dimensions in [preload("res://tests/current_test_contract.gd").viewport_size()]:
		root.content_scale_size=dimensions
		await frames(5)
		ui.toggle_craft();await frames(4)
		check(root.get_visible_rect().encloses(ui.craft_panel.panel.get_global_rect()),"craft panel fits viewport "+str(dimensions))
		check(root.get_visible_rect().encloses(ui.dock.get_global_rect()),"HUD fits viewport "+str(dimensions))
		await shot("size-"+str(dimensions.x))
		ui.close_panels()
	root.content_scale_size=Vector2i(1280,720)
	var failed := checks.filter(func(row):return not row.pass).size()
	var mode := "headless" if DisplayServer.get_name()=="headless" else "window"
	var file := FileAccess.open(OUT+mode+"-tests.json",FileAccess.WRITE);file.store_string(JSON.stringify(checks,"  "));file.close()
	print("CRAFTING V1 ",mode,": ",checks.size()," checks, ",failed," failures")
	world.queue_free();await frames(6)
	quit(0 if failed==0 else 1)
