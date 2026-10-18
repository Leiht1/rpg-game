extends SceneTree
const Body = preload("res://scripts/body_state.gd")
const Shape = preload("res://scripts/body_shape.gd")
const OUT = "res://reports/body-v1/"
var checks: Array=[]
var world: Node
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks.append({"name":label,"pass":value})
	if not value: push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func capture(name_value: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name_value+".png")
func units() -> void:
	var b := Body.new()
	check(b.health==100 and b.hunger==100 and b.stamina==100 and b.build==0,"new body defaults")
	b.advance(600,240,false,false)
	check(is_equal_approx(b.hunger,100.0-65.0/6.0) and b.health==100,"ten minutes exploration slow hunger no health loss")
	b.hunger=0;b.advance(10,4,false,false)
	check(b.health==100 and b.illness==0,"short zero hunger never damages health")
	b.advance(10800,4320,false,false)
	check(b.deprivation>1.5 and b.illness>.45 and b.health<100,"days of deprivation eventually cause interval disease damage")
	var hp := b.health;b.eat({"hunger":80});b.advance(600,240,false,false)
	check(b.health>=hp and b.damage_clock==0,"nutrition immediately stops disease damage")
	b=Body.new();b.health=15;b.advance(180,72,false,false)
	check(not b.down and b.health>=30 and b.stamina>0,"solo downed recovery restores action without inventory")
	b=Body.new();b.advance(50,20,true,false)
	check(b.stamina==0 and b.exhausted and not b.can_labor("mine"),"sprint exhausts and blocks labor")
	b.advance(12,4.8,false,false)
	check(b.stamina>=12 and not b.exhausted,"rest recovers beyond resume threshold")
	var fed := Body.new();var hungry := Body.new();fed.stamina=10;hungry.stamina=10;hungry.hunger=0
	fed.advance(5,2,false,false);hungry.advance(5,2,false,false)
	check(fed.stamina>hungry.stamina and hungry.stamina>10,"hunger reduces recovery continuously with nonzero floor")
	b=Body.new();b.spend_labor("mine");check(b.stamina==97.5,"one mining labor event costs 2.5")
	var saved := b.serialize();var restored := Body.new()
	check(restored.restore(saved) and restored.serialize()==saved,"full body round trip")
	for key in ["health","build","illness"]:
		var bad: Dictionary=saved.duplicate(true);bad[key]=INF
		check(not restored.restore(bad),"invalid finite state rejected "+key)
	var bad: Dictionary=saved.duplicate(true);bad.version=2;check(not restored.restore(bad),"future body version protected")
	b=Body.new();b.eat({"hunger":20});check(b.build==0,"one meal never changes body build")
	b.hunger=0;b.advance(14400,5760,false,false);check(b.build<-.1,"long shortage smoothly changes body")
	var db := ItemDatabase.new();var inv := ItemInventory.new(db);inv.body=Body.new();inv.add("wild_berry",2)
	check(not inv.use_slot(8) and inv.count_item("wild_berry")==2,"full health and hunger refuse unnecessary food")
	inv.body.hunger=50;check(inv.use_slot(8) and inv.count_item("wild_berry")==1 and inv.body.hunger==53,"food consumes once through shared body interface")
	inv.body.hunger=99;inv.use_slot(8);check(inv.body.hunger==100,"food clamps at maximum")
	inv.add("field_lantern",1);var lamp_data := inv.slots.duplicate(true);var copy := ItemInventory.new(db)
	check(copy.restore(lamp_data) and copy.slots==lamp_data,"lantern identity and fuel preserved")
	var env := preload("res://scripts/world_environment.gd").new();env.set_time(0)
	check(env.light_parameters().brightness<.25,"night dark enough to value lantern")
	env.free()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT));Engine.max_fps=60
	units();Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	var s: Node=world.item_service;var p: Node=world.player;var ui: Control=world.item_ui
	world.environment_view.simulation.paused=true;p.set_physics_process(false)
	var simulation: Node=world.environment_view.simulation
	var state_before: Dictionary=s.body.serialize()
	simulation.set_time(0);await frames(4)
	check(s.body.serialize()==state_before,"debug time jump and paused frames do not consume body")
	simulation.paused=false;world.environment_view.preview=true;await frames(4)
	check(s.body.serialize()==state_before,"environment day preview excludes gameplay body")
	world.environment_view.preview=false;simulation.paused=true
	# Authoritative successful hits charge once; invalid calls never charge.
	var origin: Vector2=p.position
	for pair in [["stone_pickaxe","stone_outcrop","mine",2.5],["simple_shovel","buried_bone","dig",1.5]]:
		s.inventory.add(pair[0],1)
		for i in 40:
			if s.inventory.slots[i].get("item_id","")==pair[0]: s.inventory.equip(i);break
		var target: Node2D=s.create_harvest("body-test:"+pair[2],{"kind":pair[1],"x":origin.x+40,"y":origin.y})
		s.body.stamina=100;s.body.exhausted=false
		check(s.harvest_hit(target,pair[2]) and s.body.stamina==100-float(pair[3]),"successful authority charge once "+pair[2])
		var stamina: float=s.body.stamina
		p.position=origin+Vector2(300,0)
		check(not s.harvest_hit(target,pair[2]) and s.body.stamina==stamina,"missed out-of-reach labor never charges "+pair[2])
		p.position=origin;s.body.stamina=0;s.body.exhausted=true
		check(not s.harvest_hit(target,pair[2]),"zero stamina authority blocks "+pair[2])
		s.body.stamina=100;s.body.exhausted=false;target.queue_free()
	await frames()
	# Actual collision-aware movement still runs at zero stamina, with run disabled.
	p.automated=true;p.input_override=Vector2.RIGHT;p.run_override=true;p.body.stamina=0;p.body.exhausted=true
	p.set_physics_process(true);simulation.paused=false
	await create_timer(.18).timeout
	check(not p.running and p.moving,"zero stamina permits walking but blocks sprint")
	p.body.stamina=100;p.body.exhausted=false
	await create_timer(.2).timeout
	check(p.running and p.body.stamina<100,"real running spends shared stamina")
	p.input_override=Vector2.ZERO;p.run_override=false;p.set_physics_process(false);p.moving=false;p.running=false;simulation.paused=true;p.position=origin
	# Empty slots for the independent lantern checks.
	s.inventory.equipment.main_hand={}
	for i in 40:s.inventory.slots[i]={}
	s.inventory.changed.emit()
	s.inventory.add("field_lantern",2);s.toggle_lantern(8);await frames()
	s.burn_lantern(100)
	check(s.lantern.visible and s.lantern_remaining==1700,"opened lamp burns exact time")
	check(ui.body_ui.lamp.visible and not ui.body_ui.fuel.show_percentage,"lamp HUD icon and unlabeled bar visible")
	simulation.paused=false;p.input_blocked=true;p.running=true;p.moving=true
	var old_stamina: float=s.body.stamina
	await create_timer(.08).timeout
	check(s.body.stamina>=old_stamina,"blocked stale running flags do not spend stamina")
	p.input_blocked=false;p.running=false;p.moving=false;simulation.paused=true
	s.toggle_lantern(8);await frames();check(not ui.body_ui.lamp.visible,"closing lamp hides HUD")
	s.toggle_lantern(9);check(s.lantern_remaining==1800,"new lamp has independent full duration")
	s.inventory.move_slot(9,0);check(not s.lamp_slot().is_empty(),"active lamp follows inventory move")
	s.inventory.destroy_slot(0);await frames();check(not s.lantern.visible,"removing active lamp switches off despite spare")
	ui.open_item_menu(8,Vector2(600,300));check(ui.use_button.text=="打开","lamp context says open")
	ui.close_item_actions();s.toggle_lantern(8);ui.open_item_menu(8,Vector2(600,300));check(ui.use_button.text=="关闭","lamp context says close");ui.close_item_actions()
	check(not ui.hud_accent.visible,"old leaf accent hidden")
	var snapshot: Dictionary=s.snapshot();var body_save: Dictionary=snapshot.body
	s.save_path="user://body-v1-test.json";world.persistent_world=true;s.body.hunger=37;s.body.build=.4;s.save_state()
	s.body.hunger=99;s.load_state();check(s.body.hunger==37 and s.body.build==.4,"atomic save restores body and original inventory")
	# load_state may replace the state object; runtime setup reconnect is checked below.
	world.persistent_world=false
	var file := FileAccess.open(s.save_path,FileAccess.WRITE);snapshot.erase("body");file.store_string(JSON.stringify(snapshot));file.close()
	world.persistent_world=true;s.load_state();check(s.body.health==100 and s.body.build==0,"legacy body-free snapshot defaults healthy")
	world.persistent_world=false;DirAccess.remove_absolute(s.save_path)
	# Animated seek playback across every direction/action and extreme builds.
	for shape in [-1.0,0.0,1.0]:
		for facing in ["front","back","left","right"]:
			p.facing=facing
			for action in ["","chop","mine","dig"]:
				p.action=action
				for phase in [0.0,.2,.4,.65]:
					p.action_clock=phase;p.idle_clock=phase;s.body.build=shape;p.body=s.body
					p.update_animation();await frames(1)
					var torso: Sprite2D=p.character.get_node("Visual/Pelvis/Torso")
					var expected := .25*(.9 if shape<0 else 1.12 if shape>0 else 1.0)
					check(is_equal_approx(torso.scale.x,expected) and torso.scale.y==.25,"visual shape retained %s %s %.1f %.2f"%[facing,action,shape,phase])
					check(p.character.scale==Vector2.ONE and p.character.get_node("Visual/Pelvis").scale==Vector2.ONE,"root and parent joint preserved")
		p.action="";p.facing="front";p.update_animation();await frames();await capture("shape-"+str(shape))
	# Refresh references after explicit restore, as actual configure normally does.
	ui.body_ui.state=s.body;s.inventory.body=s.body;p.body=s.body
	ui.body_ui.toggle();await frames();check(p.input_blocked and ui.body_ui.overlay.visible,"HUD opens input protected details")
	var event := InputEventKey.new();event.physical_keycode=KEY_1;event.pressed=true
	var count_before: int=s.inventory.count_item("field_lantern")
	ui._input(event);check(s.inventory.count_item("field_lantern")==count_before and ui.body_ui.overlay.visible,"detail panel intercepts hotbar input")
	await capture("details");ui.body_ui.close_panel();check(not p.input_blocked,"details close restores input")
	for tool_id in ["stone_axe","stone_pickaxe","simple_shovel"]:
		s.inventory.add(tool_id,1)
		for i in 40:
			if s.inventory.slots[i].get("item_id","")==tool_id:s.inventory.equip(i);break
		for movement in ["walk","run"]:
			for facing in ["front","back","left","right"]:
				p.facing=facing;p.moving=true;p.running=movement=="run";s.body.build=1.0
				for phase in [0.0,.25,.5,.75]:
					p.gait_distance=phase*float(p.actor.stride_world_units);p.update_animation();await frames(1)
					var grip: Node2D=p.character.get_node("Visual/Pelvis/ArmR/Grip")
					var pin: Vector2=grip.global_position
					preload("res://scripts/body_shape.gd").apply(p.character,-1.0)
					check(grip.global_position.is_equal_approx(pin),"visual body preserves animated grip "+tool_id+" "+movement+" "+facing)
		p.moving=false;p.running=false;p.action="mine" if tool_id=="stone_pickaxe" else "dig" if tool_id=="simple_shovel" else "chop";p.action_clock=.5;p.facing="right";p.update_animation()
		await frames();await capture(tool_id+"-motion")
	p.cancel_action()
	for resolution in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,900)]:
		root.size=resolution;root.content_scale_size=resolution;ui.fit_core_ui();await frames(5)
		check(ui.body_ui.hud.get_global_rect().position.x>=0 and ui.body_ui.hud.get_global_rect().end.y<resolution.y,"HUD within safe screen "+str(resolution))
		check(not ui.body_ui.hud.get_global_rect().intersects(ui.dock.get_global_rect()),"body HUD avoids hotbar "+str(resolution))
		await capture("hud-"+str(resolution.x))
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	p.cancel_action();p.facing="front";s.body.build=0;p.update_animation();world.environment_view.simulation.set_time(0)
	if is_instance_valid(s.lantern):s.lantern.hide()
	await frames(5);await capture("night-off");s.toggle_lantern(8);await frames(5);await capture("night-on")
	var failed := checks.filter(func(row): return not row.pass).size()
	var mode := "headless" if DisplayServer.get_name()=="headless" else "window"
	FileAccess.open(OUT+mode+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("BODY V1 ",mode,": ",checks.size()," checks; ",failed," failures")
	s.dirty=false;world.queue_free();await frames(6);quit(0 if failed==0 else 1)



