extends SceneTree
const OUT="res://reports/planting-ui-floor-v2/"
var checks=[]
func check(ok:bool,label:String)->void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n:int=3)->void:
	for i in n:await process_frame
func _initialize()->void:call_deferred("run")
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUT);Engine.set_meta("integration_seed",98171023)
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	var s=w.item_service;var b=s.builds;var p=w.player;var menu=s.planting_ui
	w.environment_view.set_process(false);w.set_process(false);p.set_physics_process(false)
	while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
	if "read-destroyed" in OS.get_cmdline_user_args():
		w.persistent_world=true;s.save_path=OUT+"destroyed.json";s.load_state()
		check(s.writable and b.states.is_empty(),"new process restores destroyed plot as absent")
		check(s.inventory.count_item("carrot_seed")==2,"new process does not refund planted seed")
		check(s.inventory.count_item("wild_carrot")==0 and s.loose.is_empty(),"new process has no harvest or seed drops from demolition")
	else:
		for i in 40:s.inventory.slots[i]={}
		s.inventory.equipment.main_hand=s.inventory.instance("stone_pickaxe")
		var row={}
		for y in range(-4,5):
			for x in range(-4,5):
				var at:Vector2=w.generator.spawn+Vector2(x*96,y*64);p.position=at+Vector2(70,50)
				var candidate:Dictionary=b.candidate("tilled_soil",at,false,true,0)
				if b.reason(candidate).is_empty():row=candidate;break
			if not row.is_empty():break
		check(not row.is_empty() and b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"place real legal soil")
		await frames();var id:String=b.states.keys()[0];var node:Node2D=b.visuals[id];p.position=node.position+Vector2(0,32);p.facing="back";await physics_frame
		p.try_interact();await frames()
		check(menu.visible and menu.empty.visible and menu.empty.text=="没有种子","E opens selector with explicit empty message")
		check(p.input_blocked and b.states[id].crop.is_empty(),"opening selector blocks movement and never plants")
		var escape:=InputEventKey.new();escape.pressed=true;escape.physical_keycode=KEY_ESCAPE;w.item_ui._input(escape)
		check(not menu.visible and not p.input_blocked,"Escape closes without planting")
		s.inventory.slots[0]={"item_id":"branch","count":5};s.inventory.selected=0
		s.inventory.slots[8]={"item_id":"carrot_seed","count":3};s.inventory.slots[9]={"item_id":"potato_seed","count":2};s.inventory.slots[10]={"item_id":"cabbage_seed","count":2};s.inventory.changed.emit()
		p.try_interact();await frames()
		check(menu.visible and menu.choices.get_child_count()==3 and not menu.empty.visible,"bag seeds selectable without hotbar assignment")
		check(menu.panel.size==Vector2(400,300),"selector has stable size")
		var number:=InputEventKey.new();number.pressed=true;number.physical_keycode=KEY_4;w.item_ui._input(number)
		check(s.inventory.selected==0 and b.states[id].crop.is_empty(),"hotbar key is consumed while choosing, no accidental use")
		s.body.sleeping=true
		check(not menu.handle_input(number) and not menu.visible,"sleep closes selector and leaves input to existing sleep controller")
		s.body.sleeping=false;menu.open(id);await frames()
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"seed-menu.png")
		menu.choices.get_child(0).pressed.emit();await frames()
		check(b.states[id].crop=="carrot" and s.inventory.slots[8].count==2 and s.inventory.slots[0].count==5,"single click plants bag seed immediately and consumes only one")
		check(not menu.visible and not p.input_blocked,"successful click closes without confirmation")
		menu.choose("carrot_seed");check(s.inventory.count_item("carrot_seed")==2,"duplicate click cannot plant twice")
		for entry in [["potato_seed","potato",1],["cabbage_seed","cabbage",2]]:
			b.states[id].crop="";b.states[id].growth_minutes=0;menu.open(id)
			menu.choices.get_child(entry[2]).pressed.emit();await frames()
			check(b.states[id].crop==entry[1] and s.inventory.count_item(entry[0])==1,"correct seed button plants "+str(entry[1])+" directly")
		# Reuse same fixture plot to verify stale selection and failed-save rollback.
		b.states[id].crop="";b.states[id].growth_minutes=0
		menu.open(id);s.inventory.slots[8]={};s.inventory.changed.emit();menu.choose("carrot_seed")
		check(b.states[id].crop.is_empty() and s.inventory.count_item("carrot_seed")==0,"seed removed before click does not plant")
		s.inventory.slots[8]={"item_id":"carrot_seed","count":2};s.inventory.changed.emit()
		var old_path:String=s.save_path;s.save_path="user://missing-seed-selector-folder/no-save.json";w.persistent_world=true
		menu.choose("carrot_seed")
		check(b.states[id].crop.is_empty() and s.inventory.slots[8].count==2,"failed click save restores crop and bag seed")
		w.persistent_world=false;s.save_path=old_path;menu.close_panel()
		menu.open(id);b.states[id].crop="potato";menu.choose("carrot_seed")
		check(not menu.visible and s.inventory.count_item("carrot_seed")==2,"changed plot invalidates selector without consumption")
		b.states[id].crop="carrot";b.states[id].growth_minutes=120
		s.inventory.equipment.main_hand=s.inventory.instance("stone_hammer");s.inventory.changed.emit()
		var seed_before:int=s.inventory.count_item("carrot_seed");var loose_before:Dictionary=s.loose.duplicate(true)
		w.persistent_world=true;s.save_path=OUT+"destroyed.json"
		check(b.strike(id,node),"hammer destroys growing crop plot")
		await frames()
		check(not b.states.has(id) and not is_instance_valid(node),"plot and crop visual disappear together")
		check(s.inventory.count_item("carrot_seed")==seed_before and s.inventory.count_item("wild_carrot")==0 and s.loose==loose_before,"demolition grants neither harvest nor seed refund")
		check(not menu.open(id),"destroyed plot cannot reopen seed selector")
	w.persistent_world=false;s.dirty=false
	var failed=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+("restart" if "read-destroyed" in OS.get_cmdline_user_args() else "seed-menu")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("SEED SELECTOR ",checks.size()," checks; ",failed," failures")
	w.queue_free();await frames();quit(0 if failed==0 else 1)
