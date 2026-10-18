extends SceneTree
const PATH := "user://campfire-v1-test.json"
var checks: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	var world: Node=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	world.environment_view.simulation.paused=true;world.player.set_physics_process(false)
	var service: Node=world.item_service
	service.save_path=PATH;world.persistent_world=true;service.load_state()
	var camps: RefCounted=service.camps
	check(service.writable and camps.states.size()==1,"independent process restores one camp")
	if camps.states.size()!=1:quit(1);return
	var id: String=camps.states.keys()[0]
	var row: Dictionary=camps.states[id]
	world.player.position=Vector2(row.x,row.y)+Vector2(0,75)
	check(service.inventory.has_capability("mine") and service.inventory.get_slot(1).item_id=="stone_pickaxe","equipped hotbar instance retained across process")
	check(service.resource_hits.get("camp:test:ore")==2 and service.consumed.has("camp:test:pickup"),"harvest histories retained across process")
	var mode := "mid"
	if "--ready" in OS.get_cmdline_user_args():mode="ready"
	if "--claimed" in OS.get_cmdline_user_args():mode="claimed"
	if mode=="mid":
		check(row.recipe=="roast_carrot" and row.elapsed==5 and row.lit and row.fuel>0,"mid-cooking progress fuel and ignition restored after process restart")
		check(service.inventory.count_item("wild_carrot")==0,"already committed raw ingredient remains consumed")
		camps.advance(7)
		check(row.ready and row.elapsed==12,"restored job completes from saved progress")
		service.save_state()
	elif mode=="ready":
		check(row.ready and row.recipe=="roast_carrot","unclaimed product survives another process restart")
		check(camps.act(id,"claim").is_empty(),"saved ready product can be claimed")
		check(service.inventory.count_item("roasted_carrot")==2,"claim adds exactly one to existing cooked stack")
	else:
		check(row.recipe.is_empty() and not row.ready,"claimed state survives process restart")
		check(not camps.act(id,"claim").is_empty() and service.inventory.count_item("roasted_carrot")==2,"claimed food cannot be regenerated or claimed again")
		DirAccess.remove_absolute(PATH)
	var failed: int=checks.filter(func(entry):return not entry.pass).size()
	FileAccess.open("res://reports/campfire-v1/persistence-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("CAMPFIRE PERSISTENCE ",mode,": ",checks.size()," checks; ",failed," failures")
	world.persistent_world=false;service.dirty=false;world.queue_free()
	for i in 6:await process_frame
	quit(0 if failed==0 else 1)
