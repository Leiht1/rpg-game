extends "res://tests/sleep_v8_fixture.gd"
const DEST="res://reports/mine-puzzle-v1/"
func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await frames(5);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(DEST+name+".png")
func go(at: Vector2) -> void:
	w.player.position=at;w.player.camera.reset_smoothing();w.player.reset_physics_interpolation();await frames(3)
func lamp(i: int) -> String:
	await go(s.chapter.puzzle.point("lamps",i)+Vector2(0,60))
	return s.chapter.mine.interact("lamp:"+str(i))
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view
	w.set_process(false);s.set_process(false);v.set_process(false);w.player.set_physics_process(false);w.player.automated=true
	w.player.camera.position_smoothing_enabled=false;s.guide_stage=2;s.combat.state.boars.clear();s.combat.personal.phase="alive"
	root.size=default_size();root.content_scale_size=root.size
	var q=s.chapter;var m=q.mine;var p=q.puzzle
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/.tmp/mine-ready.json"))
	q.state=q.migrate(source.exploration_chapter);m.state.phase="open";m.state.entered=true;m.state.fuse_remaining_seconds=0.0
	m.travel={"inside":true,"serial":1};q.state.mine.puzzle=p.initial()
	for i in 40:s.inventory.slots[i]={}
	s.body.health=100;s.body.energy=100;s.body.hunger=100
	await go(m.origin()+Vector2(0,200));await frames(12)
	check(s.database.errors.is_empty(),"formal item schema")
	check(p.valid(p.state),"fresh puzzle schema")
	check(q.valid(q.serialize()),"old chapter migration retains valid first two rounds")
	var view=s.chapter_view.get_node("PuzzleView")
	view.sync();check(view.ores.is_empty() and not view.targets.chest.visible,"hidden rewards absent before solve")
	check(p.interact("chest")!="木箱中留着一份古老的路线记录。","remote reward rejected")
	await snap("01-room-unsolved")
	for i in 4:
		await go(p.point("carvings",i)+Vector2(0,45));var page: String=m.interact("carving:"+str(i))
		check(page==p.OBSERVATIONS[i],"wall clue "+str(i)+" reachable")
		s.chapter_view.show_page(page);await snap("02-carving-"+str(i));s.chapter_view.close_page()
	await go(p.point("inscription")+Vector2(0,55));check(m.interact("inscription").contains("先苏醒"),"main inscription")
	await lamp(0);check(p.state.progress==1,"first correct lamp")
	await lamp(3);check(p.state.progress==0 and not p.state.solved,"wrong order resets")
	var original: Dictionary=q.serialize();var old_path: String=s.save_path
	w.persistent_world=true;s.save_path="res://reports/mine-puzzle-v1/missing/fail.json"
	check((await lamp(0)).contains("保存失败") and p.state.progress==0,"lamp save failure rollback")
	w.persistent_world=false;s.save_path=old_path
	for i in 4:await lamp(i)
	check(p.state.solved and p.state.vein_unlocked and p.state.rubble_fallen,"four lamps unlock one permanent result")
	await go(m.origin()+Vector2(0,60));await create_timer(.65).timeout;await snap("03-collapse")
	await create_timer(2.0).timeout;view.sync();await snap("04-revealed")
	check(view.ores.size()==3 and view.targets.chest.visible,"three real mine nodes and chest revealed")
	await lamp(2);check(p.state.progress==4,"completed lamp refuses restart")
	await go(p.point("chest")+Vector2(0,55))
	for i in 40:s.inventory.slots[i]={"item_id":"wood","count":99}
	check(m.interact("chest").contains("背包已满") and not p.state.claimed,"full bag preserves chest")
	for i in 40:s.inventory.slots[i]={}
	w.persistent_world=true;s.save_path="res://reports/mine-puzzle-v1/missing/fail.json"
	check(m.interact("chest").contains("保存失败") and not p.state.claimed and s.inventory.count_item(p.RECORD)==0,"chest write failure rolls reward back")
	w.persistent_world=false;s.save_path=old_path
	check(m.interact("chest").contains("路线记录") and p.state.claimed and not p.state.read,"claim once does not auto-read")
	check(s.inventory.count_item(p.RECORD)==1,"one official key item")
	check(q.use_item(p.RECORD) and p.state.read,"real inventory reader starts world wait")
	s.chapter_view.close_page();var due: float=p.state.next_due
	check(due-p.state.read_at in [1440.0,2880.0],"seeded one or two complete days")
	m.interact("chest");check(s.inventory.count_item(p.RECORD)==1 and p.state.next_due==due,"chest repeat and reread cannot duplicate or reset wait")
	await go(p.point("ores",0)+Vector2(0,65));view.sync();var node: Node2D=view.ores[0]
	check(not s.harvest_hit(node,"mine") and p.state.ores[0].hits==0,"unarmed cannot harvest")
	s.inventory.add("stone_pickaxe",1)
	for i in 40:
		if s.inventory.slots[i].get("item_id")=="stone_pickaxe":s.inventory.equip(i);break
	check(s.inventory.has_capability("mine"),"formal pickaxe equipped")
	var durability: int=s.inventory.equipment.main_hand.durability
	w.persistent_world=true;s.save_path="res://reports/mine-puzzle-v1/missing/fail.json"
	check(not s.harvest_hit(node,"mine") and p.state.ores[0].hits==0 and s.inventory.equipment.main_hand.durability==durability,"mining write failure restores ore and tool")
	w.persistent_world=false;s.save_path=old_path
	for i in int(p.config.hits):
		if not is_instance_valid(node) or p.state.ores[0].hits>=int(p.config.hits):break
		s.harvest_hit(node,"mine");s.body.stamina=100
	check(s.inventory.count_item("crystal")==int(p.config["yield"]) and p.state.ores[0].hits==int(p.config.hits),"rare crystal yield exactly two")
	check(s.inventory.equipment.main_hand.durability==durability-int(p.config.hits),"existing pick durability per hit")
	check(not s.harvest_hit(node,"mine"),"duplicate depleted hit cannot reward")
	var saved: Dictionary=s.snapshot().duplicate(true)
	check(q.valid(saved.exploration_chapter),"complete state schema")
	FileAccess.open(DEST+"saved.json",FileAccess.WRITE).store_string(JSON.stringify(saved))
	q.state=q.migrate(saved.exploration_chapter);p.advance();check(p.state.ores[0].hits==int(p.config.hits),"reload does not refresh")
	var respawn: float=p.state.ores[0].respawn_at
	check(respawn-p.state.ores[0].depleted_at==8640,"six full calendar days")
	v.simulation.day=int(floor((respawn-.1)/1440))+1;v.simulation.minute=fposmod(respawn-.1,1440);p.advance();check(p.state.ores[0].hits==int(p.config.hits),"not early before deadline")
	v.simulation.minute+=.2;p.advance();check(p.state.ores[0].hits==0 and p.state.ores[1].hits==0,"independent ore regrows by world time")
	view.sync();await frames(5);check(view.clock>2.4,"reload state does not replay collapse")
	check(p.continuation().eligible,"next-stage eligibility only no generated ruin")
	var failed: int=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(DEST+("headless" if DisplayServer.get_name()=="headless" else "window")+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("MINE PUZZLE ",checks.size()," checks ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(1 if failed else 0)
