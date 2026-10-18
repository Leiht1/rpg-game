extends SceneTree
const OUT="res://reports/planting-formal-v1/"
var checks=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n: int=3) -> void:
	for i in n:await process_frame
func _initialize() -> void:call_deferred("run")
func run() -> void:
	Engine.set_meta("integration_seed",98171023)
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
	var s=w.item_service;var b=s.builds
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	var base: Dictionary=b.candidate("tilled_soil",w.player.position,false,true,0)
	var center := Vector2(base.x,base.y)
	for offset in [Vector2.ZERO,Vector2(1,1),Vector2(95,63),Vector2(-1,-1),Vector2(-97,-65)]:
		var soil: Dictionary=b.candidate("tilled_soil",center+offset,false,true,0)
		var floor_row: Dictionary=b.candidate("wood_floor",center+offset,false,true,0)
		check(soil.gx==floor_row.gx and soil.gy==floor_row.gy and soil.x==floor_row.x and soil.y==floor_row.y,"soil and floor share same global grid "+str(offset))
	var east: Dictionary=b.candidate("tilled_soil",center+Vector2(96,0),false,true,0)
	var south: Dictionary=b.candidate("tilled_soil",center+Vector2(0,64),false,true,0)
	check(east.x-base.x==96 and east.y==base.y and south.x==base.x and south.y-base.y==64,"horizontal and vertical planting spacing exactly matches floor STEP")
	b.states={"one":base}
	check(b.occupant(b.candidate("wood_floor",center,false,true,0))=="one","soil blocks floor in same ground cell")
	b.states={"one":b.candidate("wood_floor",center,false,true,0)}
	check(b.occupant(base)=="one","floor blocks soil in same ground cell")
	b.states.clear()
	for y in 3:
		for x in 6:
			var row: Dictionary=b.candidate("tilled_soil" if x<3 else "wood_floor",center+Vector2(x*96,y*64),false,true,0)
			if x<3:row.roots=y==1
			b.states["layout-%d-%d"%[x,y]]=row
	check(b.validate(JSON.parse_string(JSON.stringify(b.serialize())),{}),"aligned field and floor serialize without occupancy collisions")
	b.refresh_all();await frames()
	var first: Node2D=b.visuals["layout-0-0"]
	var middle: Node2D=b.visuals["layout-1-0"]
	check(s.planting.soil_rect()==Rect2(-46,-30,92,60),"visible soil footprint is floor size minus two units at every edge")
	var soil: Texture2D=first.planting_texture("soil")
	check(soil is AtlasTexture and soil.region==Rect2(soil.atlas.get_image().get_used_rect()),"transparent padding excluded before fitting requested footprint")
	check(first.planting_texture("soil")==middle.planting_texture("soil"),"neighboring soil plots use identical independent texture, no auto join selection")
	check(b.visuals["layout-0-1"].planting_texture("soil")==first.planting_texture("soil"),"roots and idle state use exact same soil texture")
	check(first.body.collision_layer==0 and middle.body.collision_layer==0,"soil remains walkable like floor")
	check(b.visuals["layout-3-0"].floor_has_south(),"adjacent actual floor still joins actual floor")
	var fake: Dictionary=b.states["layout-3-1"].duplicate(true);fake.kind="tilled_soil";fake.crop="";fake.growth_minutes=0;fake.roots=false
	var original: Dictionary=b.states["layout-3-1"]
	b.states["layout-3-1"]=fake
	check(not b.visuals["layout-3-0"].floor_has_south(),"soil neighbor never hides floor exposed front edge")
	b.states["layout-3-1"]=original
	for tree in get_nodes_in_group("trees"):tree.hide()
	for drop in w.stream.drops:
		if is_instance_valid(drop):drop.hide()
	w.player.position=center+Vector2(240,240);w.player.camera.position_smoothing_enabled=false;w.player.camera.force_update_scroll()
	await frames(6)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"soil-layout.png")
	w.persistent_world=false;s.dirty=false
	var failed=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"layout-"+("headless" if DisplayServer.get_name()=="headless" else "window")+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("PLANTING LAYOUT ",checks.size()," checks; ",failed," failures")
	w.queue_free();await frames();quit(0 if failed==0 else 1)
