extends SceneTree
const OUT := "res://reports/fishing-population-v2/"
var checks: Array=[]
var summaries: Array=[]
var w: Node2D
var f: Node2D
var obtained: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool, name: String) -> void:
	checks.append({"name":name,"pass":ok})
	if not ok: push_error(name)
func files() -> Dictionary:
	var result := {}
	for name in DirAccess.get_files_at("user://"):
		if name.ends_with(".json") or name.ends_with(".tmp"): result[name]=FileAccess.get_sha256("user://"+name)
	return result
func frames(count: int=2) -> void:
	for i in count: await process_frame
func write_state(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
func inspect_population(pop: RefCounted, generator: WildGenerator, label: String) -> void:
	var lake_counts := {};var coast := 0;var geometry := true;var spacing := true
	for i in pop.spots.size():
		var spot: Dictionary=pop.spots[i]
		if spot.lake==-1: coast+=1;geometry=geometry and generator.coast_distance(spot.water)<0
		else: lake_counts[spot.lake]=int(lake_counts.get(spot.lake,0))+1
		geometry=geometry and generator.can_walk(spot.stand,20) and spot.stand.distance_to(spot.water)<175
		for y in range(-24,25,8):
			for x in range(-60,61,8): geometry=geometry and generator.sample(spot.water+Vector2(x,y)).z>=.8
		for j in i:
			var other: Dictionary=pop.spots[j]
			spacing=spacing and spot.water.distance_to(other.water)>=(1800 if spot.lake==-1 or other.lake==-1 else 320)
	check(pop.spots.size()<=20 and not pop.spots.is_empty(),label+": global cap 20")
	check(lake_counts.values().all(func(value): return value<=3),label+": no lake exceeds 3")
	check(coast>0,label+": irregular continent coast has schools")
	check(geometry,label+": all stands walkable and effects fully over water")
	check(spacing,label+": sparse sea coast and separated lake schools")
	check(pop.valid(pop.serialize()),label+": initial state validates")
	summaries.append({"seed":generator.world_seed,"total":pop.spots.size(),"coast":coast,"lakes":lake_counts,"empty_lakes":generator.lakes.size()-lake_counts.size()})
func start() -> bool:
	f.finish("");w.player.position=f.spots[0].stand
	w.player.reset_physics_interpolation();w.player.camera.reset_smoothing()
	return f.try_start()
func succeed(id: String) -> void:
	f.catch_id=id;f.advance(.9);f.advance(f.wait_time+.01);f.advance(.66)
	f.resolve_attempt(true);f.resolve_attempt(true);f.advance(1.2)
func run() -> void:
	Engine.max_fps=60
	var before := files()
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	w.environment_view.simulation.paused=true
	f=w.get_node("Fishing");f.set_process(false)
	var service=w.item_service
	var pop=service.fishing_population
	inspect_population(pop,w.generator,"formal world")
	check(is_same(f.spots,pop.spots),"controller shares persistent population array")
	for i in pop.spots.size():
		if pop.spots[i].lake==-1:
			var swap: Dictionary=pop.spots[0];pop.spots[0]=pop.spots[i];pop.spots[i]=swap;break
	# Bring a safe test bank into the streamed viewport, without editing terrain or props.
	w.player.position=f.spots[0].stand;w.stream.update_target(w.player.position)
	var deadline := Time.get_ticks_msec()+90000
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)/w.player.camera.zoom) and Time.get_ticks_msec()<deadline: await process_frame
	await frames(4)
	service.inventory.slots[0]=service.inventory.instance("fishing_rod");service.inventory.equip(0)
	service.item_obtained.connect(func(id,count): obtained.append([id,count]))
	if DisplayServer.get_name()!="headless":
		w.player.camera.position_smoothing_enabled=false
		w.player.camera.reset_smoothing();f.update_ui();f.queue_redraw()
		await frames(3);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"coast-school.png")
	# Ensure first bank is reachable; if a prop obstructs it, use another existing school.
	var found := false
	for i in f.spots.size():
		w.player.position=f.spots[i].stand
		if f.nearest_spot()==i:
			if i!=0:
				var swap: Dictionary=f.spots[0];f.spots[0]=f.spots[i];f.spots[i]=swap
			found=true;break
	check(found,"existing generated bank can be interacted with")
	if not found: finish(before);return
	var path := OUT+"state-test.json"
	service.save_path=path;w.persistent_world=true
	check(start(),"live school starts fishing")
	f.transition("failure");f.advance(.8)
	check(pop.spots[0].remaining==6,"failed fishing consumes no fish")
	check(start(),"restart after failure")
	f.finish("取消")
	check(pop.spots[0].remaining==6,"cancel consumes no fish")
	check(start(),"start rare catch")
	succeed(f.COIN_ID);f.finish("")
	check(pop.spots[0].remaining==6 and service.inventory.count_item(f.COIN_ID)==1,"coin does not consume fish stock")
	check(start(),"start full-bag catch")
	var slots: Array=service.inventory.slots.duplicate(true)
	for i in range(8,40): service.inventory.slots[i]={"item_id":"wood","count":30}
	succeed(f.FISH_ID);f.finish("")
	check(pop.spots[0].remaining==6,"full bag consumes no fish")
	service.inventory.slots.assign(slots)
	check(start(),"start rollback catch")
	service.save_path="user://missing-fishing-population-dir/invalid.json"
	var notices := obtained.size();succeed(f.FISH_ID);f.finish("")
	check(pop.spots[0].remaining==6 and obtained.size()==notices,"save failure rolls back stock and reward together")
	service.save_path=path
	var fish_before: int=service.inventory.count_item(f.FISH_ID)
	for i in 6:
		check(start(),"catch %d starts"%(i+1))
		succeed(f.FISH_ID);f.commit_reward()
		check(pop.spots[0].remaining==5-i,"catch %d consumes exactly one fish"%(i+1))
		if i==5: f.advance(.8)
		else: f.finish("")
	check(service.inventory.count_item(f.FISH_ID)==fish_before+6,"school yields exactly six fish")
	check(f.nearest_spot()==-1 and not f.try_start(),"exhausted school no longer interactable")
	f.advance(.1)
	check(f.state=="idle","sixth success ends normally without cancellation or extra award")
	if DisplayServer.get_name()!="headless":
		f.update_ui();f.queue_redraw();await frames(2);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"coast-exhausted.png")
	var exhausted: Dictionary=pop.serialize()
	var delay: float=pop.spots[0].respawn_minutes
	check(delay>=2880 and delay<=4320,"respawn waits 2 to 3 game days")
	var disk=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(disk.fishing.schools[0].remaining==0 and disk.fishing.schools[0].respawn_minutes==delay,"sixth reward atomically saves exhausted stock and timer")
	w.environment_view.advance_gameplay(1)
	check(pop.spots[0].respawn_minutes==delay,"paused world does not advance respawn timer")
	w.environment_view.simulation.paused=false
	w.environment_view.advance_gameplay(1)
	w.environment_view.simulation.paused=true
	check(is_equal_approx(delay-pop.spots[0].respawn_minutes,1440.0/(w.environment_view.simulation.day_length_minutes*60)),"respawn follows shared game clock")
	pop.advance(100)
	service.load_state(path)
	check(pop.serialize()==exhausted,"loading restores exact exhausted stock, timer and RNG")
	var old_water: Vector2=pop.spots[0].water
	pop.advance(delay-.1)
	check(pop.spots[0].remaining==0,"no early respawn")
	var before_respawn: Dictionary=pop.serialize()
	pop.advance(.2)
	check(pop.spots[0].remaining==6 and pop.spots[0].water.distance_to(old_water)>=320,"after delay new school appears at different random bank")
	var first_respawn: Dictionary=pop.serialize()
	pop.restore(before_respawn);pop.advance(.2)
	check(pop.serialize()==first_respawn,"saved RNG reproduces respawn rather than rerolling on load")
	check(pop.valid(pop.serialize()) and pop.spots.size()<=20,"replacement preserves cap, spacing and lake limits")
	# Round-trip through JSON and reject malformed fishing data without partial inventory restore.
	check(pop.valid(JSON.parse_string(JSON.stringify(pop.serialize()))),"JSON fishing round trip validates")
	for kind in ["too_many_fish","duplicate","timer","unknown","fraction","rng","nan"]:
		var bad: Dictionary=pop.serialize()
		if kind=="too_many_fish": bad.schools[0].remaining=7
		elif kind=="duplicate": bad.schools.append(bad.schools[0].duplicate())
		elif kind=="timer": bad.schools[0].respawn_minutes=1
		elif kind=="unknown": bad.schools[0].id="missing"
		elif kind=="fraction": bad.schools[0].remaining=.5
		elif kind=="rng": bad.rng_state="invalid"
		else: bad.schools[0].respawn_minutes=NAN
		check(not pop.valid(bad),"reject malformed population: "+kind)
	var old_save: Dictionary=service.snapshot();old_save.erase("fishing")
	write_state(path,old_save);pop.configure(w.generator);var generated: Dictionary=pop.serialize()
	service.load_state(path)
	check(service.writable and pop.serialize()==generated,"old saves without fishing field initialize once without rejection")
	var saved_inventory: Array=service.inventory.slots.duplicate(true)
	var corrupt: Dictionary=service.snapshot();corrupt.fishing.schools[0].remaining=7
	write_state(path,corrupt);service.load_state(path)
	check(not service.writable and service.inventory.slots==saved_inventory,"invalid persisted fish data protects save and inventory")
	w.persistent_world=false;service.writable=true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for seed_value in [271828,123456]:
		var generator=load("res://scripts/world_generator.gd").new(seed_value,1024)
		var population=load("res://scripts/fishing_population.gd").new();population.configure(generator)
		inspect_population(population,generator,"seed "+str(seed_value))
	check(summaries.any(func(row): return row.empty_lakes>0),"sample maps include naturally empty lakes")
	finish(before)
func finish(before: Dictionary) -> void:
	if is_instance_valid(w):
		w.persistent_world=false;w.free()
	await frames()
	check(files()==before,"all player JSON and tmp names and hashes unchanged")
	var report := {"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"checks":checks,"maps":summaries,"pass":checks.filter(func(row): return row.pass).size(),"fail":checks.filter(func(row): return not row.pass).size(),"player_files":before.size()}
	var file := FileAccess.open(OUT+("headless-results.json" if DisplayServer.get_name()=="headless" else "window-results.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("FISHING_POPULATION ",report.pass," pass / ",report.fail," fail")
	quit(0 if report.fail==0 else 1)
