extends SceneTree
const PATH = "user://body-persistence-v1.json"
const OUT = "res://reports/body-v1/"
var checks: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	var world: Node=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	var service: Node=world.item_service
	world.environment_view.simulation.paused=true;world.player.set_physics_process(false)
	service.save_path=PATH;world.persistent_world=true
	var mode := "read" if "--read" in OS.get_cmdline_user_args() else "write"
	if mode=="write":
		service.body.health=66;service.body.hunger=23;service.body.stamina=44;service.body.build=-.34;service.body.reserve=-.7;service.body.deprivation=1.2;service.body.illness=.5;service.body.damage_clock=29;service.body.rest_clock=1.3
		service.inventory.add("field_lantern",1);service.inventory.slots[8].fuel=1234.0
		service.inventory.add("stone_pickaxe",1);service.inventory.move_slot(9,0);service.inventory.equip(0)
		service.resource_hits["persist:ore"]=3;service.consumed["persist:loose"]=true
		service.save_state();check(FileAccess.file_exists(PATH),"atomic file written")
	else:
		service.load_state()
		check(service.writable,"saved player version remains writable")
		check(service.body.health==66 and service.body.hunger==23 and service.body.stamina==44,"attributes survive process restart")
		check(is_equal_approx(service.body.build,-.34) and is_equal_approx(service.body.reserve,-.7),"body and energy reserve survive restart")
		check(service.body.illness==.5 and service.body.damage_clock==29 and service.body.deprivation==1.2,"disease interval and nutrition survive restart")
		check(service.inventory.slots[8].fuel==1234.0,"individual lamp fuel survives restart")
		check(service.inventory.get_slot(0).item_id=="stone_pickaxe" and service.inventory.has_capability("mine"),"equipped hotbar instance survives restart")
		check(service.resource_hits.get("persist:ore")==3 and service.consumed.has("persist:loose"),"harvest history survives restart")
		var data: Dictionary=service.snapshot();data.body.version=999
		var file := FileAccess.open(PATH,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
		var protected_text := FileAccess.get_file_as_string(PATH)
		service.load_state();service.dirty=true;service.save_state()
		check(not service.writable and FileAccess.get_file_as_string(PATH)==protected_text,"unknown body version refuses writes and preserves source")
		DirAccess.remove_absolute(PATH)
	var failed := checks.filter(func(row):return not row.pass).size()
	FileAccess.open(OUT+"persistence-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("BODY PERSISTENCE ",mode,": ",checks.size()," checks; ",failed," failures")
	service.dirty=false;world.queue_free()
	for i in 6:await process_frame
	quit(0 if failed==0 else 1)
