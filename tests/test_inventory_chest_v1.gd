extends SceneTree
const OUT="res://reports/inventory-chest-v1/"
var checks=[]
var w
var s
var b
var p
func check(ok:bool,label:String)->void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n:int=4)->void:
	for i in n:await process_frame
func _initialize()->void:call_deferred("run")
func place(kind:String,vertical:bool=false)->String:
	for item in ["wood","stone","plant_fiber","broad_leaf"]:s.inventory.add(item,80)
	for y in range(-3,4):
		for x in range(-3,4):
			var at:Vector2=w.generator.spawn+Vector2(x*96,y*64);p.position=at+Vector2(130,85)
			var row:Dictionary=b.candidate(kind,at,vertical,true,0)
			if b.reason(row).is_empty():
				var before:Array=b.states.keys()
				if b.place(row,s.inventory.slots.duplicate(true)).is_empty():
					for id in b.states:
						if id not in before:return id
	return ""
func native_drag(source:Control,target:Control)->void:
	var a:Vector2=source.get_global_rect().get_center();var z:Vector2=target.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=a;Input.parse_input_event(motion);await frames()
	var down:=InputEventMouseButton.new();down.position=a;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;Input.parse_input_event(down);await frames()
	for i in range(1,11):
		var move:=InputEventMouseMotion.new();move.position=a.lerp(z,i/10.0);move.relative=(z-a)/10;move.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(move);await frames(2)
	check(w.item_ui.bag.visible and root.gui_is_dragging(),"native drag remains active with bag visible")
	var up:=InputEventMouseButton.new();up.position=z;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false;Input.parse_input_event(up);await frames()
func shot(name_value:String)->void:
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name_value+".png")
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUT);Engine.set_meta("integration_seed",271828);Engine.set_meta("chest_open_preview",true)
	w=load("res://tests/world_clean_camp_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;b=s.builds;p=w.player
	w.environment_view.set_process(false);w.set_process(false);p.set_physics_process(false)
	while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
	if "restart" in OS.get_cmdline_user_args():
		w.persistent_world=true;s.save_path=OUT+"save.json";s.load_state();await frames()
		var ids:Array=b.states.keys();check(s.writable and ids.size()==1,"restart accepts chest open field without protecting save")
		if ids.size()==1:
			check(b.states[ids[0]].open and b.states[ids[0]].contents[10].count==7,"restart retains open state and legacy overflow")
			check(s.storage_ui.panel.visible and s.storage_ui.current==ids[0],"restart restores chest panel from chest state")
		finish();return
	var ui=w.item_ui;ui.toggle_bag();await frames(10);ui.fit_core_ui()
	check(ui.bag.visible and ui.equipment_panel.visible,"bag opens two independent panels")
	check(ui.bag.position.x>850 and ui.equipment_panel.position.x==16,"inventory fixed right equipment fixed left")
	check(ui.bag.get_global_rect().end.x<=1280 and ui.bag.get_global_rect().end.y<634,"right panel fits above hotbar")
	check(ui.cells.size()==43 and ui.cells[8].index==8 and ui.cells[16].index==16,"reordered visuals preserve logical slot indices")
	check(ui.cells[9].get_global_rect().position.x>ui.cells[8].get_global_rect().position.x and ui.cells[12].get_global_rect().position.y>ui.cells[8].get_global_rect().position.y,"inventory ordered horizontally in four columns")
	ui.fit_core_ui();await frames(3);ui.fit_core_ui()
	var original:Vector2=ui.bag.position
	var mouse:=InputEventMouseMotion.new();mouse.position=Vector2(700,300);ui._input(mouse);ui.fit_core_ui()
	print("BAG_FIXED_POINTER before=",original," after=",ui.bag.position," size=",ui.bag.size," scale=",ui.bag.scale)
	check(ui.bag.position.is_equal_approx(original),"mouse movement cannot drag bag (allow subpixel layout rounding)")
	for i in 40:s.inventory.slots[i]={}
	s.inventory.slots[0]={"item_id":"wood","count":4};s.inventory.changed.emit()
	var drag={"inventory":s.inventory,"slot":0,"item_id":"wood","count":4,"snapshot":s.inventory.slots[0].duplicate(true)}
	var at:Vector2=ui.cells[8].get_global_rect().get_center()
	var fire=preload("res://scripts/campfire.gd").new();fire.manager=s.camps;fire.camp_id="test-ui-fire"
	var fire_at:Vector2=root.get_canvas_transform().affine_inverse()*at
	s.camps.states[fire.camp_id]={"x":fire_at.x,"y":fire_at.y,"fuel":0.0,"lit":false,"recipe":"","elapsed":0.0,"ready":false,"hits":1}
	fire.position=fire_at;w.object_root.add_child(fire);s.camps.visuals[fire.camp_id]=fire
	check(s.camps.target_at(fire_at)==fire.camp_id,"real campfire is behind destination bag cell")
	check(not ui.can_drop_on_ground(at,drag),"inventory region cannot become world or fire drop")
	ui.drop_on_ground(drag,at)
	check(s.inventory.slots[0].count==4 and not ui.modal.visible,"direct ground drop guard preserves hotbar and avoids quantity modal")
	await native_drag(ui.cells[0],ui.cells[8])
	check(s.inventory.slots[0].is_empty() and s.inventory.slots[8].count==4 and ui.bag.visible,"hotbar drag to bag moves stack without hiding panels")
	check(not ui.can_drop_on_ground(ui.equipment_panel.get_global_rect().get_center(),{"inventory":s.inventory,"slot":8,"snapshot":s.inventory.slots[8].duplicate(true)}),"equipment region also blocks ground drop")
	check(s.camps.states[fire.camp_id].fuel==0 and not s.camps.states[fire.camp_id].lit,"native hotbar to bag drag never feeds underlying fire")
	fire.update_damage();check(fire.damage.visible,"campfire hammer feedback uses transient health bar");fire._process(2.01);check(not fire.damage.visible,"campfire health bar also expires after two seconds")
	s.camps.visuals.erase(fire.camp_id);s.camps.states.erase(fire.camp_id);fire.queue_free();await frames()
	var id:=place("wood_chest");check(not id.is_empty(),"place real legal chest");await frames()
	var node:Node2D=b.visuals[id];p.position=node.position+Vector2(0,45);p.camera.reset_smoothing();await frames(12)
	var storage=s.storage_ui;storage.open(id);await frames()
	check(storage.panel.visible and storage.cells.filter(func(cell):return cell.visible).size()==9 and storage.player_cells.is_empty(),"chest has independent nine slots and no duplicate inventory")
	check(storage.cells[0].size==Vector2(44,44),"chest slots use smaller actual dimensions")
	var title:Label=storage.panel.get_node("ChestTitle")
	check(is_equal_approx(title.position.x+title.size.x*.5,storage.panel.size.x*.5),"chest title centered on compact panel")
	check(storage.panel.size==Vector2(156,184),"chest frame tightly fits header and nine slots")
	check(b.states[id].open and not p.input_blocked and ui.bag.visible,"opening chest persists state without closing bag or blocking movement")
	check(storage.panel.z_index>node.z_index,"chest slots render above lid")
	var world_anchor:Vector2=root.get_canvas_transform().affine_inverse()*(storage.panel.position+Vector2(storage.panel.size.x*.5,storage.panel.size.y+45))
	check(world_anchor.distance_to(node.position)<.1,"panel anchor is chest world position")
	await shot("bag-and-chest")
	p.position+=Vector2(35,0);await frames(12)
	var after_anchor:Vector2=root.get_canvas_transform().affine_inverse()*(storage.panel.position+Vector2(storage.panel.size.x*.5,storage.panel.size.y+45))
	check(after_anchor.distance_to(world_anchor)<.1 and storage.panel.visible,"moving player keeps panel fixed to chest")
	p.position=node.position+Vector2(250,0);await frames()
	check(storage.panel.visible,"walking away does not close chest")
	check(b.transfer(id,0,8,{},s.inventory.get_slot(8).duplicate(true))=="请靠近木箱","distant chest transfer remains protected")
	p.position=node.position+Vector2(0,45)
	check(b.transfer(id,0,8,{},s.inventory.get_slot(8).duplicate(true)).is_empty(),"bag transfers into primary chest grid")
	b.states[id].contents[10]={"item_id":"branch","count":7};storage.refresh()
	check(storage.legacy_button.visible,"legacy overflow offers retrieval page")
	storage.legacy_button.pressed.emit()
	check(storage.cells[1].index==10 and storage.cells[1].visible and not storage.cells[3].visible,"legacy page exposes only old three cells")
	s.inventory.slots[9]={"item_id":"wood","count":1}
	check(not b.transfer(id,10,9,b.states[id].contents[10].duplicate(true),s.inventory.slots[9].duplicate(true)).is_empty(),"legacy cells refuse deposits or swaps")
	s.inventory.slots[11]={}
	check(b.transfer(id,10,11,b.states[id].contents[10].duplicate(true),{}).is_empty() and s.inventory.slots[11].count==7,"legacy item can be withdrawn without loss")
	b.states[id].contents[10]={"item_id":"branch","count":7}
	w.persistent_world=true;s.save_path="user://missing-chest-v1-dir/no-save.json"
	check(not b.set_chest_open(id,false).is_empty() and b.states[id].open,"failed close save rolls back open state")
	w.persistent_world=false
	storage.close_panel();check(not storage.panel.visible and not b.states[id].open,"closing chest hides only chest grid")
	check(ui.bag.visible and ui.equipment_panel.visible,"chest close preserves bag")
	storage.open(id);w.persistent_world=true;s.save_path=OUT+"save.json";check(s.save_state(),"isolated chest save commits open state and contents");w.persistent_world=false
	storage.close_panel();ui.close_panels();b.states.clear();b.refresh_all();await frames()
	id=place("stone_wall");await frames();node=b.visuals[id];p.position=node.position+Vector2(0,38)
	s.inventory.equipment.main_hand=s.inventory.instance("stone_hammer");s.inventory.changed.emit()
	Input.action_press("interact");p.facing="back";p.try_interact()
	for i in 42:p._physics_process(1.0/60)
	Input.action_release("interact")
	for i in 120:p._physics_process(1.0/60)
	check(int(b.states[id].hits)==1 and p.action.is_empty(),"releasing E finishes one strike without repeating")
	b.states[id].hits=0;node.damage.hide();node.damage_seconds=0
	check(not node.damage.visible,"unstruck building has no health bar")
	check(b.strike(id,node) and node.damage.visible,"successful hammer strike shows health bar")
	node._process(1.9);check(node.damage.visible,"bar remains until two seconds")
	node._process(.11);check(not node.damage.visible,"bar disappears after two seconds")
	node.update_damage();node._process(1);node.update_damage();node._process(1.5);check(node.damage.visible,"new hit restarts timeout")
	b.refresh_all();await frames();node=b.visuals[id];check(not node.damage.visible,"damaged reconstructed building does not show stale bar")
	node.update_damage();await create_timer(2.1).timeout;check(not node.damage.visible,"real frame processing expires hammer health bar")
	b.states[id].hits=0;p.facing="back";p.position=node.position+Vector2(0,38);ui.update_input_block()
	Input.action_press("interact");p.try_interact();check(p.action=="demolish" and p.hold_chop,"hammer starts repeatable action on E")
	for i in 500:
		p._physics_process(1.0/60)
		if i%4==0:await physics_frame
		if not b.states.has(id):break
	Input.action_release("interact");await frames()
	check(not b.states.has(id),"holding E completes repeated real strikes and demolition")
	check(p.action.is_empty() or p.action_committed,"destroyed target cannot begin a new strike")
	p.cancel_action();s.inventory.equipment.erase("main_hand");s.inventory.changed.emit();b.states.clear();b.refresh_all();await frames()
	for entry in [["wood_bed",false],["wood_bed",true],["straw_mat",false],["straw_mat",true]]:
		id=place(entry[0],entry[1]);check(not id.is_empty(),"legal sleep placement "+str(entry));await frames();node=b.visuals[id]
		var bounds:Rect2=b.footprint_rect(b.states[id]);var top:Vector2=node.position+Vector2(bounds.get_center().x,bounds.position.y)
		p.position=top+Vector2(0,-11);await physics_frame;await physics_frame
		check(not p.test_move(p.transform,Vector2(0,-5)),"head/upper approach can move along outside "+str(entry))
		check(p.test_move(p.transform,Vector2(0,8)),"bed ground footprint still blocks entry "+str(entry))
		check(preload("res://scripts/world_interaction.gd").in_reach(w.stream,p.position,node),"head/upper approach can E interact "+str(entry))
		check(s.sleep.start(id).is_empty(),"head/upper sleep controller accepts same footprint "+str(entry));s.sleep.interrupt()
		p.position=top+Vector2(0,-25);p.facing="front";p.camera.reset_smoothing();await shot(entry[0]+("-vertical" if entry[1] else "-horizontal"))
		b.states.clear();b.refresh_all();await frames()
	finish()
func finish()->void:
	w.persistent_world=false;s.dirty=false
	var failed=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+("restart" if "restart" in OS.get_cmdline_user_args() else "checks")+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("INVENTORY CHEST ",checks.size()," checks; ",failed," failures")
	w.queue_free();await frames();quit(0 if failed==0 else 1)
