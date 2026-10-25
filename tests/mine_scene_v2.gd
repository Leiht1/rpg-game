extends "res://tests/sleep_v8_fixture.gd"
const DEST="res://reports/mine-scene-v2/"
var view: Node2D
func go(at: Vector2) -> void:
	w.player.position=at;w.player.reset_physics_interpolation();w.player.camera.reset_smoothing();await frames(4)
func capture_scene(name: String) -> void:
	view._process(0)
	await create_timer(.22).timeout;await frames(4);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DEST+name+".png")
func press_at(kind: String, at: Vector2) -> void:
	await go(at+Vector2(0,38));w.player.input_blocked=false;w.player.facing="back";w.player.try_interact();view._process(0);await frames(2)
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
	await go(m.origin()+Vector2(0,35));await frames(15)
	view=s.chapter_view.get_node("PuzzleView");view.set_process(false);view._process(0)
	check(view.targets.size()==10,"exactly four lamps four carvings main inscription and chest")
	check(view.rubble.texture.resource_path.contains("mine-scene-v2"),"new side heap art")
	check(view.ores.is_empty() and not view.targets.chest.visible,"no reward silhouette before solve")
	check(view.targets.inscription.get_children().all(func(n):return not n is Label),"no readable order text in room")
	for i in 4:
		var art: Sprite2D=view.targets["carving:"+str(i)].get_node("WallEtching")
		check(art.texture.resource_path.contains("etch-") and art.texture.get_width()*art.scale.x<50,"wall hotspot "+str(i)+" is small incision only")
	check(view.art.chest.texture.resource_path.contains("mine-scene-v2/chest-closed"),"reward has independent buried chest art")
	check(p.config.hits==8 and p.config["yield"]==2 and p.config.respawn_days==6,"mining balance preserved")
	await capture_scene("01-default-central")
	w.player.camera.zoom=Vector2.ONE*.65;await go(m.origin()+Vector2(0,-30));await capture_scene("02-room-layout");w.player.camera.zoom=Vector2.ONE
	for i in 4:
		await press_at("carving:"+str(i),p.point("carvings",i))
		check(s.chapter_view.panel.visible and s.chapter_view.carving.visible and s.chapter_view.words.text==p.OBSERVATIONS[i],"actual E opens matching wall closeup "+str(i))
		check(s.chapter_view.wall_dimmer.visible and not s.chapter_view.paper.visible,"wall closeup "+str(i)+" uses rock not task paper")
		await capture_scene("03-closeup-"+str(i));s.chapter_view.close_page();check(not w.player.input_blocked,"closeup restores movement "+str(i))
		await capture_scene("04-wall-hotspot-"+str(i))
	await press_at("inscription",p.point("inscription"));check(s.chapter_view.words.text.contains("先苏醒") and s.chapter_view.carving.visible,"main order requires E with separate rock closeup");await capture_scene("05-main-inscription");s.chapter_view.close_page()
	await press_at("lamp:0",p.point("lamps",0));check(p.state.progress==1,"actual lamp E still advances shared logic")
	await press_at("lamp:3",p.point("lamps",3));check(p.state.progress==0,"wrong abstract symbol still resets")
	for i in 4:await press_at("lamp:"+str(i),p.point("lamps",i))
	check(p.state.solved and p.state.progress==4,"same solve state")
	await go(m.origin()+Vector2(180,-40));view._process(0);await capture_scene("06-collapse-start")
	check(view.rubble_parts.all(func(n):return n.visible),"original heap splits into eight registered fragments")
	view._process(.55);await capture_scene("07-collapse-moving")
	check(view.ores.size()==3 and view.targets.chest.modulate.a>0 and view.targets.chest.modulate.a<1,"rewards gradually show beneath moving heap")
	check(view.ores.values().all(func(n):return not n.is_in_group("world_interactables")),"no mine interaction through moving rubble")
	view._process(.65);await capture_scene("08-collapse-reveal")
	view._process(1.3);view._process(0);await frames(2);await capture_scene("09-rewards-uncovered")
	check(view.rubble_parts.all(func(n):return not n.visible) and not view.rubble.visible,"no lingering foreground slab after collapse")
	check(view.ores.size()==3 and view.ores.values().all(func(n):return n.is_in_group("world_interactables")),"three reachable official mine nodes remain")
	check(w.player.camera.offset==Vector2.ZERO,"short gentle shake restores camera")
	await press_at("chest",p.point("chest"));view._process(0)
	check(p.state.chest_open and s.inventory.count_item(p.RECORD)==1,"chest original unique settlement preserved")
	check(view.art.chest.texture.resource_path.ends_with("mine-scene-v2/chest-open.png"),"opened buried chest keeps matching worn identity")
	await capture_scene("10-open-buried-chest")
	var saved: Dictionary=q.serialize();q.state=q.migrate(JSON.parse_string(JSON.stringify(saved)));view._process(0)
	check(q.valid(q.serialize()) and p.state.chest_open and p.state.solved,"original world state structure restores")
	check(view.clock>=p.config.reveal_seconds and not view.rubble.visible,"restored completed room does not replay")
	check(p.state.next_due==-1 and not p.state.read,"visual rework does not advance next-stage wait")
	if "--play" in OS.get_cmdline_user_args():
		q.state.mine.puzzle=p.initial();view.previous_solved=false;view.clock=10;view._process(0);view.set_process(true);w.player.camera.zoom=Vector2.ONE;w.player.input_blocked=false;w.player.set_physics_process(true);w.set_process(true);s.set_process(true);v.set_process(true);return
	var failed: int=checks.filter(func(c):return not c.pass).size();FileAccess.open(DEST+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "));print("MINE SCENE V2 ",checks.size()," checks ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(1 if failed else 0)
