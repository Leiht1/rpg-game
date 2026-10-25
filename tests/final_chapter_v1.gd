extends SceneTree
var w: Node
var s: Node
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func check(ok: bool, title: String) -> void:
	checks.append({"pass":ok,"test":title});print("PASS " if ok else "FAIL ",title)
func run() -> void:
	Engine.set_meta("integration_seed",271828);w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w);current_scene=w
	while not w.started:await process_frame
	s=w.item_service;w.set_process(false);s.set_process(false);w.environment_view.set_process(false);w.player.set_physics_process(false);w.player.automated=true
	w.player.camera.position_smoothing_enabled=false;s.combat.state.boars.clear();s.guide_stage=2
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/coastal-route-v7/ready.json"))
	s.chapter.state=s.chapter.migrate(source.exploration_chapter);s.chapter.mine.travel={"inside":false,"serial":2}
	w.environment_view.simulation.day=30;w.environment_view.simulation.minute=600
	var f=s.chapter.finale;var puzzle=s.chapter.puzzle
	var hint: Dictionary=puzzle.route_hint.resolve(s)
	print("CANDIDATES ",hint.get("placement_candidates",[]).size())
	var old_time: float=puzzle.state.next_due;puzzle.state.next_due=s.chapter.now()+1440
	f.advance();check(f.state.site.is_empty(),"no premature site before full-day deadline")
	puzzle.state.read_at=s.chapter.now()-1440;puzzle.state.next_due=s.chapter.now();f.retry_at=-30000;f.advance()
	check(f.state.eligible,"deadline grants eligibility")
	check(not f.state.site.is_empty(),"safe different-rock coastal site generated")
	if f.state.site.is_empty():finish();return
	check(f.state.site!=s.chapter.mine.state.site,"mine site preserved and distinct")
	check(w.generator.coast_distance(f.at())>=180 and w.generator.coast_distance(f.at())<=900,"site on actual outer coast rock")
	for i in 40:s.inventory.slots[i]={}
	s.body.health=100;s.body.energy=100;s.body.hunger=100;s.combat.personal.phase="alive"
	w.player.position=f.at()+Vector2(0,140);w.stream.update_target(w.player.position);await frames(120)
	f.tick(.1);check(f.state.triggered and f.state.discovered,"nearby live player triggers guardian")
	check(f.interact("chest")!="" and not f.state.chest_open,"living boss blocks chest")
	var modes: Dictionary={}
	for i in 140:
		f.tick(.1);modes[f.state.boss.attack]=true
	check(modes.has("slam") and modes.has("charge"),"phase one cycles real attacks")
	f.state.boss.health=170;f.state.boss.mode="chase";f.state.boss.clock=1;f.state.boss.sequence=0;f.tick(.05)
	check(f.state.boss.attack=="core" and f.state.boss.mode=="windup","phase two introduces warned core burst")
	for attack in ["slam","charge","quake","core"]:
		f.reset_boss();f.state.triggered=true;f.state.discovered=true
		var b: Dictionary=f.state.boss;b.mode="windup";b.attack=attack;b.clock=0.0;b.direction={"x":0.0,"y":1.0};b.hits={}
		w.player.position=f.boss_at()+Vector2(0,65);s.body.health=100;s.combat.personal.phase="alive"
		f.tick(float(f.config.windup[attack])-.05);check(s.body.health==100,"visible windup has no damage: "+attack)
		f.tick(.12);var after_hit: float=s.body.health
		check(after_hit==82,"active attack deals configured single hit: "+attack)
		f.tick(.05);check(s.body.health==after_hit,"same attack does not damage every frame: "+attack)
		f.reset_boss();b=f.state.boss;b.mode="windup";b.attack=attack;b.clock=0.0;b.direction={"x":0.0,"y":1.0};b.hits={}
		w.player.position=f.boss_at()+(Vector2(140,65) if attack=="charge" else Vector2(0,float(f.config.range.get(attack,100))+80));s.body.health=100
		f.tick(float(f.config.windup[attack])+.15);check(s.body.health==100,"walking outside warned geometry avoids hit: "+attack)
	f.reset_boss();var stump: Vector2=f.at()+Vector2(385,-110);f.state.boss.x=stump.x-100;f.state.boss.y=stump.y
	for i in 20:f.move_boss(Vector2(10,0))
	check(f.boss_at().distance_to(stump)>=56,"boss charge movement cannot pass through ruin column foot")
	w.player.position=f.at()+Vector2(1000,0);f.tick(.1);check(f.state.boss.mode=="idle" and f.state.boss.health==float(f.config.health),"leaving arena resets guardian without erasing progress")
	w.player.position=f.boss_at()+Vector2(0,60);s.body.health=100;s.combat.personal.phase="alive"
	var a: Dictionary={"targets":{},"direction":{"x":0,"y":-1},"weapon":{"range":120,"damage":400}}
	f.hit(a);check(f.state.defeated and f.state.boss.mode=="dead","normal melee hit resolves permanent boss death")
	check(s.inventory.count_item(f.CORE)==0 and not f.state.core_claimed,"core is independent world loot, not auto inventory or chest content")
	for i in 40:s.inventory.slots[i]={"item_id":"wood","count":99}
	check(f.interact("core").contains("空间") and not f.state.core_claimed,"full bag preserves core")
	for i in 40:s.inventory.slots[i]={}
	check(f.interact("core")=="" and s.inventory.count_item(f.CORE)==1,"core claim succeeds exactly once")
	f.interact("core");check(s.inventory.count_item(f.CORE)==1,"repeated core claim cannot duplicate")
	w.player.position=f.chest_at()+Vector2(0,50)
	var only_core: Array=s.inventory.slots.duplicate(true)
	for i in range(9,40):s.inventory.slots[i]={"item_id":"wood","count":99}
	s.inventory.slots[39]={}
	check(f.interact("chest").contains("空间") and not f.state.chest_open and s.inventory.count_item(f.LETTER)==0 and s.inventory.count_item(f.BLUEPRINT)==0,"one free slot cannot partially take two final rewards")
	s.inventory.slots.assign(only_core)
	var path: String=s.save_path;w.persistent_world=true;s.save_path="res://reports/final-chapter-v1/no-dir/items.json"
	check(f.interact("chest").contains("保存失败") and not f.state.chest_open and s.inventory.count_item(f.BLUEPRINT)==0,"failed disk write rolls back chest and both rewards")
	w.persistent_world=false;s.save_path=path
	check(f.interact("chest")=="" and f.state.chest_open,"defeated guardian unlocks final chest")
	check(s.inventory.count_item(f.LETTER)==1 and s.inventory.count_item(f.BLUEPRINT)==1,"chest awards exactly illustrated record and blueprint")
	f.interact("chest");check(s.inventory.count_item(f.BLUEPRINT)==1,"repeated chest request idempotent")
	check(s.chapter.use_item(f.LETTER) and s.chapter_view.route_visible,"illustrated final record opens through inventory")
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/final-chapter-v1/letter.png");s.chapter_view.close_page()
	w.persistent_world=true;s.save_path="res://reports/final-chapter-v1/no-dir/items.json"
	check(not s.chapter.use_item(f.BLUEPRINT) and not f.state.dock_unlocked and s.inventory.count_item(f.BLUEPRINT)==1,"failed blueprint save restores item and locked recipe")
	w.persistent_world=false;s.save_path=path
	check(s.chapter.use_item(f.BLUEPRINT) and f.state.dock_unlocked and s.inventory.count_item(f.BLUEPRINT)==0,"blueprint consumed atomically with dock unlock")
	check(s.camps.build_book.recipe("build_dock").default_unlocked,"dock recipe is genuinely available in existing construction book")
	check(not s.chapter.use_item(f.BLUEPRINT),"repeated blueprint use rejected")
	var snapshot: Dictionary=JSON.parse_string(JSON.stringify(s.snapshot()));check(s.chapter.valid(snapshot.exploration_chapter),"complete saved chapter validates")
	s.load_state("",false,snapshot);check(s.writable and f.state.defeated and f.state.chest_open and f.state.dock_unlocked,"JSON restore preserves boss, chest, rewards and dock")
	f.tick(5);check(f.state.defeated,"guardian never respawns after victory")
	w.player.position=f.at()+Vector2(0,200);w.player.camera.zoom=Vector2.ONE*.8;w.stream.update_target(w.player.position);await frames(60)
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/final-chapter-v1/arena.png")
	FileAccess.open("res://reports/final-chapter-v1/ready.json",FileAccess.WRITE).store_string(JSON.stringify(s.snapshot()))
	puzzle.state.next_due=old_time
	finish()
func finish() -> void:
	var failed: int=checks.filter(func(c):return not c.pass).size()
	FileAccess.open("res://reports/final-chapter-v1/window.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "));print("FINAL CHAPTER ",checks.size()," checks ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(1 if failed else 0)
