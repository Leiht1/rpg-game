extends SceneTree
var OUT := "res://reports/floor-formal-v3/"
var checks: Array=[]
var tile_script: Script=preload("res://scripts/camp_building.gd")
func _initialize(): call_deferred("run")
func frames(n: int=3):
	for i in n: await process_frame
func check(ok: bool,label: String):
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func run():
	var render_service=preload("res://tests/render_service_fixture.gd").new();root.add_child(render_service)
	DirAccess.make_dir_recursive_absolute(OUT)
	# GPU seam tests use both materials and fractional display scale, matching camera zoom.
	for zoom in [1.0,.75,1.25]:
		for material in ["wood_floor","stone_path","mixed"]:
			var view := SubViewport.new();view.size=Vector2i(600,440);view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
			var bg := ColorRect.new();bg.size=Vector2(600,440);bg.color=Color(0,1,0);view.add_child(bg)
			var layer := Node2D.new();layer.position=Vector2(24.3,24.7);layer.scale=Vector2.ONE*zoom;view.add_child(layer)
			var manager=preload("res://scripts/camp_buildings.gd").new()
			manager.service=render_service
			for y in 4:
				for x in 4:
					var id := "%d:%d"%[x,y];var at := Vector2(48+x*96,32+y*64)
					manager.states[id]=manager.candidate(("wood_floor" if x<2 else "stone_path") if material=="mixed" else material,at,false,true,0)
			for id in manager.states:
				var tile=tile_script.new();tile.preview=true;tile.manager=manager;tile.building_id=id;tile.position=Vector2(manager.states[id].x,manager.states[id].y);layer.add_child(tile)
			await frames();await RenderingServer.frame_post_draw
			var im := view.get_texture().get_image();var green := 0
			for y in range(ceili(24.7+zoom),floori(24.7+255*zoom)):
				for x in range(ceili(24.3+zoom),floori(24.3+383*zoom)):
					var c := im.get_pixel(x,y)
					if c.g>.95 and c.r<.05 and c.b<.05: green+=1
			check(green==0,"candidate internal green pixels0 "+material+" zoom"+str(zoom))
			im.save_png(OUT+"square-grid-"+material+"-"+str(zoom)+".png");view.free();await frames(6)
	render_service.free()
	await world_scene()
	var failed: Array=checks.filter(func(v): return not v.pass)
	FileAccess.open(OUT+"square-floor-tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed.size(),"art_status":"approved_user"},"  "))
	print("FORMAL FLOOR: %d checks, %d failed"%[checks.size(),failed.size()]);quit(0 if failed.is_empty() else 1)
func world_scene():
	var world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	world.player.set_physics_process(false);world.player.camera.position_smoothing_enabled=false;world.environment_view.simulation.paused=true
	var manager=world.item_service.builds
	var anchor: Vector2=world.generator.spawn.snapped(Vector2(96,64))-Vector2(192,128)
	manager.states.clear()
	for y in 4:
		for x in 4:
			manager.states["floor:%d:%d"%[x,y]]=manager.candidate("wood_floor" if x<2 else "stone_path",anchor+Vector2(48+x*96,32+y*64),false,true,0)
	for x in 4:
		for y in [0,4]: manager.states["wall:%d:%d"%[x,y]]=manager.candidate("stone_wall",anchor+Vector2(48+x*96,y*64),false,true,0)
	for y in 4:
		for x in [0,4]: manager.states["side:%d:%d"%[x,y]]=manager.candidate("stone_wall",anchor+Vector2(x*96,32+y*64),true,true,0)
	manager.states.chest=manager.candidate("wood_chest",anchor+Vector2(290,70),false,true,0)
	manager.states.table=manager.candidate("workbench",anchor+Vector2(280,170),false,true,0)
	world.player.position=anchor+Vector2(150,190);world.player.reset_physics_interpolation();world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	while not world.stream.viewport_ready(world.player.position,Vector2(800,450)): await process_frame
	manager.refresh_all();await frames(5)
	root.size=Vector2i(1280,720);await frames(6);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"floor-current-world.png")
	for size_value in [preload("res://tests/current_test_contract.gd").viewport_size()]:
		root.size=size_value;await frames(6);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"square-floor-world-"+str(size_value.x)+".png")
		check(manager.visuals.size()==manager.states.size(),"candidate same logical occupancy "+str(size_value.x))
	var north: Node2D=manager.visuals["floor:0:0"]
	check(north.floor_has_south(),"formal mixed contiguous floor hides interior lip")
	var south: Dictionary=manager.states["floor:0:1"].duplicate(true)
	manager.states.erase("floor:0:1");manager.refresh_around(south);await frames()
	check(not manager.visuals["floor:0:0"].floor_has_south(),"demolition refresh exposes remaining real material lip")
	manager.states["floor:0:1"]=south;manager.refresh_around(south);await frames()
	check(manager.visuals["floor:0:0"].floor_has_south(),"rebuild hides lip again without residual ground band")
	var service: Node=world.item_service
	service.inventory.add("wood",99)
	world.camp_ui.begin_build("build_wood_floor")
	var ghost_row: Dictionary=manager.candidate("wood_floor",anchor+Vector2(48,-32),false,true,0)
	world.camp_ui.ghost_build.states.preview=ghost_row
	check(world.camp_ui.ghost.floor_has_south(),"placement preview sees formal neighboring floor")
	check(world.camp_ui.ghost.floor_texture("wood","top").resource_path=="res://assets/buildings/v3/wood-top.png","preview uses adopted formal texture path")
	world.camp_ui.cancel_placement()
	var expected: Dictionary=manager.states.duplicate(true)
	world.persistent_world=true;service.save_path=OUT+"floor-save.json"
	check(service.save_state(),"save adopted floor through original atomic snapshot")
	manager.states.clear();service.load_state();await frames()
	check(manager.states==expected and service.writable,"same-process load retains floor positions orientations occupancy")
	check(manager.visuals["floor:0:0"].floor_has_south(),"load reconstructs contiguous surface and exposed lip rules")
	world.persistent_world=false;world.free();await frames(6)
