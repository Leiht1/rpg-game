extends SceneTree
const OUT="res://reports/planting-formal-v1/"
var checks=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Engine.set_meta("integration_seed",98171023)
	var w=load("res://tests/world_clean_camp_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
	var s=w.item_service;var b=s.builds
	s.save_path=OUT+"isolated-save.json";w.persistent_world=true
	var after_harvest: bool="after-harvest" in OS.get_cmdline_user_args()
	var reading: bool="read" in OS.get_cmdline_user_args() or after_harvest
	if after_harvest:
		s.load_state()
		check(s.writable and b.states.size()==4,"third process loads harvested snapshot")
		check(b.states["plot-2"].roots and b.states["plot-2"].crop.is_empty(),"harvested mature crop remains roots after another restart")
		check(s.inventory.count_item("carrot_seed")==9 and s.inventory.count_item("wild_carrot")==4,"one harvest reward restored exactly once")
		check(b.states["plot-1"].growth_minutes==120.25,"unharvested crop does not grow while process is closed")
		check(b.states["plot-3"].roots,"other roots retained independently")
	elif not reading:
		for i in 40:s.inventory.slots[i]={}
		for index in 4:
			var row: Dictionary=b.candidate("tilled_soil",w.generator.spawn+Vector2(96*index,128),false,true,0)
			row.crop="carrot" if index in [1,2] else "";row.growth_minutes=120.25 if index==1 else float(s.planting.rules.crops.carrot.minutes) if index==2 else 0.0;row.roots=index==3
			b.states["plot-"+str(index)]=row
		s.inventory.slots[0]={"item_id":"carrot_seed","count":7}
		check(s.save_state(),"write isolated real atomic snapshot")
		check(FileAccess.file_exists(s.save_path),"save file exists outside player save path")
	else:
		s.load_state();check(s.writable,"new process accepts saved crop snapshot")
		check(b.states.size()==4,"four plot states survive process restart")
		check(b.states["plot-0"].crop.is_empty() and not b.states["plot-0"].roots,"idle restored")
		check(b.states["plot-1"].growth_minutes==120.25,"growth restored exactly without offline growth")
		check(s.planting.stage(b.states["plot-2"])==2,"maturity restored")
		check(b.states["plot-3"].roots,"roots restored")
		check(s.inventory.count_item("carrot_seed")==7,"inventory restored without duplicate seeds")
		var serialized: Dictionary=b.serialize();serialized.objects["plot-1"].growth_minutes=-1
		check(not b.validate(serialized,{}),"negative progress rejected")
		serialized=b.serialize();serialized.objects["plot-1"].crop="unknown"
		check(not b.validate(serialized,{}),"unknown crop rejected")
		serialized=b.serialize();serialized.objects["plot-1"].roots=true
		check(not b.validate(serialized,{}),"contradictory crop and roots rejected")
		serialized=b.serialize();serialized.objects["plot-1"].growth_minutes=999999
		check(not b.validate(serialized,{}),"overgrown progress rejected")
		# Old building saves contain no crop fields and remain valid.
		var legacy: Dictionary=b.candidate("wood_floor",w.generator.spawn+Vector2(0,256),false,true,0)
		check(b.validate({"version":1,"grid_version":1,"objects":{"legacy":legacy}},{}),"old buildings without crop fields remain valid")
		await process_frame;await process_frame;await process_frame
		var target: Node2D=b.visuals["plot-2"]
		w.player.position=target.position+Vector2(0,32)
		await physics_frame;await physics_frame
		check(s.planting.interact("plot-2",target),"harvest restored mature crop through real interaction")
		check(b.states["plot-2"].roots and s.inventory.count_item("carrot_seed")==9 and s.inventory.count_item("wild_carrot")==4,"restored crop grants configured produce and seeds once")
		check(not s.planting.interact("plot-2",target) and s.inventory.count_item("wild_carrot")==4,"repeated restored crop harvest refused")
	w.persistent_world=false;s.dirty=false
	var failed=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"persistence-"+("after-harvest" if after_harvest else "read" if reading else "write")+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("PLANTING PERSISTENCE ",checks.size()," checks; ",failed," failures")
	w.queue_free();await process_frame;await process_frame;quit(0 if failed==0 else 1)
