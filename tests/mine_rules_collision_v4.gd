extends "res://tests/sleep_v8_fixture.gd"
const DEST="res://reports/mine-collision-clues-v4/"
const Geometry=preload("res://scripts/mine_puzzle_geometry.gd")
var view: Node2D
func go(at: Vector2) -> void:
	w.player.position=at;w.player.reset_physics_interpolation();w.player.camera.reset_smoothing();await frames(3)
func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	w.item_ui.message_time=0;await create_timer(.18).timeout;await frames(3);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(DEST+name+".png")
func light(i: int, real_e: bool=false) -> String:
	if real_e:
		await go(s.chapter.puzzle.point("lamps",i)+Vector2(0,48));w.player.input_blocked=false;w.player.facing="back";w.player.try_interact();view._process(0);return ""
	w.player.position=s.chapter.puzzle.point("lamps",i)+Vector2(0,48)
	return s.chapter.mine.interact("lamp:"+str(i))
func native_collision(kind: String, at: Vector2, directions: Array) -> void:
	var polygon: PackedVector2Array=Geometry.polygon(kind)
	for direction in directions:
		var dir: Vector2=direction
		var distance: float=0
		for point in polygon:distance=maxf(distance,point.dot(dir))
		distance+=45 if kind=="rubble" else 30
		# Keep mineral/chest test approaches in the clear gap between those objects.
		if kind=="ore" and dir==Vector2.DOWN:distance=55
		if kind=="chest" and dir==Vector2.UP:distance=70
		var from: Vector2=at+dir*distance;var expected:=0.0
		while expected<200 and not Geometry.contains(from-at-dir*expected,polygon,10):expected+=.5
		await go(from);w.player.input_blocked=false;w.player.automated=true;w.player.input_override=-dir;w.player.set_physics_process(true)
		var began: int=Time.get_ticks_msec();var touched:=false;var penetrated:=false
		while Time.get_ticks_msec()-began<850:
			await physics_frame
			if Geometry.contains(w.player.position-at,polygon,9.0):penetrated=true
			for j in w.player.get_slide_collision_count():
				var collider: Object=w.player.get_slide_collision(j).get_collider()
				if collider!=null and collider.get_meta("mine_volume","")==kind:touched=true
		w.player.input_override=Vector2.ZERO;w.player.set_physics_process(false)
		var traveled: float=(w.player.position-from).dot(-dir)
		check(touched and not penetrated,"actual walking "+kind+" "+str(dir)+" physically contacts volume without penetrating while sliding")
func run() -> void:
	Engine.set_meta("integration_seed",271828);w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w);current_scene=w
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view;w.set_process(false);s.set_process(false);v.set_process(false);w.player.set_physics_process(false);w.player.automated=true;w.player.camera.position_smoothing_enabled=false
	s.guide_stage=2;s.combat.state.boars.clear();s.combat.personal.phase="alive";root.size=default_size();root.content_scale_size=root.size
	var q=s.chapter;var m=q.mine;var p=q.puzzle
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/.tmp/mine-ready.json"))
	q.state=q.migrate(source.exploration_chapter);m.state.phase="open";m.state.entered=true;m.state.fuse_remaining_seconds=0.0;m.travel={"inside":true,"serial":1};m.state.puzzle=p.initial()
	for i in 40:s.inventory.slots[i]={}
	s.body.health=100;s.body.energy=100;s.body.hunger=100
	await go(m.origin()+Vector2(-30,20));await frames(10);view=s.chapter_view.get_node("PuzzleView");view.set_process(false);view._process(0);await physics_frame;await frames(2)
	# All permutations: no prefix leaks whether the chosen order is correct.
	var permutations:=0
	for a in 4:
		for b in 4:
			for c in 4:
				for d in 4:
					if [a,b,c,d].any(func(i):return [a,b,c,d].count(i)!=1):continue
					m.state.puzzle=p.initial();var ids: Array=[a,b,c,d];var partial_ok:=true
					for j in 4:
						await light(ids[j])
						if j<3:partial_ok=partial_ok and p.state.order==ids.slice(0,j+1) and p.state.progress==j+1 and not p.state.solved
					check(partial_ok,"three unjudged lamps retained for permutation "+str(ids))
					check(p.state.solved==(ids==[0,1,2,3]) and (p.state.progress==4 if p.state.solved else p.state.order.is_empty()),"only fourth judges permutation "+str(ids));permutations+=1
	check(permutations==24,"all twenty-four unique orders covered")
	m.state.puzzle=p.initial();await light(2,true);await light(0,true);await light(3,true);await light(3,true)
	check(p.state.order==[2,0,3] and p.state.progress==3,"real E preserves wrong prefix and duplicate does not add")
	check(view.art[0].texture.resource_path.ends_with("on.png") and view.art[2].texture.resource_path.ends_with("on.png") and view.art[3].texture.resource_path.ends_with("on.png") and view.art[1].texture.resource_path.ends_with("off.png"),"visual lights match chosen identities instead of correct prefix")
	await go(m.origin()+Vector2(-30,20));await snap("01-wrong-three-stay-lit")
	var partial: Dictionary=q.serialize();q.state=q.migrate(JSON.parse_string(JSON.stringify(partial)));check(q.valid(q.state) and p.state.order==[2,0,3],"JSON reload preserves arbitrary partial order")
	var old_path: String=s.save_path;w.persistent_world=true;s.save_path="res://reports/mine-collision-clues-v4/missing/sub/items.json"
	check((await light(1)).contains("保存失败") and p.state.order==[2,0,3],"failed fourth-save restores three lamps and order")
	w.persistent_world=false;s.save_path=old_path
	await light(1,true);check(p.state.order.is_empty() and p.state.progress==0 and not p.state.solved,"fourth wrong light extinguishes whole set")
	await go(m.origin()+Vector2(-30,20));await snap("02-fourth-wrong-reset")
	var legacy: Dictionary=q.serialize();legacy.mine.puzzle.erase("order");legacy.mine.puzzle.version=1;legacy.mine.puzzle.progress=2
	check(q.valid(legacy),"old partial save accepted")
	q.state=q.migrate(legacy);check(p.state.version==2 and p.state.order==[0,1] and p.state.progress==2,"old prefix safely migrates")
	legacy=q.serialize();legacy.mine.puzzle.version=1;legacy.mine.puzzle.erase("order");legacy.mine.puzzle.progress=4;legacy.mine.puzzle.solved=true;legacy.mine.puzzle.vein_unlocked=true;legacy.mine.puzzle.rubble_fallen=true;legacy.mine.puzzle.chest_open=true;legacy.mine.puzzle.claimed=true;legacy.mine.puzzle.read=true;legacy.mine.puzzle.read_at=q.now();legacy.mine.puzzle.next_due=q.now()+1440
	q.state=q.migrate(legacy);check(q.valid(q.state) and p.state.order==[0,1,2,3] and p.state.claimed and p.state.read and p.state.next_due==legacy.mine.puzzle.next_due,"completed old reward and waiting state remain intact")
	var bad: Dictionary=q.serialize();bad.mine.puzzle.order=[0,0,2,3];check(not q.valid(bad),"duplicate saved order rejected")
	bad=q.serialize();bad.mine.puzzle.order=[3,2,1,0];check(not q.valid(bad),"incorrect completed save rejected")
	m.state.puzzle=p.initial();view._process(0);await frames(3);await physics_frame
	for i in 4:
		var glyph: Sprite2D=view.targets["carving:"+str(i)].get_node("WallEtching")
		check(glyph.texture.resource_path.ends_with("glyph-%d.png"%i) and glyph.z_index==-5,"single matching wall glyph behind actor "+str(i))
		await go(p.point("carvings",i)+Vector2(0,38));w.player.input_blocked=false;w.player.facing="back";w.player.try_interact()
		check(s.chapter_view.carving.visible and s.chapter_view.carving.texture.resource_path.contains("mine-clues-v4/closeup-") and s.chapter_view.words.text==p.OBSERVATIONS[i],"actual E opens single-symbol meaning clue "+str(i))
		await snap("03-clue-"+str(i));s.chapter_view.close_page()
	# Controlled overlap verifies visible layering, in addition to reachable wall shots.
	await go(view.targets["carving:0"].get_node("WallEtching").global_position+Vector2(0,40));await snap("04-controlled-actor-in-front")
	await native_collision("lamp",p.point("lamps",0),[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN])
	await go(p.point("lamps",0)+Vector2(0,40));await snap("05-lamp-volume-front")
	await native_collision("rubble",p.point("rubble"),[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN])
	await snap("06-heap-volume-front")
	for i in 4:await light(i,true)
	check(p.state.solved and p.state.order==[0,1,2,3],"correct four-light order still solves once")
	view._process(2.5);view._process(0);await frames(4);await physics_frame
	check(view.barrier.get_child(0).disabled and not view.rubble.visible,"completed heap no longer blocks floor")
	await native_collision("chest",p.point("chest"),[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN])
	await go(p.point("chest")+Vector2(0,45));await snap("07-chest-volume-front")
	await native_collision("ore",p.point("ores",1),[Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN])
	await go(p.point("ores",1)+Vector2(0,45));await snap("08-crystal-volume-front")
	FileAccess.open(DEST+"ready.json",FileAccess.WRITE).store_string(JSON.stringify(s.snapshot()))
	await go(p.point("chest")+Vector2(0,45));check(m.interact("chest").contains("路线记录") and p.state.claimed,"new volume still permits real reward interaction")
	var failed: int=checks.filter(func(row):return not row.pass).size();FileAccess.open(DEST+("headless" if DisplayServer.get_name()=="headless" else "window")+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "));print("MINE RULES COLLISION V4 ",checks.size()," checks ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(1 if failed else 0)
