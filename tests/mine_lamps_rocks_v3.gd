extends "res://tests/sleep_v8_fixture.gd"
const DEST="res://reports/mine-lamps-rocks-v3/"
var view: Node2D
func go(at: Vector2) -> void:
	w.player.position=at;w.player.reset_physics_interpolation();w.player.camera.reset_smoothing();await frames(4)
func capture_scene(name: String) -> void:
	view._process(0);w.item_ui.message_time=0;await create_timer(.16).timeout;await frames(3);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DEST+name+".png")
func lamp(i: int) -> void:
	await go(s.chapter.puzzle.point("lamps",i)+Vector2(0,48));w.player.input_blocked=false;w.player.facing="back";w.player.try_interact();view._process(0);await frames(2)
func run() -> void:
	Engine.set_meta("integration_seed",271828);w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w);current_scene=w
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view;w.set_process(false);s.set_process(false);v.set_process(false);w.player.set_physics_process(false);w.player.automated=true
	w.player.camera.position_smoothing_enabled=false;s.guide_stage=2;s.combat.state.boars.clear();s.combat.personal.phase="alive";root.size=default_size();root.content_scale_size=root.size
	var q=s.chapter;var m=q.mine;var p=q.puzzle
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/.tmp/mine-ready.json"))
	q.state=q.migrate(source.exploration_chapter);m.state.phase="open";m.state.entered=true;m.state.fuse_remaining_seconds=0.0;m.travel={"inside":true,"serial":1};m.state.puzzle=p.initial()
	for i in 40:s.inventory.slots[i]={}
	s.body.health=100;s.body.energy=100;s.body.hunger=100
	await go(m.origin()+Vector2(-30,20));await frames(12);view=s.chapter_view.get_node("PuzzleView");view.set_process(false);view._process(0)
	var a: Vector2=p.point("lamps",0);var b: Vector2=p.point("lamps",1);var c: Vector2=p.point("lamps",2);var d: Vector2=p.point("lamps",3)
	check(a.x==c.x and b.x==d.x and a.y==d.y and b.y==c.y,"four lamp anchors form exact rectangle")
	check(a.distance_to(d)==380 and a.distance_to(c)==240,"rectangle has clear central operating space")
	for i in 4:
		check(view.art[i].texture.resource_path.ends_with("lamp-%d-off.png"%i),"unlit lamp "+str(i)+" uses extinguished chamber")
		check(is_equal_approx(view.art[i].texture.get_width()*view.art[i].scale.x,132),"lamp "+str(i)+" enlarged to 132 world units")
		check(view.art[i].modulate==Color.WHITE,"lamp "+str(i)+" stone has no lighting tint")
	check(view.rubble_parts.size()==14,"heap consists of fourteen whole independent stones")
	check(view.rubble_parts.all(func(n):return not n.texture is AtlasTexture and n.texture.resource_path.contains("/rock-")),"every stone texture is a complete separately generated rock")
	check(view.rubble_parts.all(func(n):return n.visible and n.modulate.a==1),"same whole stones form initial opaque heap")
	check(view.ores.is_empty() and not view.targets.chest.visible,"rewards remain hidden before completion")
	await capture_scene("01-unlit-rectangle")
	await lamp(0);check(p.state.progress==1,"actual E lights first lamp")
	await go(m.origin()+Vector2(-30,20));await capture_scene("02-one-lamp-lit")
	check(view.art[0].texture.resource_path.ends_with("lamp-0-on.png") and view.art[0].modulate==Color.WHITE,"light appears inside chamber without brightening stone")
	await lamp(3);check(p.state.progress==0,"wrong E resets lamps")
	check(range(4).all(func(i):return view.art[i].texture.resource_path.ends_with("off.png")),"failed sequence extinguishes all four real chambers")
	for i in 4:await lamp(i)
	check(p.state.solved,"original completion logic preserved")
	await go(m.origin()+Vector2(-30,20));await capture_scene("03-all-lamps-lit")
	check(range(4).all(func(i):return view.art[i].texture.resource_path.ends_with("on.png") and view.art[i].modulate==Color.WHITE),"four flames lit while roofs and stone retain original colour")
	await go(m.origin()+Vector2(120,20));view._process(0);await capture_scene("04-before-stones-move")
	var solved: Dictionary=q.serialize();var movement_counts: Array=[];var scale_constant:=true;var staggered:=false
	DirAccess.make_dir_recursive_absolute(DEST+"frames")
	for frame in 61:
		view._process(0 if frame==0 else .04);view._process(0)
		var moving: int=view.rubble_parts.filter(func(n):return n.position.distance_to(n.get_meta("rest"))>3).size()
		movement_counts.append(moving)
		if moving>0 and moving<view.rubble_parts.size():staggered=true
		for stone in view.rubble_parts:
			if stone.scale!=stone.get_meta("fixed_scale"):scale_constant=false
		await frames(2);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DEST+"frames/%03d.png"%frame)
		if frame in [10,22,34,46,60]:root.get_texture().get_image().save_png(DEST+"05-slide-%02d.png"%frame)
	check(scale_constant,"all stones retain exactly the same scale in every rendered animation frame")
	check(staggered,"stones begin sliding at different times")
	check(movement_counts.max()==14,"every complete stone actually slides before disappearing")
	check(view.rubble_parts.all(func(n):return not n.visible) and not view.rubble.visible,"last stone finishes before reveal event ends")
	check(view.ores.size()==3 and view.targets.chest.visible and view.targets.chest.modulate.a==1,"unchanged rewards exposed behind departed stones")
	check(q.serialize()==solved,"visual animation does not mutate persistent progress or rewards")
	check(w.player.camera.offset==Vector2.ZERO,"gentle shake restores camera exactly")
	await capture_scene("06-clear-reward-area")
	for i in 4:
		var display: Sprite2D=view.art[i]
		var viewport:=SubViewport.new();viewport.size=Vector2i(520,390);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
		var off:=Sprite2D.new();off.texture=view.lamp_textures[i].off;off.scale=Vector2.ONE*.78;off.position=Vector2(130,180);viewport.add_child(off)
		var on:=Sprite2D.new();on.texture=view.lamp_textures[i].on;on.scale=Vector2.ONE*.78;on.position=Vector2(390,180);viewport.add_child(on)
		await frames(4);await RenderingServer.frame_post_draw;viewport.get_texture().get_image().save_png(DEST+"07-lamp-pair-%d.png"%i);viewport.queue_free();await frames(2)
	m.travel.inside=false;view._process(.1);m.travel.inside=true;view._process(0)
	check(not view.rubble.visible and p.state.solved,"leaving and returning does not rebuild or replay heap")
	q.state=q.migrate(JSON.parse_string(JSON.stringify(solved)));view._process(0)
	check(q.valid(q.serialize()) and not view.rubble.visible,"completed existing save restores final visual state")
	FileAccess.open(DEST+"animation-metrics.json",FileAccess.WRITE).store_string(JSON.stringify({"frames":61,"step_seconds":.04,"moving_stones":movement_counts,"scale_constant":scale_constant},"  "))
	var failed: int=checks.filter(func(row):return not row.pass).size();FileAccess.open(DEST+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "));print("MINE LAMPS ROCKS V3 ",checks.size()," checks ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(1 if failed else 0)
