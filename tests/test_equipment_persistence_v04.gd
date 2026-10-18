extends SceneTree
const PATH := "user://test-equipment-v04-process.json"
const EXPECT := "user://test-equipment-v04-process-expected.json"
var checks: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	var world=load("res://tests/world_v06_formal_fixture.gd").new()
	root.add_child(world)
	while not world.started: await process_frame
	var service: Node=world.item_service
	world.persistent_world=true
	service.save_path=PATH
	if "--write" in OS.get_cmdline_user_args():
		service.inventory.add("stone_axe",1)
		service.inventory.add("stone_pickaxe",1)
		service.inventory.equip(8)
		service.inventory.get_slot(40).state["saved_marker"]="process-restart"
		service.save_state()
		var file := FileAccess.open(EXPECT,FileAccess.WRITE)
		file.store_string(service.inventory.get_slot(40).instance_id); file.close()
		check(FileAccess.file_exists(PATH),"writer saves isolated atomic snapshot")
	else:
		service.load_state()
		var expected := FileAccess.get_file_as_string(EXPECT)
		check(service.writable and service.inventory.has_capability("chop") and not service.inventory.has_capability("mine"),"new process restores only equipped axe capability")
		check(service.inventory.get_slot(40).get("instance_id","")==expected and service.inventory.get_slot(40).get("state",{}).get("saved_marker","")=="process-restart","new process restores exact instance ID and state")
		check(service.inventory.slots[9].get("item_id","")=="stone_pickaxe" and service.inventory.slots[8].is_empty(),"new process preserves bag separately without copied axe")
		var original := FileAccess.get_file_as_string(PATH)
		var value: Dictionary=JSON.parse_string(original)
		value.equipment.head={"item_id":"missing_future_item","count":1}
		var file := FileAccess.open(PATH,FileAccess.WRITE); file.store_string(JSON.stringify(value)); file.close()
		service.load_state()
		check(service.writable and service.inventory.quarantined_equipment.has("head") and service.inventory.has_capability("chop"),"unknown equipment quarantines without breaking valid equipment")
		value=JSON.parse_string(original)
		value.slots[8]=value.equipment.main_hand.duplicate(true)
		file=FileAccess.open(PATH,FileAccess.WRITE); file.store_string(JSON.stringify(value)); file.close()
		var bad_source := FileAccess.get_file_as_string(PATH)
		service.load_state(); service.save_state()
		check(not service.writable and FileAccess.get_file_as_string(PATH)==bad_source and service.inventory.get_slot(40).instance_id==expected,"duplicated save rejects atomically and never overwrites source")
		service.writable=true
		value=JSON.parse_string(original)
		value.loose["duplicate:tool"]={"id":"duplicate:tool","item_id":"stone_axe","count":1,"x":100.0,"y":100.0,"instance":value.equipment.main_hand.duplicate(true)}
		file=FileAccess.open(PATH,FileAccess.WRITE); file.store_string(JSON.stringify(value)); file.close()
		service.load_state()
		check(not service.writable,"same equipment instance cannot also exist as a loose drop")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(EXPECT))
	world.persistent_world=false
	var failed := 0
	for row in checks:
		if not row.pass: failed+=1
	var mode := "write" if "--write" in OS.get_cmdline_user_args() else "read"
	var file := FileAccess.open("res://reports/equipment-v04/process-"+mode+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(checks,"  ")); file.close()
	print("PERSISTENCE ",mode," ",checks.size()," checks; ",failed," failures")
	world.queue_free()
	for i in 5: await process_frame
	quit(0 if failed==0 else 1)
