extends SceneTree
const OUT="res://reports/chest-ui-v2/"
var checks=[]
func check(ok:bool,label:String)->void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n:int=4)->void:
	for i in n:await process_frame
func native_drag(owner_world:Node,source:Control,target:Control)->void:
	var a:Vector2=source.get_global_rect().get_center();var z:Vector2=target.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=a;Input.parse_input_event(motion);await frames()
	var down:=InputEventMouseButton.new();down.position=a;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;Input.parse_input_event(down);await frames()
	for i in range(1,11):
		var move:=InputEventMouseMotion.new();move.position=a.lerp(z,i/10.0);move.relative=(z-a)/10;move.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(move);await frames(2)
	check(owner_world.item_ui.bag.visible and root.gui_is_dragging(),"native drag remains active with bag visible")
	var up:=InputEventMouseButton.new();up.position=z;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;Input.parse_input_event(up);await frames()
func _initialize()->void:call_deferred("run")
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUT);Engine.set_meta("integration_seed",271828);Engine.set_meta("chest_open_preview",false)
	var w=load("res://tests/world_clean_camp_fixture.gd").new();root.add_child(w)
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
		check(storage.cells[0].size==Vector2(44,44) and storage.panel.size==Vector2(156,184),"smaller chest cells and compact frame")
		check(storage.panel.z_index>node.z_index,"grid remains above lid")
		w.item_ui.toggle_bag();await frames()
		check(w.item_ui.bag.z_index>storage.panel.z_index and w.item_ui.equipment_panel.z_index>storage.panel.z_index,"both bag panels draw above chest")
		check(w.item_ui.cells[9].position.x>w.item_ui.cells[8].position.x and w.item_ui.cells[12].position.y>w.item_ui.cells[8].position.y,"bag visual order matches row-major organize")
		check(storage.panel.get_node("ChestTitle").position.y==12,"title moved into blank header")
		check(node.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"both chest states share minification filtering")
		var e:=InputEventKey.new();e.physical_keycode=KEY_E;e.pressed=true;Input.parse_input_event(e);await frames()
		check(w.item_ui.bag.visible and not b.states[id].open,"E closes real targeted chest while bag remains open")
		e.pressed=false;Input.parse_input_event(e);await frames();e.pressed=true;Input.parse_input_event(e);await frames()
		check(w.item_ui.bag.visible and b.states[id].open,"E reopens real chest with bag visible")
		e.pressed=false;Input.parse_input_event(e);await frames()
		storage.set_process(false);var previous:Vector2=storage.panel.position;storage.panel.position=w.item_ui.bag.position+Vector2(0,80)
		var motion:=InputEventMouseMotion.new();motion.position=w.item_ui.cells[8].get_global_rect().get_center();Input.parse_input_event(motion);await frames()
		var hovered:Control=root.gui_get_hovered_control()
		check(hovered!=null and (hovered==w.item_ui.bag or w.item_ui.bag.is_ancestor_of(hovered)),"bag receives pointer above overlapping chest")
		storage.panel.position=previous;storage.set_process(true)
		b.states[id].contents[0]={"item_id":"branch","count":5};s.inventory.slots[30]={};s.inventory.changed.emit()
		await native_drag(w,storage.cells[0],w.item_ui.cells[30])
		check(b.states[id].contents[0].is_empty() and s.inventory.slots[30].get("count",0)==5,"native drag from smaller chest into bag")
		await native_drag(w,w.item_ui.cells[30],storage.cells[0])
		check(s.inventory.slots[30].is_empty() and b.states[id].contents[0].get("count",0)==5,"native drag bag to smaller chest bypasses ground catcher")

		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"open.png")
		storage.close_panel();await frames();check(not b.states[id].open and not storage.panel.visible,"closing returns to closed state and hides grid")
		storage.open(id);b.states[id].contents[0]={"item_id":"branch","count":5};storage.refresh()
		w.persistent_world=true;s.save_path=OUT+"save.json";check(s.save_state(),"isolated open chest save commits contents")
	w.persistent_world=false;s.dirty=false
	var failed=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+("restart" if "restart" in OS.get_cmdline_user_args() else "checks")+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("FORMAL CHEST ",checks.size()," checks; ",failed," failures")
	w.queue_free();await frames();quit(0 if failed==0 else 1)
