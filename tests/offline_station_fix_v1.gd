extends SceneTree
var checks: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool, label: String) -> void:
	checks.append({"pass":value,"label":label})
	if not value:push_error(label)
func run() -> void:
	var Creation=load("res://scripts/character_creation.gd")
	var path: String="user://offline-station-test-"+str(Time.get_ticks_usec())+"/state.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var original: String="old world sentinel"
	FileAccess.open(path,FileAccess.WRITE).store_string(original)
	var c=Creation.new();c.selection_only=true;c.save_path=path;root.add_child(c)
	check(c.screen.visible and not c.enter.disabled and c.world==null,"new creation ignores existing invalid save without disabling Enter")
	check(FileAccess.get_file_as_string(path)==original,"opening creation preserves previous save")
	var cancelled: Array=[];c.cancelled.connect(func():cancelled.append(true))
	c.cancelled.emit()
	check(cancelled.size()==1 and FileAccess.get_file_as_string(path)==original,"cancel preserves previous save")
	c.selection_only=false
	var record: Dictionary={"version":1,"active_character_id":"isolated","world_id":"new-world","seed":447349832,"map_cells":1024,"characters":{"isolated":{"world_id":"new-world","appearance":c.look.duplicate(true),"test_outfit_granted":false,"outfit_id":""}}}
	c.save_path=path+"/blocked.json"
	check(not await c.open_world(record,true),"failed initial save returns to creation")
	check(FileAccess.get_file_as_string(path)==original and not c.enter.disabled and c.world==null,"failed creation preserves old world and allows retry")
	c.save_path=path
	check(await c.open_world(record,true),"new world initializes successfully over existing invalid save")
	check(c.valid_session(JSON.parse_string(FileAccess.get_file_as_string(path))),"successful creation atomically replaces old save with valid new session")
	var saved: String=FileAccess.get_file_as_string(path)
	var w=c.world;var s=w.item_service
	w.persistent_world=false
	w.set_process(false);w.environment_view.set_process(false);w.player.set_physics_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	s.builds.states.clear();s.builds.refresh_all();await physics_frame;await process_frame
	var at: Vector2=w.player.position
	var row: Dictionary=s.builds.candidate("metal_workbench",at,false,true,0)
	s.builds.states["test-station"]=row;s.builds.refresh_around(row)
	await physics_frame;await process_frame
	var found: bool=false
	for offset in [Vector2(0,65),Vector2(65,0),Vector2(-65,0),Vector2(0,-65)]:
		w.player.position=Vector2(row.x,row.y)+offset
		if s.workbench_valid("test-station"):found=true;break
	check(found,"metal workbench reachable before snapshot")
	w.item_ui.toggle_craft("test-station")
	check(w.item_ui.craft_panel.visible and s.craft_station_id=="test-station","open metal crafting UI")
	var old=s.builds.visuals["test-station"]
	s.builds.refresh_around(row)
	old.body.collision_layer=1
	check(not s.workbench_valid("test-station"),"reproduce original snapshot collider causing station rejection")
	old.body.collision_layer=0
	for i in 8:
		var retired=s.builds.visuals["test-station"]
		s.builds.refresh_around(row)
		check(retired.body.collision_layer==0,"snapshot retires old collider immediately "+str(i))
		w.item_ui.craft_panel._process(0)
		check(w.item_ui.craft_panel.visible and s.workbench_valid("test-station"),"UI survives immediate snapshot replacement "+str(i))
		await physics_frame;await process_frame
	w.set_meta("network_game",true)
	for i in 3:
		var snapshot: Dictionary=s.snapshot()
		snapshot.buildings.objects["test-station"].hits=i%2+1
		s.load_state("",false,snapshot)
		w.item_ui.craft_panel._process(0)
		check(s.writable and w.item_ui.craft_panel.visible and s.craft_station_id=="test-station","authoritative snapshot keeps metal station usable "+str(i))
		await physics_frame;await process_frame
	w.remove_meta("network_game")
	var recipe: Dictionary=s.craft_book.recipe("metal_copper_axe")
	for material in recipe.materials:s.inventory.add(material,int(recipe.materials[material]))
	check(s.start_craft("metal_copper_axe",1).is_empty(),"metal crafting starts after repeated snapshots")
	s.advance_craft(2)
	check(s.craft_job.is_empty() and s.inventory.count_item("copper_axe")==1,"metal crafting completes and grants product")
	w.player.position+=Vector2(300,0);w.item_ui.craft_panel._process(0)
	check(not w.item_ui.craft_panel.visible,"walking away still closes station")
	s.writable=false;w.persistent_world=false
	c.queue_free();await process_frame
	var resume=Creation.new();resume.save_path=path;root.add_child(resume)
	while resume.busy:await process_frame
	check(resume.world!=null and not resume.screen.visible,"continue restores newly created world")
	resume.world.persistent_world=false;resume.world.item_service.writable=false
	resume.queue_free();await process_frame
	check(FileAccess.get_file_as_string(path)==saved,"read-only continuation leaves save intact")
	var launcher=load("res://scripts/launcher.gd").new();root.add_child(launcher);launcher.local_mode()
	var new_button: Button=launcher.content.find_children("*","Button",true,false).filter(func(b):return b.text=="创建新的世界")[0]
	new_button.pressed.emit()
	check(launcher.creation!=null and launcher.creation.screen.visible and not launcher.creation.enter.disabled,"launcher new-world button always opens enabled character creation")
	launcher.creation.cancelled.emit();await process_frame
	check(launcher.creation==null and launcher.root.visible,"launcher cancel returns to visible offline menu")
	launcher.queue_free();await process_frame
	FileAccess.open("res://reports/offline-station-fix-v1/checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	var failed: int=checks.filter(func(row_value):return not row_value.pass).size()
	print("OFFLINE_STATION_CHECKS ",checks.size()," FAILED ",failed)
	quit(1 if failed else 0)
