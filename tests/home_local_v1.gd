extends "res://tests/sleep_v8_fixture.gd"
const Combat=preload("res://scripts/combat_world_view.gd")
class Harness extends "res://scripts/combat_service.gd":
	func boar_clear(_at: Vector2,_next: Vector2,_node: CollisionObject2D=null) -> bool:return true
	func attack_path_clear(_at: Vector2,_target: Vector2,_id: String) -> bool:return true
class TestTree extends Node2D:
	var required_hits:=4
	func hit() -> void:pass
	func fade_out() -> void:pass
var out:="res://reports/home-local-v1/"
func row(at: Vector2) -> Dictionary:
	return {"x":at.x,"y":at.y,"home_x":at.x,"home_y":at.y,"health":45.0,"mode":"chase","clock":0.0,"hit":0.0,"generation":0,"facing_x":-1.0}
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds
	w.set_process(false);w.player.set_physics_process(false);s.set_process(false);v.set_process(false);s.combat_view.set_process(false)
	root.size=default_size();root.content_scale_size=root.size
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	check(not w.persistent_world,"isolated local world")
	var at: Vector2=w.player.position
	for id in ["stone_axe","stone_pickaxe","simple_shovel","stone_hammer","copper_axe","copper_pickaxe","copper_shovel","copper_hammer"]:
		s.inventory.equipment.main_hand=s.inventory.instance(id)
		check(s.inventory.harvest_power()==(2 if id.begins_with("copper") else 1),"harvest power "+id)
	# Actual harvest service, including odd counts and mixed progress.
	var resources: Dictionary=preload("res://scripts/harvest_node.gd").configuration().resources
	for kind in resources:
		var definition: Dictionary=resources[kind]
		var tool: String="copper_pickaxe" if definition.action=="mine" else "copper_shovel"
		s.inventory.equipment.main_hand=s.inventory.instance(tool)
		var spot: Vector2=at+Vector2(0,45)
		var id: String="test:half:"+kind
		var node=s.create_harvest(id,{"x":spot.x,"y":spot.y,"kind":kind})
		check(node!=null,"create resource "+kind)
		var hits:=0
		while not s.consumed.has(id) and hits<30:
			s.body.stamina=100;s.body.energy=100;w.player.action=str(definition.action)
			if not s.harvest_hit(node,str(definition.action)):break
			hits+=1
		check(hits==ceili(float(definition.hits)/2) and s.consumed.has(id),"half hits ceil and completes "+kind)
		check(int(s.inventory.equipment.main_hand.durability)==250-hits,"one durability per actual strike "+kind)
		if is_instance_valid(node):node.queue_free()
		await frames(2)
	w.player.action=""
	for tool_id in ["stone_axe","copper_axe"]:
		for required in [4,8]:
			var tree:=TestTree.new();tree.required_hits=required;tree.position=at+Vector2(0,60);tree.set_meta("prop_id","test-tree:"+tool_id+str(required));tree.add_to_group("trees");w.object_root.add_child(tree)
			s.inventory.equipment.main_hand=s.inventory.instance(tool_id)
			var strikes:=0
			while not w.stream.harvested.has(tree.get_meta("prop_id")) and strikes<12:
				s.body.stamina=100;s.body.energy=100;w.player.action="chop";w.stream.chop_tree(tree);strikes+=1
			check(strikes==required/(2 if tool_id=="copper_axe" else 1),"tree strike count "+tool_id+str(required))
			var wood:=0
			for key in s.loose:
				if str(key).begins_with(tree.get_meta("prop_id")+":"):wood+=int(s.loose[key].count)
			check(wood==required/4*6,"tree reward milestones preserved "+tool_id+str(required))
			tree.queue_free();await frames(2)
	w.player.action=""
	# Keep legacy fuel capacities/IDs; burn faster so old saves remain valid.
	for id in ["field_lantern","silver_lantern"]:
		if not s.database.definitions.has(id):continue
		var lamp: Dictionary=s.inventory.instance(id)
		s.inventory.slots[0]=lamp;s.active_lamp="";s.toggle_lantern(0)
		var capacity: float=lamp.fuel
		s.burn_lantern(capacity*.75-1)
		check(is_equal_approx(lamp.fuel,4.0/3.0),"lamp duration .75 "+id)
		s.burn_lantern(1)
		check(s.lantern_remaining==0 and not s.lantern.visible,"lamp expires exactly "+id)
	# Hover must not toggle visibility or rebuild the content subtree.
	s.inventory.slots[8]=s.inventory.instance("copper_axe")
	var cell=w.item_ui.cells[8];cell.refresh()
	var toggles: Array=[];cell.durability_bar.visibility_changed.connect(func():toggles.append(true))
	for i in 12:
		cell.mouse_entered.emit();await process_frame;cell.mouse_exited.emit();await process_frame
	check(toggles.is_empty() and cell.durability_bar.visible,"durability never hides on hover")
	# Fuel curves and actual flame contact anchor.
	s.camps.states["test-fire"]={"x":at.x+160,"y":at.y,"fuel":1200.0,"lit":true,"hits":0,"recipe":"","elapsed":0.0,"ready":false}
	var fire=load("res://scripts/campfire.gd").new();fire.manager=s.camps;fire.camp_id="test-fire";w.object_root.add_child(fire);fire.position=at+Vector2(160,0);fire.set_process(false)
	var base_bottom: float=-44+fire.flame_bottom
	for fraction in [1.0,.5,.01]:
		s.camps.states["test-fire"].fuel=1200*fraction;fire._process(0)
		check(is_equal_approx(s.camps.light_scale("test-fire"),lerpf(.5,2,fraction)),"fuel radius "+str(fraction))
		check(is_equal_approx(fire.flame.scale.x/.2,lerpf(.5,1.5,fraction)),"fuel flame size "+str(fraction))
		check(is_equal_approx(fire.flame.position.y+fire.flame_bottom*fire.flame.scale.y/.2,base_bottom),"flame bottom fixed "+str(fraction))
	s.camps.states["test-fire"].fuel=0;s.camps.states["test-fire"].lit=false;fire._process(0)
	check(not fire.flame.visible and s.camps.light_scale("test-fire")==0,"zero fuel extinguished")
	var torch_row: Dictionary=b.candidate("camp_torch",at+Vector2(220,0),false,true,0)
	torch_row.fuel=1200.0;torch_row.lit=true;b.states["test-torch"]=torch_row
	var torch=load("res://scripts/camp_building.gd").new();torch.manager=b;torch.building_id="test-torch";w.object_root.add_child(torch);torch.position=at+Vector2(220,0);torch.set_process(false)
	var fixed_position: Vector2=torch.torch_flame.position;var fixed_body: Transform2D=torch.torch_body.transform
	for fraction in [1.0,.5,.001]:
		torch_row.fuel=1200*fraction;torch._process(0)
		check(torch.torch_flame.position==fixed_position and torch.torch_body.transform==fixed_body,"torch cup/shaft and flame root stationary "+str(fraction))
		check(is_equal_approx(torch.torch_flame.scale.x/torch.torch_flame_base_scale,lerpf(.5,1.5,fraction)),"torch flame curve "+str(fraction))
	# Repeated negative heading is stable in the rendered basis, not decomposed scale.
	var record:=row(at)
	var pig=Combat.Boar.new();pig.record=record;w.object_root.add_child(pig);pig.position=at+Vector2(110,0);pig.set_process(false)
	var stable:=true
	for i in 180:
		pig.position.x+=.01;pig._process(.016)
		if pig.skeleton.transform.x!=Vector2(-1,0) or pig.skeleton.transform.y!=Vector2(0,1):stable=false
	check(stable,"180 frames no boar left/right oscillation")
	var c=Harness.new();c.service=s;c.state.population_initialized=true;c.state.population_revision=2
	c.state.boars={"test":row(at)};c.personal.phase="alive"
	v.simulation.minute=1260
	w.player.position=at+Vector2(230,0)
	b.states["test-crop"]={"kind":"tilled_soil","layer":"ground","x":at.x+80,"y":at.y,"crop":"potato","growth_minutes":50.0,"roots":false}
	check(c.crop_on_path(at,w.player.position,"test")=="test-crop","crop along pursuit path selected first")
	c.advance_boars(.4);c.advance_boars(.4)
	check(c.state.boars.test.mode=="attack" and c.state.boars.test.attack_target=="crop:test-crop","boar attacks crop before player")
	c.advance_boars(.4)
	check(b.states["test-crop"].crop=="" and b.states["test-crop"].roots,"one attack destroys crop")
	c.advance_boars(1.0);c.advance_boars(.1)
	check(c.state.boars.test.mode=="chase","boar resumes player pursuit")
	# Existing wall polygons still block the route.
	var wall: Dictionary=b.candidate("wood_fence",at+Vector2(0,200),false,true,0)
	if not wall.is_empty():
		b.states["test-barrier"]=wall
		check(not s.combat.boar_clear(Vector2(wall.x,wall.y)-Vector2(0,60),Vector2(wall.x,wall.y)+Vector2(0,60)),"fence blocks boar path")
	# Night encounter relocation stays offscreen and far away; once per night.
	c.state.boars={"distant":row(at+Vector2(4000,0))};c.state.boars.distant.mode="patrol"
	c.rules=c.rules.duplicate(true);c.rules.boar.night_encounter_chance=1.0
	w.player.position=at;c.state.encounter_wait=18.0
	c.advance_night_encounter(1,1260)
	var hunter: Dictionary=c.state.boars.distant
	var range_to_player:=Vector2(hunter.x,hunter.y).distance_to(at)
	check(c.state.has("encounter_night") and hunter.get("night_hunter",false),"night encounter created")
	check(range_to_player>=650 and range_to_player<=1000,"night spawn stays distant")
	var hunter_at:=Vector2(hunter.x,hunter.y);c.advance_night_encounter(60,1260)
	check(Vector2(hunter.x,hunter.y)==hunter_at and c.state.boars.size()==1,"one encounter per night without population growth")
	check(c.valid(c.serialize(),c.personal),"new encounter fields roundtrip save validation")
	# Hair applied to actual native rig for both genders, four directions.
	var catalog=preload("res://scripts/character_catalog.gd")
	s.inventory.equipment={};w.player.character_look={}
	var layer:=CanvasLayer.new();layer.layer=2000;root.add_child(layer)
	var bg:=ColorRect.new();bg.color=Color("d6dbc4");bg.size=Vector2(default_size());layer.add_child(bg)
	var labels: Array=[]
	for r in 4:
		var hair_id: String="unisex_mohawk" if r<2 else "unisex_bun"
		var gender: String="male" if r%2==0 else "female"
		var look: Dictionary={"hair_id":hair_id,"gender":gender,"skin_id":"skin_2"}
		check(catalog.valid(look),"unisex selection "+hair_id+" "+gender)
		for col in 4:
			var direction: String=["front","back","right","left"][col]
			w.player.facing=direction;w.player.update_animation()
			preload("res://scripts/character_look.gd").new().apply(w.player.character,look,s.inventory,direction)
			var rig=w.player.character.duplicate();layer.add_child(rig);rig.position=Vector2(230+col*250,20+r*170);rig.scale=Vector2.ONE*1.45;rig.get_node("AnimationPlayer").active=false
			var hair: Sprite2D=rig.get_node("Visual/Pelvis/Head/Sprite/CharacterHairfront")
			check(hair.texture!=null and hair.visible,"native hair "+hair_id+" "+gender+" "+direction)
		var label:=Label.new();label.text=("莫西干" if r<2 else "丸子头")+(" 男" if gender=="male" else " 女");label.position=Vector2(20,65+r*170);layer.add_child(label)
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"hair-four-views.png")
	layer.queue_free();await frames()
	# Actual viewport portal survives repeated recreation, with opaque frame pixels.
	w.player.position=at;v.simulation.minute=720
	s.combat_view.portal.queue_free();await frames()
	for i in 4:
		var portal=Combat.Portal.new();w.object_root.add_child(portal);portal.position=at+Vector2(0,-20);portal.scale=Vector2.ONE*2
		await frames();await RenderingServer.frame_post_draw
		check(portal.frame_texture.get_image().get_used_rect().has_area(),"portal texture survives regeneration "+str(i))
		if i==3:root.get_texture().get_image().save_png(out+"world-portal.png")
		portal.queue_free();await frames()
	var guide_has_warning:=false
	for label in w.item_ui.guide.find_children("*","Label",true,false):
		if "夜晚可能会遭遇野兽，保护好自己" in label.text:guide_has_warning=true
	check(guide_has_warning,"survival guide warning")
	w.item_ui.guide.open_letter();await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"guide.png");w.item_ui.guide.close_letter()
	# Copper hammer shares the same two-unit progression and single-use wear rule.
	s.inventory.equipment.main_hand=s.inventory.instance("copper_hammer")
	w.player.position=fire.position+Vector2(0,50)
	check(b.strike("test-fire",fire) and s.camps.states["test-fire"].hits==2,"copper hammer advances twice")
	check(b.strike("test-fire",fire) and not s.camps.states.has("test-fire"),"copper hammer completes odd count in ceil half")
	check(s.inventory.equipment.main_hand.durability==248,"hammer wears once per actual strike")
	FileAccess.open(out+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	var failed:=checks.filter(func(x):return not x.pass).size()
	print("HOME_LOCAL ",checks.size()," FAILED ",failed)
	w.queue_free();await frames();quit(1 if failed else 0)
