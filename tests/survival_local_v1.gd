extends Node
class LocalWorld extends "res://scripts/world.gd":
	func load_world_identity(_path: String=WORLD_ID_PATH) -> void:
		persistent_world=false;world_seed=271828;map_cells=1536;world_id="survival-local-v1-test"
	func parse_arguments() -> void:pass
var checks:=0
const OUT="res://reports/.tmp/survival-local-v1/"
func verify(ok: bool, label: String) -> void:
	if not ok:push_error("FAIL "+label);get_tree().quit(1)
	assert(ok,label);checks+=1
func frames(count: int=4) -> void:
	for i in count:await get_tree().process_frame
func key(code: int) -> void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e)
	await frames()
	e.pressed=false;Input.parse_input_event(e);await frames()
func capture(name_value: String) -> void:
	await get_tree().create_timer(.25).timeout
	get_viewport().get_texture().get_image().save_png(OUT+name_value+".png")
func _ready() -> void:run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var world:=LocalWorld.new();add_child(world)
	for i in 900:
		await get_tree().process_frame
		if world.started:break
	verify(world.started,"local world loaded")
	await frames(10)
	var items=world.item_service;var ui=world.item_ui;var inv=items.inventory
	verify(items.database.errors.is_empty(),"item definitions")
	verify(inv.slots[8].get("item_id")=="survival_guide","one guide in bag")
	verify(inv.count_item("survival_guide")==1 and items.guide_stage==0,"first entry")
	verify(ui.guide.ring.visible,"persistent initial hint")
	await key(KEY_D);verify(items.guide_stage==0,"unrelated key does not complete hint")
	await capture("01-open-bag-hint")
	await key(KEY_B);verify(ui.bag.visible and items.guide_stage==1,"B advances to guide hint")
	verify(ui.guide.caption.text.contains("右键"),"right click instruction")
	verify(ui.guide.caption.get_global_rect().position.y>=0,"guide instruction not clipped")
	await capture("02-guide-hint")
	var pending: Dictionary=items.snapshot()
	items.guide_stage=2;items.load_state("",false,pending);await frames()
	verify(items.guide_stage==1 and ui.guide.ring.visible,"unfinished guide persists after restore")
	var click:=InputEventMouseButton.new()
	click.position=ui.cells[8].get_global_rect().get_center();click.global_position=click.position
	click.button_index=MOUSE_BUTTON_RIGHT;click.pressed=true
	get_viewport().push_input(click,true);await frames()
	click.pressed=false;get_viewport().push_input(click,true);await frames()
	verify(ui.item_menu.visible,"native right click opens item menu")
	verify(ui.use_button.text=="查看" and not ui.destroy_button.visible,"view only menu")
	verify(not inv.destroy_slot(8) and inv.count_item("survival_guide")==1,"destroy protection")
	verify(not items.discard(8),"discard protection")
	ui.use_button.pressed.emit();await frames()
	verify(ui.guide.letter.visible and items.guide_stage==2,"view opens letter and completes")
	verify(world.player.input_blocked and not ui.guide.ring.visible,"letter blocks actions, hint gone")
	verify(ui.guide.handwriting.get_font_name().contains("WenKai"),"handwriting font loaded")
	verify(ui.bag_button.size.x>=76 and ui.map_button.size.x>=76,"B and M button width")
	verify(ui.hotbar_note.get_global_rect().end.y<=720,"hotbar note inside default window")
	await capture("03-letter")
	await key(KEY_B);verify(ui.guide.letter.visible,"letter consumes bag key")
	await key(KEY_ESCAPE);verify(not ui.guide.letter.visible,"Esc closes letter")
	verify(inv.count_item("survival_guide")==1,"reading never consumes letter")
	var snapshot: Dictionary=items.snapshot()
	verify(snapshot.guide_stage==2 and snapshot.tree_balance_version==2,"persisted flags")
	items.guide_stage=0;items.load_state("",false,snapshot);await frames()
	verify(items.writable and items.guide_stage==2 and not ui.guide.ring.visible,"restore complete, no repeat hint")
	# A real isolated disk snapshot is read by a separate process on the second run.
	var disk_path:=OUT+"items.json"
	if OS.get_cmdline_user_args().has("--reload"):
		var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(disk_path))
		items.load_state("",false,disk);await frames()
		verify(items.guide_stage==2 and inv.count_item("survival_guide")==1 and not ui.guide.ring.visible,"new process persistence")
	else:
		var file:=FileAccess.open(disk_path,FileAccess.WRITE);file.store_string(JSON.stringify(snapshot));file.close()
	# Historical tree progress is rescaled once; the next save must not scale again.
	var legacy:=snapshot.duplicate(true);legacy.erase("tree_balance_version");legacy.erase("guide_stage")
	legacy.tree_hits={"test-big":6,"test-small":5}
	items.load_state("",false,legacy)
	verify(world.stream.tree_hits["test-big"]==4 and world.stream.tree_hits["test-small"]==3,"old tree progress migration")
	verify(items.guide_stage==2,"existing characters not forced through onboarding")
	var migrated: Dictionary=items.snapshot();items.load_state("",false,migrated)
	verify(world.stream.tree_hits["test-big"]==4,"migration not repeated")
	var invalid:=snapshot.duplicate(true);invalid.guide_stage=9
	items.load_state("",false,invalid)
	verify(not items.writable,"invalid guide progress protects save")
	items.writable=true
	invalid=snapshot.duplicate(true);invalid.tree_balance_version=3
	items.load_state("",false,invalid)
	verify(not items.writable,"future tree revision protects save")
	items.writable=true
	items.load_state("",false,snapshot)
	# Moving and sorting use the same inventory and preserve the unique letter.
	verify(inv.move_slot(8,0),"guide can move into hotbar")
	await key(KEY_ESCAPE);await key(KEY_1)
	verify(ui.guide.letter.visible and inv.count_item("survival_guide")==1,"hotbar reads letter")
	ui.guide.close_letter();ui.close_panels()
	world.player.set_physics_process(false)
	var p: Vector2=world.player.position
	for kind in ["flint_outcrop","stone_outcrop","copper_outcrop","silver_outcrop","gold_outcrop"]:
		items.body.stamina=100;items.body.energy=100;items.body.exhausted=false
		inv.equipment.main_hand=inv.instance("stone_pickaxe")
		var id: String="local-balance:"+kind
		var target: Node2D=items.create_harvest(id,{"kind":kind,"x":p.x+34,"y":p.y})
		await frames()
		world.player.action="mine"
		var hits: int={"flint_outcrop":4,"stone_outcrop":5,"copper_outcrop":6,"silver_outcrop":7,"gold_outcrop":8}[kind]
		verify(int(target.definition.hits)==hits,"configured hits "+kind)
		for hit in range(1,hits+1):
			verify(items.harvest_hit(target,"mine"),"accepted mine hit "+kind)
			verify(items.consumed.has(id)==(hit==hits),"depleted at exact hit "+kind)
		var expected: Dictionary=target.definition.drops.duplicate(true)
		if kind=="stone_outcrop":
			expected.stone=12+int(abs(id.hash())%5)
			if abs((id+":flint").hash())%10<3:expected.flint=1
		var rewards:={}
		for row in items.loose.values():
			if str(row.id).begins_with(id+":loot:"):rewards[row.item_id]=int(row.count)
		for reward in expected:expected[reward]=int(expected[reward])
		verify(rewards==expected,"unchanged reward batch "+kind)
		verify(not items.harvest_hit(target,"mine"),"no repeated payout "+kind)
		world.player.cancel_action();target.queue_free();await frames()
	print("SURVIVAL_LOCAL_PASS checks=",checks)
	world.queue_free();await frames(12);get_tree().quit()
