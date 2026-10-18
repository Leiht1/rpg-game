extends SceneTree
const PATH := "user://crafting-v1-restart.json"
const EXPECTED := "user://crafting-v1-restart-expected.json"
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func normalized(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	var world: Node=load("res://tests/world_v06_formal_fixture.gd").new()
	root.add_child(world)
	while not world.started:await process_frame
	var service: Node=world.item_service
	world.persistent_world=true;service.save_path=PATH
	var write := "--write" in OS.get_cmdline_user_args()
	if write:
		for id in ["hand_stone_axe","hand_stone_pickaxe","hand_simple_shovel","hand_field_lantern"]:
			var row: Dictionary=service.craft_book.recipe(id)
			for material in row.materials:service.inventory.add(str(material),int(row.materials[material]))
			check(service.craft(id,1,service.new_craft_request()).is_empty(),"writer crafts "+id)
		check(service.inventory.add("supply_pouch",1)==0,"writer retains acquired supply pouch")
		for i in 40:
			if service.inventory.slots[i].get("item_id","")=="stone_pickaxe":service.inventory.move_slot(i,2);break
		service.inventory.use_slot(2)
		service.inventory.equipment.main_hand.state["restart_marker"]="crafted-tool"
		service.resource_hits["craft-restart:dig"]=2
		service.consumed["craft-restart:pickup"]=true
		service.inventory.add("broad_leaf",4)
		check(service.start_craft("hand_leaf_fiber",2).is_empty(),"writer starts unfinished timed operation")
		service.save_state()
		check(not service.snapshot().has("craft_job"),"pending timer is not written to save")
		FileAccess.open(EXPECTED,FileAccess.WRITE).store_string(JSON.stringify(service.snapshot()))
		check(FileAccess.file_exists(PATH),"writer persists isolated atomic save")
	else:
		service.load_state()
		var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
		check(service.writable and normalized(service.snapshot())==expected,"fresh process restores exact crafted snapshot")
		check(service.inventory.has_capability("mine") and service.inventory.get_slot(2).instance_id==service.inventory.equipment.main_hand.instance_id,"fresh process preserves hotbar reference and tool ability")
		check(service.inventory.equipment.main_hand.state.get("restart_marker","")=="crafted-tool","tool instance state survives restart")
		check(service.inventory.count_item("field_lantern")==1 and not is_instance_valid(service.lantern),"lantern item persists; session light defaults off")
		check(not expected.has("recipes") and not expected.has("craft_selection"),"static recipes and UI state do not pollute save")
		check(service.craft_job.is_empty() and service.inventory.count_item("broad_leaf")==4 and service.inventory.count_item("plant_fiber")==0,"restart cancels unfinished progress without spending materials or producing output")
		check(service.inventory.count_item("supply_pouch")==1,"acquired pouch survives restart without a recipe")
		var original := FileAccess.get_file_as_string(PATH)
		var bad: Dictionary=expected.duplicate(true);bad.version=999
		FileAccess.open(PATH,FileAccess.WRITE).store_string(JSON.stringify(bad))
		var protected_source := FileAccess.get_file_as_string(PATH)
		service.load_state();service.save_state()
		check(not service.writable and FileAccess.get_file_as_string(PATH)==protected_source,"future save protection still prevents overwrite")
		var before: Array=service.inventory.slots.duplicate(true)
		check(not service.craft("hand_leaf_fiber",1,service.new_craft_request()).is_empty() and service.inventory.slots==before,"protected load also prevents new crafting edits")
		FileAccess.open(PATH,FileAccess.WRITE).store_string(original)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(EXPECTED))
	world.persistent_world=false;service.dirty=false
	var failed := checks.filter(func(row):return not row.pass).size()
	var mode := "write" if write else "read"
	FileAccess.open("res://reports/crafting-v1/restart-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("CRAFT RESTART ",mode,": ",checks.size()," checks; ",failed," failures")
	world.queue_free()
	for i in 5:await process_frame
	quit(0 if failed==0 else 1)
