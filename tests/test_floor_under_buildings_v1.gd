extends SceneTree
const OUT="res://reports/floor-under-buildings-v1/"
var w: Node
var s: Node
var b: RefCounted
var checks: Array=[]
var site := Vector2.ZERO
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames() -> void:
	await physics_frame;await physics_frame;await process_frame
func reset_site() -> void:
	b.states.clear();b.refresh_all();s.camps.states.clear();s.camps.rebuild();await frames()
	for i in 40:s.inventory.slots[i]={}
	s.inventory.add("wood",90);s.inventory.add("stone",90)
func install(kind: String,at: Vector2,vertical: bool=false) -> Dictionary:
	var row: Dictionary=b.candidate(kind,at,vertical,false,0)
	if kind=="signpost": row.text="测试"
	b.states.existing=row;b.install(w.stream.chunk_at(at));return row
func finish() -> void:
	var failed: int=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+("restart.json" if "read" in OS.get_cmdline_user_args() else "window.json"),FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed,"checks":checks},"  "))
	print("FLOOR UNDER BUILDINGS: ",checks.size()," checks; ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.free();await process_frame;quit(0 if failed==0 else 1)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT);Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;b=s.builds
	w.set_process(false);w.environment_view.set_process(false);w.environment_view.simulation.paused=true;w.player.set_physics_process(false);s.set_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	s.save_path=OUT+"isolated-save.json"
	if "read" in OS.get_cmdline_user_args():
		w.persistent_world=true;s.load_state();await frames()
		check(s.writable and b.states.size()==2,"restart accepts floor under existing chest")
		check(b.states.get("existing",{}).get("kind")=="wood_chest","restart retains chest")
		check(b.states.existing.contents[0].get("durability")==73,"restart retains chest contents")
		check(b.states.values().any(func(r):return r.kind=="wood_floor"),"restart retains floor")
		check(s.inventory.count_item("wood")==86,"restart retains exact one floor cost")
		await finish();return
	await reset_site()
	var origin: Vector2=w.player.position
	for y in range(-4,5):
		for x in range(-4,5):
			var row: Dictionary=b.candidate("wood_floor",origin+Vector2(x*96,y*64),false,false,0)
			w.player.position=Vector2(row.x,row.y)+Vector2(110,70)
			if b.reason(row).is_empty():site=Vector2(row.x,row.y);break
		if site!=Vector2.ZERO:break
	check(site!=Vector2.ZERO,"find valid loaded dry site")
	if site==Vector2.ZERO:await finish();return
	for floor_kind in ["wood_floor","stone_path"]:
		for kind in b.definitions:
			if b.definitions[kind].layer!="free":continue
			for vertical in ([false,true] if kind in ["wood_bed","straw_mat"] else [false]):
				await reset_site()
				var before: Dictionary=install(kind,site,vertical).duplicate(true)
				await frames()
				var row: Dictionary=b.candidate(floor_kind,site,false,false,0)
				var label: String=floor_kind+" under "+kind+str(vertical)
				check(b.reason(row).is_empty(),"preview allows "+label)
				check(b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"placement allows "+label)
				check(b.states.existing==before and b.states.size()==2,"existing facility unchanged "+label)
				check(not b.reason(row).is_empty(),"duplicate paving rejected "+label)
		# Off-center small fixture exercises shape overlap beyond the sampled points.
		await reset_site();install("wood_chest",site+Vector2(28,0));await frames()
		var floor_row: Dictionary=b.candidate(floor_kind,site,false,false,0)
		check(b.reason(floor_row).is_empty(),"off-center collider permits "+floor_kind)
		await reset_site()
		s.camps.states.fire={"x":site.x,"y":site.y,"fuel":100.0,"lit":true,"recipe":"","elapsed":0.0,"ready":false};s.camps.rebuild();await frames()
		check(b.reason(floor_row).is_empty(),"campfire permits "+floor_kind)
		for kind in ["stone_wall","wood_fence","stone_gate","fence_gate"]:
			for vertical in [false,true]:
				await reset_site();install(kind,site,vertical);await frames()
				check(b.reason(floor_row).is_empty(),"wall blocks and doorway permits "+floor_kind+kind+str(vertical))
		for kind in ["wood_floor","stone_path","tilled_soil"]:
			await reset_site();install(kind,site);await frames()
			check(not b.reason(floor_row).is_empty(),"existing ground occupancy rejects "+floor_kind+kind)
		await reset_site()
		var obstacle := StaticBody2D.new();var shape := CollisionShape2D.new();var rect := RectangleShape2D.new();rect.size=Vector2(20,20);shape.shape=rect;obstacle.add_child(shape);obstacle.position=site;w.add_child(obstacle);await frames()
		check(not b.reason(floor_row).is_empty(),"unregistered obstacle still rejects "+floor_kind)
		obstacle.free();await frames()
		var trees: Array=get_nodes_in_group("trees")
		if not trees.is_empty():
			var tree: Node2D=trees[0];var previous: Vector2=tree.position
			tree.position=site;await frames()
			check(not b.reason(floor_row).is_empty(),"natural tree still rejects "+floor_kind)
			tree.position=previous;await frames()
	# Failed saves must leave both the existing chest and inventory intact.
	await reset_site();install("wood_chest",site);b.states.existing.contents[0]=s.inventory.instance("stone_axe");b.states.existing.contents[0].durability=73;await frames()
	var before: Dictionary=b.states.duplicate(true);var slots: Array=s.inventory.slots.duplicate(true)
	w.persistent_world=true;s.save_path=OUT+"missing/save.json"
	var row: Dictionary=b.candidate("wood_floor",site,false,false,0)
	check(b.place(row,slots)=="保存失败，建造已回滚","save failure rolls back floor")
	check(b.states==before and s.inventory.slots==slots,"failed floor preserves facility and materials")
	s.save_path=OUT+"isolated-save.json"
	check(b.place(row,slots).is_empty(),"floor under chest commits atomically")
	check(s.inventory.count_item("wood")==86,"successful floor consumes exact original cost once")
	var after: Array=s.inventory.slots.duplicate(true)
	check(not b.place(row,after).is_empty() and s.inventory.slots==after,"duplicate floor consumes nothing")
	# Validate the JSON representation actually written to disk, including numeric normalization.
	check(b.validate(JSON.parse_string(JSON.stringify(b.serialize())),{}),"floor and chest persisted snapshot validates")
	check(not b.reason(b.candidate("workbench",site,false,false,0)).is_empty(),"new furniture still cannot overlap existing furniture")
	await frames()
	if DisplayServer.get_name()!="headless":
		w.player.camera.position_smoothing_enabled=false;w.player.camera.reset_smoothing();await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"floor-under-chest.png")
	await finish()
