extends SceneTree
var checks: Array=[]
const OUT="res://reports/body-v1/"
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames() -> void:
	for i in 4:await process_frame
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	var world: Node=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	world.environment_view.simulation.paused=true;world.player.set_physics_process(false)
	var s: Node=world.item_service;var ui: Control=world.item_ui;var b: RefCounted=s.body
	s.inventory.add("field_lantern",1);s.toggle_lantern(8);await frames();s.burn_lantern(321)
	check(s.discard(8,1),"active lantern can be dropped through original service")
	await frames();check(not s.lantern.visible,"dropping active lamp closes light")
	var drop: Node2D
	for node in world.stream.drops:
		if is_instance_valid(node) and node.get_meta("item_id","")=="field_lantern":drop=node;break
	check(drop!=null,"lamp dropped as original world item")
	if drop!=null:
		drop.set_meta("airborne",false)
		check(s.pickup(drop),"lamp picked up using original service")
		check(s.inventory.slots[8].fuel==1479.0,"drop and pickup preserve individual fuel")
	s.inventory.add("stone_axe",1)
	for i in 40:
		if s.inventory.slots[i].get("item_id","")=="stone_axe":s.inventory.equip(i);break
	var trees := get_nodes_in_group("trees")
	check(not trees.is_empty(),"actual original tree available")
	if not trees.is_empty():
		b.stamina=100;world.stream.chop_tree(trees[0]);check(b.stamina==98.5,"actual successful tree authority spends 1.5")
	ui.body_ui.toggle();await frames()
	var frame: Rect2=ui.body_ui.paper.get_global_rect()
	for state in [[100,100,0,0,false],[90,20,.8,.5,false],[14,0,2.0,3.0,true],[70,80,.8,.5,false]]:
		b.health=state[0];b.hunger=state[1];b.illness=state[2];b.deprivation=state[3];b.down=state[4]
		ui.body_ui.refresh();await frames()
		check(ui.body_ui.paper.get_global_rect()==frame,"detail frame stays stable "+str(state))
		check(ui.body_ui.summary.get_combined_minimum_size().x<=196,"status text cannot stretch HUD "+str(state))
	ui.body_ui.close_panel();b.down=false
	var snap: Dictionary=s.snapshot()
	s.save_path="user://body-edge-protected.json";world.persistent_world=true
	for bad in [-1.0,2000.0,"broken"]:
		var altered: Dictionary=snap.duplicate(true);altered.slots[8].fuel=bad
		var file:=FileAccess.open(s.save_path,FileAccess.WRITE);file.store_string(JSON.stringify(altered));file.close()
		s.writable=true;s.load_state();check(not s.writable,"invalid lamp fuel protects source "+str(bad))
	var target := Node2D.new();root.add_child(target);target.set_meta("interaction_action","mine");target.set_meta("progress","3/7")
	check(not preload("res://scripts/world_interaction.gd").caption(target,s.inventory).contains("/"),"harvest count removed from visible caption")
	target.free();world.persistent_world=false;s.dirty=false;DirAccess.remove_absolute(s.save_path)
	var failed:=checks.filter(func(row):return not row.pass).size()
	FileAccess.open(OUT+"edges.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("BODY EDGES: ",checks.size()," checks; ",failed," failures")
	world.queue_free();await frames();quit(0 if failed==0 else 1)


