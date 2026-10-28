extends SceneTree
const OUT="res://reports/soil-shelter-rotate-v1/"
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
	s.inventory.equipment.main_hand=s.inventory.instance("stone_pickaxe")
	for kind in ["stone_wall","wood_fence"]:
		for vertical in [false,true]:
			await reset_site();s.inventory.equipment.main_hand=s.inventory.instance("stone_pickaxe")
			install(kind,site,vertical);await frames()
			for delta in ([Vector2(-48,0),Vector2(48,0)] if vertical else [Vector2(0,-32),Vector2(0,32)]):
				var soil: Dictionary=b.candidate("tilled_soil",site+delta,false,false,0)
				check(b.reason(soil).is_empty(),"soil beside "+kind+str(vertical)+str(delta)+" reason="+b.reason(soil))
	await reset_site()
	var ui=w.camp_ui
	ui.placing=true;ui.building_id="build_rain_shelter";ui.build_vertical=false
	var key:=InputEventKey.new();key.physical_keycode=KEY_R;key.pressed=true
	ui.handle_input(key);check(ui.build_vertical,"R switches shelter direction")
	ui.handle_input(key);check(not ui.build_vertical,"R restores shelter direction")
	ui.placing=false
	var shelter: Dictionary=b.candidate("rain_shelter",site,true,false,0)
	b.states.rotated=shelter;b.install(w.stream.chunk_at(site));await frames()
	check(b.visuals.has("rotated"),"rotated shelter installed")
	var render=b.visuals.rotated.shelter_view
	check(render.parts.size()==4 and render.image.resource_path.ends_with("shelter_vertical.png"),"rotated art and four poles")
	check(load("res://scripts/weather_exposure.gd").covered(s,site+Vector2(0,-130)),"rotated coverage along depth")
	check(not load("res://scripts/weather_exposure.gd").covered(s,site+Vector2(130,0)),"rotated coverage excludes sides")
	for post in load("res://scripts/weather_exposure.gd").posts(shelter):
		var point:=site+Vector2(post[0],post[1])
		check(load("res://scripts/weather_exposure.gd").pole_blocks(shelter,point,point,1),"rotated pole blocks")
	check(b.validate({"version":1,"grid_version":1,"objects":{"rotated":shelter}},{} ),"rotated shelter accepts existing save schema")
	var pole_soil: Dictionary=b.candidate("tilled_soil",site+Vector2(-98,140),false,false,0)
	check(b.reason(pole_soil)=="耕地不能覆盖雨棚柱子","rotated pole forbids soil")
	render.update_occlusion(site);await create_timer(.2).timeout
	check(render.roof.modulate.a<1 and render.parts.all(func(part):return part.modulate.a==1),"rotated roof fades alone")
	render.update_occlusion(site+Vector2(500,500));await create_timer(.2).timeout
	check(is_equal_approx(render.roof.modulate.a,1),"rotated roof returns opaque")
	w.player.position=site+Vector2(220,140)
	await frames()
	get_root().get_texture().get_image().save_png(OUT+"rotated.png")
	await finish()



