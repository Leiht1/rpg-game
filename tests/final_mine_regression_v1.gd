extends "res://tests/final_chapter_v1.gd"
func go(p: Vector2) -> void:
	w.player.position=p;w.stream.update_target(p);await frames(4)
func run() -> void:
	Engine.set_meta("integration_seed",271828);w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w);current_scene=w
	while not w.started:await process_frame
	s=w.item_service;w.set_process(false);s.set_process(false);w.environment_view.set_process(false);w.player.set_physics_process(false);w.player.automated=true
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/coastal-route-v7/ready.json"))
	s.chapter.state=s.chapter.migrate(source.exploration_chapter);s.chapter.mine.travel={"inside":true,"serial":1};s.chapter.mine.state.puzzle=s.chapter.puzzle.initial();s.body.health=100;s.body.energy=100;s.combat.personal.phase="alive";s.combat.personal.attack={}
	var q=s.chapter;var p=q.puzzle;var m=q.mine;var before: Dictionary=q.serialize()
	check(q.state.stage==5 and q.state.bottle_claimed and q.state.bottle_read and m.state.phase=="open","first and second round progress preserved")
	await go(p.point("chest")+Vector2(0,45));check(not m.interact("chest").is_empty() and not p.state.claimed,"unsolved lamp room cannot give route map")
	for i in 4:
		await go(p.point("carvings",i)+Vector2(0,40));check(m.interact("carving:"+str(i))==p.OBSERVATIONS[i],"existing wall clue "+str(i))
	for i in [0,3,1,2]:await go(p.point("lamps",i)+Vector2(0,40));m.interact("lamp:"+str(i))
	check(p.state.progress==0 and not p.state.solved,"wrong complete lamp order resets safely")
	for i in 4:await go(p.point("lamps",i)+Vector2(0,40));m.interact("lamp:"+str(i))
	check(p.state.solved and p.state.vein_unlocked and p.state.rubble_fallen,"correct four-season sequence unlocks crystal and original chest")
	await create_timer(2.5).timeout;await go(p.point("chest")+Vector2(0,45))
	for i in 40:s.inventory.slots[i]={}
	check(m.interact("chest").contains("路线记录") and s.inventory.count_item(p.RECORD)==1,"original route map claim works")
	check(q.use_item(p.RECORD) and p.state.read,"original illustrated map reading works")
	s.chapter_view.close_page();var due: float=p.state.next_due;m.interact("chest");s.chapter_view.close_page()
	check(p.state.next_due==due and s.inventory.count_item(p.RECORD)==1,"reread cannot duplicate map or reset wait")
	check(q.state.stage==before.stage and q.state.bottle_claimed==before.bottle_claimed and m.state.site==before.mine.site and m.state.phase=="open","preceding chapters never reset")
	check(q.valid(q.serialize()),"continued complete exploration schema remains valid")
	var failed: int=checks.filter(func(c):return not c.pass).size();FileAccess.open("res://reports/final-chapter-v1/mine-regression.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "));print("MINE CURRENT REGRESSION ",checks.size()," checks ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(1 if failed else 0)
