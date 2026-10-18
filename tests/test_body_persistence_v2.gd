extends SceneTree
const OUT = "res://reports/body-v2/"
const PATH = "res://reports/body-v2/isolated-save.json"
var checks: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	var world: Node=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	var s = world.item_service;var v = world.environment_view;var env = v.simulation
	v.set_process(false);env.paused=false;world.player.set_physics_process(false)
	s.save_path=PATH;world.persistent_world=true
	var mode := "write"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode=arg.trim_prefix("--mode=")
	if mode=="write":
		s.inventory.add("wild_carrot",4);s.inventory.add("stone_pickaxe",1);s.inventory.equip(9)
		s.resource_hits["body-v2:test"]=3;s.consumed["body-v2:collected"]=true
		s.body.energy=0;s.body.start_sleep(1320,true);env.minute=1320
		s.camps.states["body-v2:fire"]={"x":world.player.position.x+80,"y":world.player.position.y,"fuel":1000.0,"lit":true,"recipe":"roast_carrot","elapsed":0.0,"ready":false}
		s.camps.burning["body-v2:fire"]=true
		s.builds.states["body-v2:floor"]=s.builds.candidate("wood_floor",world.player.position+Vector2(192,128),false,true,0)
		v.advance_gameplay(150)
		check(s.body.sleeping and is_equal_approx(s.body.sleep_elapsed,60),"one sleeping hour before save")
		check(s.save_state(),"atomic actual file write")
		FileAccess.open(OUT+"expected-save.json",FileAccess.WRITE).store_string(JSON.stringify(s.snapshot()))
	else:
		s.load_state()
		check(s.writable,"new process accepts snapshot")
		if not s.writable:
			finish(world,s,mode);return
		if mode=="read":
			var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"expected-save.json"))
			check(s.body.sleeping and is_equal_approx(s.body.sleep_elapsed,60) and is_equal_approx(s.body.energy,13),"new process restores partial sleep without adding time")
			check(is_equal_approx(env.minute,1380),"same atomic world clock")
			for key in ["slots","equipment","hotbar_equipment","resource_hits","consumed","buildings","campfires"]:
				check(JSON.parse_string(JSON.stringify(s.snapshot()[key]))==expected[key],"unchanged state across restart "+key)
			v.advance_gameplay(300)
			check(not s.body.sleeping and is_equal_approx(s.body.energy,39) and is_equal_approx(env.minute,60),"resume remaining two hours once")
			check(s.save_state(),"waking atomic save")
		elif mode=="awake":
			check(not s.body.sleeping and is_equal_approx(s.body.energy,39) and is_equal_approx(env.minute,60),"third process no duplicated sleep or recovery")
			check(s.inventory.count_item("wild_carrot")==4 and s.inventory.has_capability("mine"),"inventory and equipment survive all stages")
			var data: Dictionary=s.snapshot();data.body.version=1
			for key in ["energy","sleeping","sleep_forced","sleep_elapsed","sleep_duration"]: data.body.erase(key)
			data.erase("body_environment")
			FileAccess.open(PATH,FileAccess.WRITE).store_string(JSON.stringify(data))
			s.load_state();check(s.writable and s.body.energy==100 and not s.body.sleeping,"real v1 file migrates to healthy awake state")
			check(s.inventory.count_item("wild_carrot")==4 and s.builds.states.has("body-v2:floor") and s.resource_hits["body-v2:test"]==3,"migration preserves camp food and harvest")
			check(s.save_state(),"migrated file saves version two")
		elif mode=="legacy-read":
			check(s.body.energy==100 and not s.body.sleeping and s.inventory.count_item("wild_carrot")==4,"migrated file survives separate restart")
			var original: Dictionary=s.snapshot()
			for invalid in ["version","energy","clock"]:
				var data: Dictionary=original.duplicate(true)
				if invalid=="version": data.body.version=999
				elif invalid=="energy": data.body.energy=-1
				else: data.body_environment.version=999
				FileAccess.open(PATH,FileAccess.WRITE).store_string(JSON.stringify(data))
				var text := FileAccess.get_file_as_string(PATH)
				s.writable=true;s.load_state();s.dirty=true
				check(not s.writable and not s.save_state() and FileAccess.get_file_as_string(PATH)==text,"invalid source protected "+invalid)
	finish(world,s,mode)
func finish(world: Node,s: Node,mode: String) -> void:
	var failed := checks.filter(func(row):return not row.pass).size()
	FileAccess.open(OUT+"persistence-"+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("BODY V2 PERSISTENCE ",mode,": ",checks.size()," checks; ",failed," failures")
	world.persistent_world=false;s.dirty=false;world.queue_free()
	for i in 6: await process_frame
	quit(0 if failed==0 else 1)
