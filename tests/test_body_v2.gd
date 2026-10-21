extends SceneTree
const Body = preload("res://scripts/body_state.gd")
const OUT = "res://reports/body-v2/"
var checks: Array = []
var world: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func units() -> void:
	for hours in [8,16,24]:
		for active in [false,true]:
			var b := Body.new()
			b.advance(hours*150.0,hours*60.0,false,active)
			check(is_equal_approx(b.hunger,maxf(0,100-hours*80.0/24.0*(1.15 if active else 1.0))),"hunger hours %d active %s"%[hours,active])
			check(is_equal_approx(b.energy,100-hours*3.2*(1.15 if active else 1.0)),"energy hours %d active %s"%[hours,active])
			check(b.health==100 and b.illness==0,"one day no immediate disease %d %s"%[hours,active])
	var b := Body.new();b.advance(3600,1440,false,false)
	check(is_equal_approx(b.hunger,20),"ordinary movement and waiting have same base rate")
	for active in [false,true]:
		b=Body.new();var hours := 0
		while b.energy>0: b.advance(150,60,false,active);hours+=1
		check(hours>=27 and hours<=32,"forced threshold 27-32 hours active %s"%active)
	var db := ItemDatabase.new()
	var count := 0
	for id in db.definitions:
		var row: Dictionary=db.item(id)
		if row.get("use_action")!="eat": continue
		count+=1
		var inv := ItemInventory.new(db);b=Body.new();inv.body=b
		inv.add(id,2);inv.move_slot(8,0)
		check(not inv.use_slot(0) and inv.count_item(id)==2,"full refuses "+id)
		b.hunger=10;b.energy=33;b.stamina=44;b.health=66
		check(inv.use_slot(0) and is_equal_approx(b.hunger,10+row.effects.hunger) and inv.count_item(id)==1,"hotbar one effect "+id)
		check(b.energy==33 and b.stamina==44 and b.health==66,"food only hunger "+id)
		inv.move_slot(0,8);b.hunger=99
		check(inv.use_slot(8) and b.hunger==100 and inv.count_item(id)==0,"bag single clamps "+id)
	check(count==db.definitions.values().filter(func(row):return row.get("use_action")=="eat").size(),"all current edible foods enumerated")
	b=Body.new();b.advance(50,20,true,false)
	check(b.stamina==0 and b.exhausted,"50 simulated seconds sprint")
	b.advance(12,4.8,false,false);check(b.stamina>=12 and not b.exhausted,"stamina delay and recovery retained")
	b=Body.new();b.energy=0;b.start_sleep(480,true);b.advance(447.5,179,false,false)
	check(b.sleeping,"forced cannot wake before three hours")
	b.advance(2.5,1,false,false)
	check(not b.sleeping and is_equal_approx(b.energy,39),"forced wakes after three hours with 39 energy")
	b.advance(150,60,false,false);check(b.energy>35,"no repeated fainting")
	b=Body.new();b.energy=0;b.start_sleep(1320);check(b.sleep_duration==480,"night 22 to 06 eight hours")
	b.advance(1200,480,false,false);check(is_equal_approx(b.energy,100-(480-b.sleep_elapsed)/60.0*float(b.rules.energy_per_hour)) and not b.sleeping,"reaches full then spends remaining elapsed minutes awake")
	b.energy=20;b.start_sleep(1200);check(b.sleep_duration==600,"early night prioritizes six AM within ten hours")
	b.sleeping=false
	b.energy=20;b.start_sleep(720);check(b.sleep_duration==180,"day nap three hours")
	var saved := b.serialize();var restored := Body.new()
	check(restored.restore(saved) and restored.serialize()==saved,"sleep state full round trip")
	var legacy: Dictionary=saved.duplicate(true);legacy.version=1
	for key in ["energy","sleeping","sleep_forced","sleep_elapsed","sleep_duration"]: legacy.erase(key)
	check(restored.restore(legacy) and restored.energy==100 and not restored.sleeping,"v1 defaults healthy energy")
	for key in ["energy","sleep_elapsed","sleep_duration"]:
		var bad: Dictionary=saved.duplicate(true);bad[key]=INF
		check(not restored.restore(bad),"reject infinite "+key)
	var bad: Dictionary=saved.duplicate(true);bad.version=999
	check(not restored.restore(bad),"unknown body version protected")
	b=Body.new();b.hunger=0;b.advance(30,12,false,false);check(b.health==100 and b.illness==0,"short zero hunger safe")
	b.advance(5650,2260,false,false);check(b.illness>=.45 and b.health<100,"prolonged zero hunger disease")
	var hp := b.health;b.eat({"hunger":100});b.advance(100,40,false,false)
	check(b.health>=hp and b.damage_clock==0,"nutrition stops disease damage")
	b.health=1;b.energy=0;b.start_sleep(480,true);b.advance(450,180,false,false)
	check(not b.down and b.health>=30 and not b.sleeping,"sleep and low health care cooperate")
func run() -> void:
	Engine.max_fps=60
	units()
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	var s = world.item_service;var p = world.player;var ui = world.item_ui
	var v = world.environment_view;var env = v.simulation;var b = s.body
	env.paused=true;p.set_physics_process(false)
	while not world.stream.viewport_ready(p.position,Vector2(640,360)): await process_frame
	var before: Dictionary=b.serialize();env.set_time(12);await frames()
	check(b.serialize()==before,"paused and set time do not catch up body")
	env.paused=false;v.preview=true;before=b.serialize();v._process(.1)
	check(b.serialize()==before,"debug preview excludes body")
	v.preview=false;env.paused=true
	v.preview=true;v.previous_scale=1.0;v.previous_pause=true;env.time_scale=60
	check(s.snapshot().body_environment.time_scale==1.0 and s.snapshot().body_environment.paused,"preview speed excluded from atomic snapshot")
	v.preview=false;env.time_scale=1.0
	for energy in [100,50,25,10]:
		b.energy=energy;check(is_equal_approx(b.efficiency(),1.0 if energy>=35 else .88 if energy>=15 else .70),"efficiency tier %d"%energy)
	# Real character physics movement uses the same authority as labor clock.
	p.automated=true;p.input_override=Vector2.RIGHT;p.run_override=false
	var origin: Vector2=p.position;var rates: Array=[]
	for energy in [100,25,10]:
		p.position=origin;b.energy=energy;p.input_blocked=false;p.action=""
		p._physics_process(1.0/60.0);rates.append(p.velocity.length())
	check(is_equal_approx(rates[1]/rates[0],.88) and is_equal_approx(rates[2]/rates[0],.70),"real physics speed penalties")
	p.position=origin;p.input_override=Vector2.ZERO
	# Use a valid native target; a null demolition target must cancel immediately.
	var clock_target: Node2D=s.create_harvest("body-v2:clock",{"kind":"stone_outcrop","x":origin.x,"y":origin.y-45})
	s.inventory.equipment.main_hand=s.inventory.instance("stone_pickaxe");p.set_equipment(s.inventory)
	for energy in [100,25,10]:
		b.energy=energy;p.action="mine";p.action_target=clock_target;p.action_clock=0;p.action_committed=false
		p._physics_process(.1)
		check(is_equal_approx(p.action_clock,.1*b.efficiency()) and not p.action_committed,"real labor clock synced %d"%energy)
	p.cancel_action();clock_target.queue_free();await frames()
	b.energy=0;p.action="pickup"
	check(not v.try_start_sleep(true) and not b.sleeping,"sleep waits for pickup transaction")
	p.cancel_action();s.craft_busy=true
	check(not v.try_start_sleep(true),"sleep waits for craft commit")
	s.craft_busy=false
	ui.toggle_bag();world.camp_ui.placing=true
	check(v.try_start_sleep(true) and b.sleeping and p.input_blocked and not ui.bag.visible and not world.camp_ui.placing,"forced sleep closes UI placement and locks input")
	var pos: Vector2=p.position;p.input_override=Vector2.RIGHT;p._physics_process(.1)
	check(p.position==pos and not s.inventory.use_slot(0),"sleep blocks movement and item use")
	env.paused=false;env.minute=1320;env.force_weather(2)
	s.camps.states["sleep:test"]={"x":origin.x+80,"y":origin.y,"fuel":1200.0,"lit":true,"recipe":"roast_carrot","elapsed":0.0,"ready":false}
	s.camps.burning["sleep:test"]=true
	var weather_before: float=env.transition_elapsed
	v.advance_gameplay(30)
	check(is_equal_approx(env.minute,1332) and is_equal_approx(b.sleep_elapsed,12),"sleep clock and body same twelve game minutes")
	check(env.transition_elapsed>weather_before and s.camps.states["sleep:test"].fuel<1170 and s.camps.states["sleep:test"].ready,"sleep advances rain fuel and cooked task")
	var h: float=b.hunger;var e: float=b.energy
	check(s.camps.act("sleep:test","claim")=="" and b.hunger==h and b.energy==e,"claim grants food without applying food effect")
	check(not s.camps.act("sleep:test","claim").is_empty(),"claim cannot duplicate")
	v.advance_gameplay(420)
	check(not b.sleeping and not p.input_blocked and is_equal_approx(b.energy,39),"normal elapsed three hours unlocks wakeup at 39 energy")
	print("FORCED CLOCK ",env.minute," energy ",b.energy," elapsed ",b.sleep_elapsed)
	check(is_equal_approx(env.minute,60),"forced total three hours world time")
	b.energy=20;env.minute=1320
	check(not v.try_start_sleep(false) and not b.sleeping,"manual ground sleep remains unavailable at night")
	b.energy=20;env.minute=720
	check(not v.try_start_sleep(false) and not b.sleeping,"manual ground sleep remains unavailable during day; facilities own manual sleep")
	b.stamina=0;b.exhausted=true;b.energy=100;p.input_blocked=false;p.input_override=Vector2.RIGHT;p.run_override=true;p._physics_process(.016)
	check(not p.running and p.velocity.length()>0,"exhausted still walks")
	p.cancel_action();p.input_override=Vector2.ZERO
	env.paused=true
	# Exercise actual hit settlement under slowed logical clocks and zero-energy handoff.
	for row in [["mine","stone_pickaxe","stone_outcrop",.55],["dig","simple_shovel","buried_bone",.68]]:
		var id: String="body-v2:action:"+row[0]
		var target: Node2D=s.create_harvest(id,{"kind":row[2],"x":origin.x,"y":origin.y-45})
		s.inventory.equipment.main_hand=s.inventory.instance(row[1]);p.set_equipment(s.inventory)
		p.position=origin;p.facing="back";p.action=row[0];p.action_target=target;p.action_clock=0;p.action_committed=false
		b.energy=10;b.stamina=100;b.exhausted=false;p.input_blocked=false
		var elapsed := 0.0
		while not p.action.is_empty() and p.action_clock<float(row[3])-.00001 and elapsed<5:
			p._physics_process(.01);elapsed+=.01
		check(elapsed>float(row[3])/0.71 and s.resource_hits.get(id,0)==1,"slow real hit exactly once "+row[0])
		p._physics_process(.03)
		check(s.resource_hits.get(id,0)==1 and s.inventory.equipment.main_hand.durability==99,"no extra hit or wear "+row[0])
		check(is_equal_approx(b.stamina,100-float(b.rules.labor_cost[row[0]])),"unchanged stamina cost "+row[0])
		if DisplayServer.get_name()!="headless":
			p.camera.position_smoothing_enabled=false;p.camera.force_update_scroll();ui.body_ui.refresh();await frames(3)
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"slowed-"+row[0]+".png")
		# New action starts while energetic, then energy reaches zero before its hit.
		p.cancel_action();b.energy=1
		p.action=row[0];p.action_target=target;p.action_clock=float(row[3])-.005;p.action_committed=false;b.energy=0
		p._physics_process(.02)
		check(s.resource_hits.get(id,0)==2 and s.inventory.equipment.main_hand.durability==98,"pending action safely settles at zero energy "+row[0])
		check(not v.try_start_sleep(true),"force waits for action end "+row[0])
		var finish_steps := 0
		while not p.action.is_empty() and finish_steps<100:
			p._physics_process(.05);finish_steps+=1
		check(p.action.is_empty(),"native action completes within bounded normal clock "+row[0])
		check(v.try_start_sleep(true) and b.sleeping,"force enters after native action completes "+row[0])
		env.paused=false;v.advance_gameplay(450);env.paused=true
		check(s.resource_hits.get(id,0)==2 and s.inventory.equipment.main_hand.durability==98,"sleep never repeats prior action settlement "+row[0])
		target.queue_free();await frames()
	var tree: Node2D
	for node in get_nodes_in_group("trees"):
		var at: Vector2=node.position+Vector2(0,48)
		if world.generator.can_walk(at,12) and world.stream.tree_in_reach(at,node): tree=node;break
	check(tree!=null,"real approachable tree for slowed chop")
	if tree!=null:
		s.inventory.equipment.main_hand=s.inventory.instance("stone_axe");p.set_equipment(s.inventory)
		p.position=tree.position+Vector2(0,48);b.energy=10;b.stamina=100;b.exhausted=false;p.input_blocked=false
		p.action="chop";p.action_target=tree;p.action_clock=.35;p.action_committed=false;p.facing="back"
		var id: String=tree.get_meta("prop_id");var hits: int=world.stream.tree_hits.get(id,0)
		p._physics_process(.02);p._physics_process(.02)
		check(world.stream.tree_hits.get(id,0)==hits+1 or world.stream.harvested.has(id),"slowed real chop one hit")
		check(s.inventory.equipment.main_hand.durability==99 and b.stamina==98.5,"slowed chop same durability and stamina")
		p.cancel_action()
	p.position=origin;b.energy=100;p.camera.position_smoothing_enabled=false;p.camera.force_update_scroll()
	# Chest is closed through its public lifecycle, so it can open again after sleep.
	s.builds.states["body-v2:chest"]=s.builds.candidate("wood_chest",origin+Vector2(64,0),false,true,0)
	s.storage_ui.open("body-v2:chest");b.energy=0;env.paused=false;env.minute=720
	check(v.try_start_sleep(true) and not s.storage_ui.panel.visible and s.storage_ui.visible,"forced sleep closes storage without hiding reusable root")
	v.advance_gameplay(450);s.storage_ui.open("body-v2:chest")
	check(s.storage_ui.panel.visible and s.storage_ui.is_visible_in_tree(),"storage usable after waking")
	s.storage_ui.close_panel();env.paused=true
	var before_sleep: Dictionary=b.serialize();world.persistent_world=true
	var previous_path: String=s.save_path;s.save_path="res://reports/body-v2/no-such-folder/save.json";b.energy=20
	check(not v.try_start_sleep(true) and not b.sleeping,"failed initial save rolls back sleep state")
	s.save_path=previous_path;world.persistent_world=false;b.restore(before_sleep)
	# One complete handoff on the real engine physics/process loops, without manual seek/tick.
	var native_id := "body-v2:engine-loop"
	var native_target: Node2D=s.create_harvest(native_id,{"kind":"stone_outcrop","x":origin.x,"y":origin.y-45})
	s.inventory.equipment.main_hand=s.inventory.instance("stone_pickaxe");p.set_equipment(s.inventory)
	p.position=origin;p.input_override=Vector2.ZERO;p.input_blocked=false;p.action="mine";p.action_target=native_target;p.action_clock=0;p.action_committed=false;p.hold_chop=false
	b.energy=0;b.stamina=100;b.exhausted=false;env.paused=false
	p.set_physics_process(true)
	for i in 600:
		if b.sleeping: break
		await physics_frame
	check(b.sleeping and p.action.is_empty(),"engine loops finish action then force sleep")
	check(s.resource_hits.get(native_id,0)==1 and s.inventory.equipment.main_hand.durability==99,"engine loops settle exactly one hit and wear")
	p.set_physics_process(false);env.paused=false;v.advance_gameplay(450)
	for i in 6:
		if not b.sleeping: break
		await physics_frame
	check(not b.sleeping and b.energy>=38 and not p.input_blocked and s.resource_hits.get(native_id,0)==1,"engine loops wake and restore input without duplicate hit")
	p.set_physics_process(false);env.paused=true;native_target.queue_free()
	for size in [Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),ProjectSettings.get_setting("display/window/size/viewport_height"))]:
		root.size=size;root.content_scale_size=size;ui.fit_core_ui();await frames(6);ui.body_ui.refresh()
		check(not ui.body_ui.hud.get_global_rect().intersects(ui.dock.get_global_rect()),"HUD clear of dock %s"%size)
		check(ui.body_ui.bars.size()==4 and ui.body_ui.hud.get_global_rect().position.y>=0,"four bars fit %s"%size)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+"hud-%d.png"%size.x)
		ui.body_ui.toggle();await frames(3)
		check(not ui.body_ui.hud.visible and not ui.dock.visible,"modal detail avoids HUD dock overlap %s"%size)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+"detail-%d.png"%size.x)
		print("PAPER ",size," actual ",ui.body_ui.paper.size," scale ",ui.body_ui.paper.scale," rect ",ui.body_ui.paper.get_global_rect())
		check(ui.body_ui.paper.get_global_rect().end.y<=size.y,"detail fits %s"%size)
		ui.body_ui.close_panel()
	env.paused=true
	var failed := checks.filter(func(row):return not row.pass).size()
	var mode := "headless" if DisplayServer.get_name()=="headless" else "window"
	FileAccess.open(OUT+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("BODY V2 ",mode,": ",checks.size()," checks; ",failed," failures")
	s.dirty=false;world.queue_free();await frames(6);quit(0 if failed==0 else 1)
