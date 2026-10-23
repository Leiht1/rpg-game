extends SceneTree
class Harness extends "res://scripts/combat_service.gd":
	func boar_clear(_at: Vector2,_next: Vector2,_node: CollisionObject2D=null) -> bool:return true
	func attack_path_clear(_at: Vector2,_target: Vector2,_id: String) -> bool:return true
var failed:=false
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failed=true
func _initialize() -> void:run.call_deferred()
func row(at: Vector2) -> Dictionary:return {"x":at.x,"y":at.y,"home_x":at.x,"home_y":at.y,"health":45.0,"mode":"patrol","clock":0.0,"hit":0.0,"generation":0,"facing_x":-1.0}
func run() -> void:
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.set_process(false);w.player.set_physics_process(false);w.item_service.set_process(false);w.environment_view.set_process(false)
	var s=w.item_service;var p=w.player;var ui=w.item_ui
	check(ui.bag_button.tooltip_text.is_empty() and ui.map_button.tooltip_text.is_empty(),"bag/map no hover tooltip")
	for i in 40:s.inventory.slots[i]={}
	s.inventory.equipment={};s.inventory.hotbar_equipment={};s.body.health=100;s.body.energy=100
	s.inventory.slots[0]=s.inventory.instance("wood_club")
	check(s.inventory.use_slot(0) and s.inventory.slots[0].is_empty(),"hotbar key equips")
	check(s.inventory.use_slot(0) and not s.inventory.slots[0].is_empty() and s.inventory.equipment.get("main_hand",{}).is_empty(),"same key unequips to original slot")
	check(s.inventory.use_slot(0),"same key equips again")
	p.facing="front";s.combat.personal.attack={};p.update_animation()
	var arm=p.character.get_node("Visual/Pelvis/ArmR");var pose: Transform2D=arm.transform
	ui.open_item_menu(0,Vector2(400,300));check(arm.transform==pose,"right click preserves held pose immediately");ui.close_item_actions()
	var c=Harness.new();c.service=s;c.state.population_initialized=true
	var at: Vector2=p.position;c.state.boars={"test":row(at)};var b: Dictionary=c.state.boars.test
	p.position=at+Vector2(100,0);c.advance_boars(.01);check(b.mode=="alert","detection starts alert before chase")
	var before: Vector2=Vector2(b.x,b.y);c.advance_boars(.3);check(b.mode=="alert" and before==Vector2(b.x,b.y),"alert pauses movement")
	c.advance_boars(.41);check(b.mode=="chase","chase begins after alert")
	p.position=at+Vector2(450,0);c.advance_boars(.1);check(b.mode=="chase","chase beyond initial notice range")
	p.position=at+Vector2(1200,0);c.advance_boars(.1);check(b.mode in ["return","patrol"],"eventual leash return")
	b.x=at.x;b.y=at.y;b.mode="chase";p.position=at+Vector2(30,0);c.advance_boars(.01);check(b.mode=="attack","attack commits")
	p.position=at+Vector2(1100,0);c.advance_boars(.4);check(b.mode=="attack" and not b.struck,"leaving detection does not cancel attack")
	c.advance_boars(.5);check(b.mode=="attack" and not b.struck,"miss continues through recovery")
	c.advance_boars(.3);check(b.mode=="chase","miss completes full action")
	# A stable network victim is hit once if it enters before the action ends.
	b.x=at.x;b.y=at.y;b.mode="attack";b.clock=.4;b.struck=false;b.attack_target="peer"
	c.personal.phase="entering";c.peers=[{"id":"peer","x":at.x+100,"y":at.y,"phase":"alive"}];c.damage_events=[]
	c.advance_boars(.1);check(c.damage_events.is_empty(),"out of range no damage")
	c.peers[0].x=at.x+30;c.advance_boars(.1);check(c.damage_events.size()==1 and b.mode=="attack","late contact during action hits")
	c.advance_boars(.1);check(c.damage_events.size()==1,"at most one hit per attack")
	b.mode="hurt";b.clock=0;b.facing_x=-1;c.advance_boars(.1);check(b.facing_x==-1,"hurt retains heading")
	var pig=load("res://scripts/combat_world_view.gd").Boar.new();pig.record=b;root.add_child(pig);pig.set_process(false)
	pig.position+=Vector2(8,0);pig._process(.016);check(pig.skeleton.scale.x==-1,"knockback displacement does not flip boar")
	b.mode="attack";b.clock=.45;pig._process(.016);check(pig.body.position!=Vector2(0,-24) and absf(pig.body.rotation)>.01,"attack moves full body")
	b.mode="patrol";pig.position+=Vector2(2,0);var t: float=pig.clock;pig._process(.1);var slow: float=pig.clock-t
	b.mode="chase";pig.position+=Vector2(2,0);t=pig.clock;pig._process(.1);check(pig.clock-t>slow*2,"chase steps faster than patrol")
	b.mode="attack";b.clock=1.17;b.struck=false;b.attack_target="peer";c.damage_events=[]
	c.advance_boars(.1);check(c.damage_events.is_empty() and b.mode=="chase","no contact after action ended")
	pig.queue_free();c=null
	# Actual native rig contact sheet, default project resolution.
	var layer:=CanvasLayer.new();layer.layer=2000;root.add_child(layer)
	var bg:=ColorRect.new();bg.size=Vector2(1280,720);bg.color=Color("d6dbc4");layer.add_child(bg)
	for r in 4:
		var view: String=["front","back","right","left"][r]
		for col in 6:
			var unarmed: bool=col<3;var elapsed: float=[.0,.125,.2,.0,.17,.26][col]
			var id: String="unarmed" if unarmed else "wood_club"
			s.inventory.equipment={} if unarmed else {"main_hand":s.inventory.instance(id)}
			p.facing=view;p.combat_render_state={};s.combat.personal.phase="alive";s.combat.personal.attack={"weapon":s.combat.rules.weapons[id],"elapsed":elapsed,"direction":{"x":1,"y":0},"targets":{}}
			p.update_animation()
			var rig=p.character.duplicate();layer.add_child(rig);rig.position=Vector2(25+col*205,r*175+5);rig.scale=Vector2.ONE*1.5;rig.get_node("AnimationPlayer").active=false
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/.tmp/combat-behavior-v3-sheet.png")
	# Normal-speed visual sample: three unarmed views, front club, patrol and attack.
	for child in layer.get_children():
		if child!=bg:child.queue_free()
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://reports/.tmp/combat-behavior-v3-motion")
	for frame in 30:
		var poses:=Node2D.new();layer.add_child(poses)
		for col in 4:
			var id: String="wood_club" if col==3 else "unarmed"
			var view: String=["front","back","right","front"][col]
			var elapsed: float=frame*.04
			s.inventory.equipment={} if col<3 else {"main_hand":s.inventory.instance(id)}
			p.facing=view;p.combat_render_state={}
			s.combat.personal.attack={"weapon":s.combat.rules.weapons[id],"elapsed":elapsed,"direction":{"x":1,"y":0},"targets":{}} if elapsed<(.74 if col==3 else .56) else {}
			p.update_animation()
			var rig=p.character.duplicate();poses.add_child(rig);rig.position=Vector2(10+col*220,125);rig.scale=Vector2.ONE*1.8;rig.get_node("AnimationPlayer").active=false
		for col in 2:
			var animal=load("res://scripts/combat_world_view.gd").Boar.new()
			animal.record=row(Vector2.ZERO);animal.record.facing_x=1;animal.record.mode="patrol" if col==0 else "alert" if frame<10 else "attack";animal.record.clock=maxf(0,(frame-10)*.04)
			poses.add_child(animal);animal.set_process(false);animal.position=Vector2(300+col*500,580);animal.scale=Vector2.ONE*2.4
			animal.clock=frame*.04*3;animal.previous=animal.position-Vector2(2,0);animal._process(.04)
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/.tmp/combat-behavior-v3-motion/%02d.png"%frame)
		poses.queue_free();await process_frame
	print("BEHAVIOR_V3 ",checks," checks ","FAIL" if failed else "PASS");quit(1 if failed else 0)
