extends "res://tests/sleep_v8_fixture.gd"
const DEST="res://reports/exploration-elder-style-v3/"
func move_to(at: Vector2) -> void:
	w.player.position=at;w.player.camera.position_smoothing_enabled=false
	w.stream.target_center=Vector2i(-999,-999);w.stream.update_target(at)
	while not w.stream.viewport_ready(at,Vector2(640,360)):await process_frame
	await frames(8)
func snap(label: String) -> void:
	v.dial.queue_redraw();v.season_dial.queue_redraw()
	await frames(8);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DEST+label+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(DEST);Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view
	w.set_process(false);s.set_process(false);v.set_process(false);w.player.set_physics_process(false)
	w.player.automated=true;s.combat.state.boars.clear();s.combat.personal.phase="alive"
	root.size=default_size();root.content_scale_size=root.size
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/.tmp/exploration-waits-v2/ready.json"))
	s.load_state("",false,saved);s.combat.personal.phase="alive"
	check(s.writable and not w.persistent_world,"isolated world restoration without production saves")
	var at: Vector2=s.chapter.point("elder")
	await move_to(at+Vector2(-65,25));w.player.facing="front";w.player.update_animation()
	check(s.chapter_view.props.has("shore"),"actual elder loaded at persisted river bank")
	var elder: Sprite2D=s.chapter_view.props.shore.get_node("Elder")
	check(elder.texture.resource_path=="res://assets/exploration/v3/elder.png","new flat cartoon elder runtime art")
	await snap("01-normal-front")
	w.player.camera.zoom=Vector2.ONE*1.65;await snap("02-enlarged-front")
	w.player.facing="right";w.player.update_animation();await snap("03-enlarged-side")
	w.player.camera.zoom=Vector2.ONE
	await move_to(at+Vector2(0,-30));w.player.facing="front";w.player.update_animation();await snap("04-behind")
	await move_to(at+Vector2(0,35));w.player.facing="back";w.player.update_animation();await snap("05-in-front")
	check(preload("res://scripts/world_interaction.gd").in_reach(w.stream,w.player.position,s.chapter_view.props.shore),"actual E selection reaches elder with foot collider")
	var before: Dictionary=s.chapter.serialize()
	s.chapter_view.investigate("shore");await snap("06-dialogue")
	check(s.chapter_view.panel.visible and s.chapter_view.words.text.contains("当年"),"same real elder conversation after art replacement")
	check(s.chapter.state==before,"repeat dialogue retains current phase and deadline")
	s.chapter_view.close_page()
	var line: Line2D=s.chapter_view.props.shore.get_node("FishingLine")
	check(line.points.size()==3 and (line.points[-1]+at).distance_to(s.chapter.point("river_fish"))<1,"line ends on actual saved river water")
	check(s.chapter_view.props.shore.get_child_count()==4,"one sprite one collider one line one bobber")
	FileAccess.open(DEST+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	var failed:=checks.filter(func(c):return not c.pass).size();print("ELDER STYLE V3 ",checks.size()," checks ",failed," failed")
	quit(1 if failed else 0)
