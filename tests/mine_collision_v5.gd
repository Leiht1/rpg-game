extends "res://tests/mine_playable_preview.gd"
var checks: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("COLLISION_CHECK ",ok," ",label)
func walk(from: Vector2,direction: Vector2,seconds: float) -> Vector2:
	w.player.position=from;w.player.reset_physics_interpolation();w.stream.update_target(from)
	while not w.stream.viewport_ready(from,Vector2(640,360)):await process_frame
	w.player.automated=true;w.player.input_blocked=false;w.player.input_override=direction;w.player.set_physics_process(true)
	await create_timer(seconds).timeout
	w.player.input_override=Vector2.ZERO;w.player.set_physics_process(false)
	print("WALK_END ",w.player.position-from);return w.player.position
func snap(name: String) -> void:
	w.player.camera.reset_smoothing();w.player.camera.force_update_scroll()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/mine-collision-v5/"+name+".png")
func smoke() -> void:
	var s=w.item_service;var m=s.chapter.mine;var view=s.chapter_view.get_node("MineView")
	w.environment_view.simulation.paused=true;s.combat.state.boars.clear();w.player.camera.position_smoothing_enabled=false
	m.state.phase="open";m.state.recipe=true;m.state.investigated=true
	await create_timer(.2).timeout
	var p:=await walk(m.at()+Vector2(0,100),Vector2.UP,1.3)
	check(p.y>=m.at().y+9 and p.y<m.at().y+35,"open threshold reachable but actor cannot enter shell or pass behind picture")
	await snap("01-exterior-threshold")
	p=await walk(m.at()+Vector2(210,-35),Vector2.LEFT,1.2)
	check(p.x>m.at().x+150,"right rock face blocks actor")
	p=await walk(m.at()+Vector2(-210,-35),Vector2.RIGHT,1.2)
	check(p.x<m.at().x-150,"left rock face blocks actor")
	p=await walk(m.at()+Vector2(0,-225),Vector2.DOWN,1.2)
	check(p.y<m.at().y-170,"rear roof blocks actor")
	w.player.position=m.at()+Vector2(0,65);w.player.reset_physics_interpolation()
	check(m.interact("enter").is_empty(),"threshold still permits entry")
	while s.chapter_view.transition.active:await process_frame
	p=await walk(m.origin()+Vector2(0,245),Vector2.DOWN,1.2)
	check(p.y<=m.origin().y+331 and p.y>m.origin().y+318,"inside approach stops before beam")
	await snap("02-interior-threshold")
	var rules=preload("res://scripts/mine_rules.gd")
	check(not rules.walkable(m.origin()+Vector2(-150,350),w.generator.extent) and not rules.walkable(m.origin()+Vector2(150,350),w.generator.extent),"both painted exit posts and beam are outside floor")
	check(rules.walkable(m.origin()+Vector2(0,275),w.generator.extent),"entry landing remains clear")
	check(rules.walkable(m.origin()+Vector2(750,0),w.generator.extent) and rules.walkable(m.origin()+Vector2(-750,0),w.generator.extent),"floor along both side edges remains reachable")
	check(rules.walkable(m.origin()+Vector2(0,320),w.generator.extent),"floor close to exit beam remains reachable")
	check(m.interact("exit").is_empty(),"stopped position still reaches exit")
	while s.chapter_view.transition.active:await process_frame
	check(not m.travel.inside,"round trip completes")
	var failures:=checks.filter(func(c):return not c.pass).size()
	var f=FileAccess.open("res://reports/mine-collision-v5/checks.json",FileAccess.WRITE);f.store_string(JSON.stringify(checks,"  "));f.close()
	print("COLLISION_TOTAL ",checks.size()," FAILURES ",failures);quit(1 if failures else 0)

