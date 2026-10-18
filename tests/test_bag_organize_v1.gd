extends SceneTree
const OUT := "res://reports/bag-organize-v1/"
const SAVE := "res://reports/bag-organize-v1/isolated-save.json"
var checks: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func totals(slots: Array) -> Dictionary:
	var sums := {}
	for row in slots:
		if not row.is_empty(): sums[row.item_id]=int(sums.get(row.item_id,0))+int(row.count)
	return sums
func units() -> void:
	var inv := ItemInventory.new(ItemDatabase.new())
	check(inv.organized_bag_slots()==inv.slots,"empty bag no-op")
	inv.slots[0]={"item_id":"wood","count":2};inv.slots[9]={"item_id":"wood","count":40};inv.slots[20]={"item_id":"wood","count":30}
	inv.slots[12]={"item_id":"wild_berry","count":12};inv.slots[30]={"item_id":"wild_berry","count":25}
	var before: Array=inv.slots.duplicate(true);var planned: Array=inv.organized_bag_slots()
	check(inv.slots==before,"planning has no partial live mutation")
	check(totals(planned)==totals(before) and planned[0]==before[0],"all counts and hotbar preserved")
	var woods: Array=planned.slice(8).filter(func(r):return r.get("item_id")=="wood")
	check(woods.size()==1 and woods[0].count==70,"wood merges under actual stack limit ninety-nine")
	check(planned[8].item_id=="wild_berry" and planned[8].count==30 and planned[9].count==7,"food first and stack limit thirty")
	check(planned.slice(12).all(func(r):return r.is_empty()),"empty cells packed to end")
	inv.slots.assign(planned);check(inv.organized_bag_slots()==planned,"repeated sorting idempotent")
	inv=ItemInventory.new(ItemDatabase.new());inv.slots[8]={"item_id":"wood","count":70};inv.slots[9]={"item_id":"wood","count":60}
	planned=inv.organized_bag_slots();check(planned[8].count==99 and planned[9].count==31,"material overflow splits at ninety-nine")
	inv=ItemInventory.new(ItemDatabase.new())
	for i in range(8,40): inv.slots[i]={"item_id":"wood","count":1}
	planned=inv.organized_bag_slots();check(planned[8].count==32 and planned.slice(9).all(func(r):return r.is_empty()),"full bag can consolidate")
	inv=ItemInventory.new(ItemDatabase.new())
	var first: Dictionary=inv.instance("stone_pickaxe");first.durability=27;first.state={"test":"first"}
	var second: Dictionary=inv.instance("stone_pickaxe");second.durability=86
	inv.slots[9]=first;inv.slots[11]=second
	inv.slots[16]={"item_id":"field_lantern","count":1,"lamp_id":"lamp-a","fuel":400.0}
	inv.slots[24]={"item_id":"field_lantern","count":1,"lamp_id":"lamp-b","fuel":1100.0}
	inv.equipment.main_hand=inv.instance("stone_axe");inv.hotbar_equipment={"2":inv.equipment.main_hand.instance_id}
	var links: Dictionary=inv.hotbar_equipment.duplicate(true);var equipment: Dictionary=inv.equipment.duplicate(true)
	planned=inv.organized_bag_slots()
	check(planned[8]==first and planned[9]==second,"same tools remain two unchanged instances in stable order")
	check(planned[10].lamp_id=="lamp-a" and planned[10].fuel==400 and planned[11].lamp_id=="lamp-b" and planned[11].fuel==1100,"lamps retain individual identity fuel and order")
	check(inv.equipment==equipment and inv.hotbar_equipment==links and planned[2].is_empty(),"equipped hotbar alias unchanged")
	inv=ItemInventory.new(ItemDatabase.new());inv.slots[8]={"item_id":"wood","count":2,"state":{"quality":1}};inv.slots[9]={"item_id":"wood","count":3,"state":{"quality":2}}
	planned=inv.organized_bag_slots();check(not planned[9].is_empty() and planned[8].count==2 and planned[9].count==3,"different metadata never coalesces")
func run() -> void:
	units();Engine.set_meta("integration_seed",271828)
	var world: Node=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	var s = world.item_service;var ui = world.item_ui;var inv = s.inventory
	world.environment_view.simulation.paused=true;world.player.set_physics_process(false)
	if "--read" in OS.get_cmdline_user_args():
		world.persistent_world=true;s.save_path=SAVE;s.load_state()
		check(s.writable and inv.count_item("wood")==72 and inv.slots[8].item_id=="wild_berry" and inv.slots[8].count==30,"independent process restores organized counts and placement")
		check(inv.slots[0].item_id=="wood" and inv.slots[0].count==2 and inv.hotbar_equipment.has("2") and inv.has_capability("chop"),"restart retains hotbar and equipment references")
		check(inv.slots.filter(func(r):return r.get("item_id")=="stone_pickaxe").map(func(r):return r.durability)==[27,86],"restart retains both tool durabilities")
		check(inv.slots.filter(func(r):return r.get("item_id")=="field_lantern").map(func(r):return r.fuel)==[400.0,1100.0],"restart retains two lamps without duplication")
		finish(world,"restart");return
	inv.slots[0]={"item_id":"wood","count":2};inv.slots[9]={"item_id":"wood","count":40};inv.slots[20]={"item_id":"wood","count":30}
	inv.slots[12]={"item_id":"wild_berry","count":12};inv.slots[30]={"item_id":"wild_berry","count":25}
	inv.slots[22]=inv.instance("stone_pickaxe");inv.slots[22].durability=27
	inv.slots[25]=inv.instance("stone_pickaxe");inv.slots[25].durability=86
	inv.slots[16]={"item_id":"field_lantern","count":1,"lamp_id":"lamp-a","fuel":400.0}
	inv.slots[24]={"item_id":"field_lantern","count":1,"lamp_id":"lamp-b","fuel":1100.0}
	inv.equipment.main_hand=inv.instance("stone_axe");inv.hotbar_equipment={"2":inv.equipment.main_hand.instance_id}
	s.toggle_lantern(16)
	var before: Array=inv.slots.duplicate(true)
	world.persistent_world=true;s.save_path="res://reports/bag-organize-v1/missing-folder/save.json"
	check(not s.organize_bag().is_empty() and inv.slots==before,"failed save rolls back whole sort")
	world.persistent_world=false;s.writable=false
	check(not s.organize_bag().is_empty() and inv.slots==before,"protected source blocks sort")
	s.writable=true;s.craft_job={"test":true}
	check(not s.organize_bag().is_empty() and inv.slots==before,"active craft blocks sort")
	s.craft_job={};world.player.action="throw"
	check(not s.organize_bag().is_empty() and inv.slots==before,"active throw blocks stale source relocation")
	world.player.action="";s.body.sleeping=true
	check(not s.organize_bag().is_empty() and inv.slots==before,"sleep blocks sort")
	s.body.sleeping=false;ui.toggle_bag();await frames()
	ui.open_item_menu(12,Vector2(500,300));ui.organize_button.pressed.emit()
	check(inv.slots==before,"open item modal blocks sort")
	ui.close_item_actions();ui.organize_button.pressed.emit()
	check(inv.slots[8].item_id=="wild_berry" and inv.slots[8].count==30 and totals(inv.slots)==totals(before),"actual button merges and sorts without count changes")
	check(s.lantern.visible and s.active_lamp=="lamp-a" and s.lamp_slot().fuel==400,"lit lamp follows identity after relocation")
	s.burn_lantern(1);check(s.lamp_slot().fuel==399,"same lamp burns after relocation")
	s.lamp_slot().fuel=400
	var ordered: Array=inv.slots.duplicate(true);ui.organize_button.pressed.emit()
	check(inv.slots==ordered,"repeated button idempotent")
	var all: Array=ui.body_ui.hud.find_children("*","TextureRect",true,false)
	check(all.size()==4 and all[3].texture.resource_path=="res://assets/ui/body_v2/energy.png" and not Engine.has_meta("energy_icon_preview"),"formal energy PNG without preview switch")
	check(not ui.body_ui.paper.find_children("*","Button",true,false).any(func(n):return n.text.contains("睡眠")),"no sleep button reintroduced")
	world.persistent_world=true;s.save_path=SAVE
	check(s.save_state(),"organized full snapshot saved atomically for restart")
	world.persistent_world=false
	for size in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=size;root.content_scale_size=size;ui.fit_core_ui();await frames(6)
		var rect: Rect2=ui.organize_button.get_global_rect()
		check(rect.position.x>=0 and rect.end.x<=size.x and rect.end.y<=size.y,"sort button fits viewport %s"%size)
		check(ui.bag.get_global_rect().encloses(rect) and not rect.intersects(ui.cells[8].get_global_rect()),"header button clear of slots %s"%size)
		var stable: Vector2=ui.bag.size;ui.organize_button.pressed.emit();await frames()
		check(ui.bag.size==stable,"sorting does not resize bag %s"%size)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"bag-%d.png"%size.x)
	ui.close_panels();await frames()
	if DisplayServer.get_name()!="headless":
		ui.body_ui.refresh();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"formal-energy.png")
	finish(world,"headless" if DisplayServer.get_name()=="headless" else "window")
func finish(world: Node,mode: String) -> void:
	var failed := checks.filter(func(row):return not row.pass).size()
	FileAccess.open(OUT+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("BAG ORGANIZE ",mode,": ",checks.size()," checks; ",failed," failures")
	world.persistent_world=false;world.item_service.dirty=false;world.queue_free();await frames(6);quit(0 if failed==0 else 1)
