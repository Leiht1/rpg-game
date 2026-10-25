extends SceneTree
var w: Node
var s: Node
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func check(ok: bool, label: String) -> void:
	checks.append({"pass":ok,"test":label});print("PASS " if ok else "FAIL ",label)
func go(pos: Vector2, zoom: float, file: String) -> void:
	w.player.position=pos;w.player.camera.zoom=Vector2.ONE*zoom;w.stream.update_target(pos);w.player.camera.reset_smoothing();w.player.reset_physics_interpolation()
	for i in 180:
		if w.stream.viewport_ready(pos,Vector2(640,360)):break
		await process_frame
	await create_timer(.45).timeout;await frames(4);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/final-chapter-v2/"+file+".png")
func run() -> void:
	Engine.set_meta("integration_seed",271828);w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w);current_scene=w
	while not w.started:await process_frame
	s=w.item_service;w.set_process(false);s.set_process(false);w.environment_view.set_process(false);w.player.set_physics_process(false);w.player.automated=true;w.player.camera.position_smoothing_enabled=false
	var snapshot: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/final-chapter-v1/ready.json"));s.load_state("",false,snapshot)
	check(s.writable,"isolated complete chapter restores")
	var f=s.chapter.finale;f.state.defeated=false;f.state.triggered=false;f.reset_boss();s.body.health=100;s.combat.personal.phase="alive";s.guide_stage=2;s.combat.state.boars.clear()
	w.item_ui.message_time=0;w.item_ui.obtained.hide()
	await go(f.at()+Vector2(0,150),.8,"01-overview")
	var view: Node=s.chapter_view.get_node("FinaleView")
	check(view.ground.material is ShaderMaterial,"ground uses continuous texture and irregular blend")
	check(view.ground.texture.resource_path.contains("final-v2"),"old hard-rim ground excluded")
	check(view.props.size()==4,"independent tall pillars, stump and seat")
	var pic: Sprite2D=view.props[0].get_child(0)
	check(pic.texture.get_height()*pic.scale.y>170 and pic.texture.get_height()*pic.scale.y<210,"tall pillar world height measured against actual hero")
	check(absf(pic.position.y+pic.texture.get_height()*pic.scale.y*.5-6)<.01,"pillar anchor at base, no guessed cluster centre")
	await go(f.at()+Vector2(420,100),1,"02-transition-normal")
	await go(f.at()+Vector2(-390,-90),1,"03-pillar-normal")
	w.player.camera.offset=Vector2(0,-95)
	await go(f.at()+Vector2(-390,-90),1.65,"04-pillar-zoom")
	w.player.camera.offset=Vector2.ZERO
	var pillar: Node2D=view.props[0]
	w.player.position=pillar.position+Vector2(-65,0);await physics_frame
	var hit: KinematicCollision2D=w.player.move_and_collide(Vector2(130,0))
	check(hit!=null,"pillar foot blocks actual player movement")
	await go(pillar.position+Vector2(0,-25),1,"05-person-behind-pillar")
	await go(pillar.position+Vector2(0,32),1,"06-person-front-pillar")
	for i in 60:
		w.player.position=f.at()+Vector2(300+i*7,110);w.stream.update_target(w.player.position);await process_frame
	check(view.ground.visible and view.visible,"ground remains present across transition movement")
	await go(f.at()+Vector2(0,150),1,"07-boss-phase-one")
	f.state.boss.health=150;f.state.boss.mode="windup";f.state.boss.attack="core";f.state.boss.clock=.7;f.state.triggered=true
	await go(f.at()+Vector2(0,150),.8,"08-boss-phase-two")
	s.chapter_view.show_page("海彼岸的记录");await create_timer(.5).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/final-chapter-v2/09-letter.png");s.chapter_view.close_page()
	var failed: int=checks.filter(func(c):return not c.pass).size();FileAccess.open("res://reports/final-chapter-v2/window.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "));print("SCENERY V2 ",checks.size()," checks ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(1 if failed else 0)
