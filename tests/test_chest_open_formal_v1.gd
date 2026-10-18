extends SceneTree
const OUT="res://reports/chest-open-formal-v1/"
var checks=[]
func check(ok:bool,label:String)->void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n:int=4)->void:
	for i in n:await process_frame
func _initialize()->void:call_deferred("run")
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUT);Engine.set_meta("integration_seed",271828);Engine.set_meta("chest_open_preview",false)
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	var s=w.item_service;var b=s.builds;var p=w.player;var storage=s.storage_ui
	w.set_process(false);w.environment_view.set_process(false);p.set_physics_process(false)
	while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
	if "restart" in OS.get_cmdline_user_args():
		w.persistent_world=true;s.save_path=OUT+"save.json";s.load_state();await frames()
		check(s.writable and b.states.size()==1,"new process accepts formal open chest save")
		if b.states.size()==1:
			var id:String=b.states.keys()[0];p.position=Vector2(b.states[id].x,b.states[id].y)+Vector2(0,45);await frames()
			check(b.states[id].open and storage.panel.visible and b.states[id].contents[0].count==5,"restart restores open grid and contents")
			check(b.textures.has("res://assets/buildings/chest-open-v1/wood_chest_open.png"),"restart draws formal open texture without preview flag")
	else:
		for item in ["wood","plant_fiber"]:s.inventory.add(item,40)
		var id:=""
		for y in range(-3,4):
			for x in range(-3,4):
				var at:Vector2=w.generator.spawn+Vector2(x*96,y*64);p.position=at+Vector2(130,85)
				var row:Dictionary=b.candidate("wood_chest",at,false,true,0)
				if b.reason(row).is_empty() and b.place(row,s.inventory.slots.duplicate(true)).is_empty():id=b.states.keys()[0];break
			if not id.is_empty():break
		check(not id.is_empty(),"place legal formal chest")
		var node:Node2D=b.visuals[id];p.position=node.position+Vector2(0,45);p.reset_physics_interpolation();p.camera.position_smoothing_enabled=false;p.camera.reset_smoothing();p.camera.force_update_scroll();await frames(12)
		check(not b.states[id].open and not storage.panel.visible,"closed chest hides storage grid")
		var old:Texture2D=node.texture(13);check(old.resource_path=="res://assets/buildings/v2/wood_chest.png","closed state retains approved original image")
		storage.open(id);await frames()
		check(b.states[id].open and storage.panel.visible,"E open uses persisted chest state and grid")
		check(b.textures.has("res://assets/buildings/chest-open-v1/wood_chest_open.png"),"open state loads formal image with preview disabled")
		check(storage.cells[0].size==Vector2(44,44) and storage.panel.size==Vector2(156,184),"formal adoption uses current compact frame and smaller cells")
		check(storage.panel.z_index>node.z_index,"grid remains above lid")
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"open.png")
		storage.close_panel();await frames();check(not b.states[id].open and not storage.panel.visible,"closing returns to closed state and hides grid")
		storage.open(id);b.states[id].contents[0]={"item_id":"branch","count":5};storage.refresh()
		w.persistent_world=true;s.save_path=OUT+"save.json";check(s.save_state(),"isolated open chest save commits contents")
	w.persistent_world=false;s.dirty=false
	var failed=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+("restart" if "restart" in OS.get_cmdline_user_args() else "checks")+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("FORMAL CHEST ",checks.size()," checks; ",failed," failures")
	w.queue_free();await frames();quit(0 if failed==0 else 1)
