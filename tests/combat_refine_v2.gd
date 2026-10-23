extends SceneTree
var failed:=false
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failed=true
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.set_process(false);w.player.set_physics_process(false);w.item_service.set_process(false);w.environment_view.set_process(false)
	var s=w.item_service;var c=s.combat
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	if "--portal-only" in OS.get_cmdline_user_args():
		w.player.position=c.spawn_point();w.player.camera.reset_physics_interpolation()
		for i in 6:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/.tmp/portal-no-threshold-final.png")
		check(c.service.combat_view.portal.get_child(0).material==null,"portal uses complete new sprite without clipping")
		quit(1 if failed else 0);return
	c.personal.phase="alive";c.personal.attack={};s.body.energy=100;s.body.stamina=100;s.body.health=100;s.inventory.equipment={}
	check(c.attack(Vector2.RIGHT).is_empty(),"start attack")
	var before: Dictionary=c.personal.attack.duplicate(true);var stamina: float=s.body.stamina
	check(c.attack(Vector2.RIGHT).is_empty() and c.personal.attack==before and s.body.stamina==stamina,"repeat silent without restart or cost")
	c.personal.attack={}
	var count: int=c.state.boars.size()
	check(c.debug_spawn_near() and c.state.boars.size()==count+1,"debug boar +1")
	check(c.valid(c.state,c.personal),"debug boar save validation")
	await screen_check(s,w)
	c.personal.attack={};w.player.combat_render_state={};w.player.update_animation()
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/.tmp/combat-refine-world.png")
	var layer:=CanvasLayer.new();layer.layer=2000;root.add_child(layer)
	var background:=ColorRect.new();background.size=Vector2(1280,720);background.color=Color("d6dbc4");layer.add_child(background)
	for row in 4:
		var view: String=["front","right","back","left"][row]
		var label:=Label.new();label.text=view;label.position=Vector2(8,row*174+60);layer.add_child(label)
		for col in 6:
			var elapsed: float=[0.0,.08,.17,.24,.44,.73][col]
			w.player.facing=view;s.inventory.equipment={"main_hand":s.inventory.instance("wood_club")}
			c.personal.attack={"weapon":c.rules.weapons.wood_club,"elapsed":elapsed,"direction":{"x":1,"y":0},"targets":{}}
			w.player.combat_render_state={};w.player.update_animation()
			var expected: String="harvest/"+("side" if view in ["left","right"] else view)+"_mine"
			check(str(w.player.animation_player.current_animation)==expected,"native mine "+view+" phase "+str(col))
			var rig=w.player.character.duplicate();layer.add_child(rig);rig.position=Vector2(82+col*194,row*174+4);rig.scale=Vector2.ONE*1.4
			rig.get_node("AnimationPlayer").active=false

	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/.tmp/combat-refine-sheet.png")
	layer.queue_free();await process_frame
	var motion:=CanvasLayer.new();motion.layer=2000;root.add_child(motion)
	var bg:=ColorRect.new();bg.size=Vector2(1280,720);bg.color=Color("d6dbc4");motion.add_child(bg)
	DirAccess.make_dir_recursive_absolute("res://reports/.tmp/combat-refine-motion")
	for frame in 25:
		var poses:=Node2D.new();motion.add_child(poses)
		for index in 4:
			var view: String=["front","right","back","left"][index]
			w.player.facing=view
			c.personal.attack={"weapon":c.rules.weapons.wood_club,"elapsed":frame*.04,"direction":{"x":1,"y":0},"targets":{}} if frame<19 else {}
			w.player.combat_render_state={};w.player.update_animation()
			var rig=w.player.character.duplicate();poses.add_child(rig);rig.position=Vector2(120+index*280,210);rig.scale=Vector2.ONE*2.0;rig.get_node("AnimationPlayer").active=false
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/.tmp/combat-refine-motion/%02d.png"%frame)
		poses.queue_free();await process_frame
	print("COMBAT_REFINE_PASS" if not failed else "COMBAT_REFINE_FAIL");quit(1 if failed else 0)
func screen_check(s,w) -> void:
	var ui=w.item_ui
	ui.rebuild_catalog()
	await process_frame
	check(ui.catalog.find_child("SpawnBoar",true,false)!=null,"F6 boar button")
	check(s.database.item("flint").world_size==23,"loose flint enlarged")
	for id in ["wood","wood_club"]:
		for i in s.inventory.slots.size():s.inventory.slots[i]={}
		var expected: int=s.database.item(id).max_stack
		var found:=false
		for button in ui.catalog.find_children("*","Button",true,false):
			for sibling in button.get_parent().get_children():
				if sibling is Label and sibling.text.split("·").size()>1 and sibling.text.split("·")[1].strip_edges()==id:
					check(button.text=="+%d"%expected,"debug amount label "+id)
					button.pressed.emit();found=true
		check(found and s.inventory.count_item(id)==expected,"debug stack grant "+id)
	var attack_hint:=false
	for label in ui.guide.find_children("*","Label",true,false):
		if "F  攻击" in label.text:attack_hint=true
	check(attack_hint,"guide F attack")

