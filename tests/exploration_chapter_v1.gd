extends "res://tests/sleep_v8_fixture.gd"
const DEST="res://reports/exploration-waits-v2/"
func snap(label: String) -> void:
	v.dial.queue_redraw();v.season_dial.queue_redraw()
	await frames(12);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DEST+label+".png")
func count(id: String) -> int:
	var n:=0
	for slot in s.inventory.slots:
		if slot.get("item_id","")==id:n+=int(slot.count)
	return n
func move_to(at: Vector2) -> void:
	w.player.position=at;w.player.camera.position_smoothing_enabled=false
	w.stream.target_center=Vector2i(-999,-999)
	w.stream.update_target(at)
	while not w.stream.viewport_ready(at,Vector2(640,360)):await process_frame
	await frames(6)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(DEST)
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds
	w.set_process(false);s.set_process(false);v.set_process(false);w.player.set_physics_process(false)
	w.player.automated=true;s.combat.state.boars.clear();s.combat.personal.phase="alive"
	root.size=default_size();root.content_scale_size=root.size
	check(not w.persistent_world and v.save_path.is_empty(),"isolated world no production save access")
	check(s.database.errors.is_empty(),"item schema valid")
	var q=s.chapter
	q.advance();check(q.state.stage==0 and q.state.site.is_empty(),"new world silent and empty")
	await frames();check(s.chapter_view.props.is_empty(),"no early placeholders")
	var fresh: Dictionary=s.snapshot().duplicate(true)
	s.load_state("",false,fresh);q.advance();check(q.state.stage==0,"early reload remains dormant")
	# Exercise actual facility placement, with test-only ingredients and normal costs.
	for id in ["copper_ingot","wood","stone"]:s.inventory.add(id,50)
	var row: Dictionary={}
	for y in range(-5,6):
		for x in range(-5,6):
			var candidate: Dictionary=b.candidate("metal_workbench",w.generator.spawn+Vector2(x*96,y*64),false,true,0)
			if b.reason(candidate).is_empty():row=candidate;break
		if not row.is_empty():break
	check(not row.is_empty(),"normal valid metal workbench site")
	check(b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"normal building transaction with cost")
	q.advance();check(q.state.stage==0,"facility alone insufficient")
	v.simulation.day=28;v.simulation.minute=1439
	q.advance();check(q.state.stage==0,"day 28 final minute remains dormant with workbench")
	var dormant: Dictionary=s.snapshot().duplicate(true)
	s.load_state("",false,dormant);q.advance();check(q.state.stage==0,"pre-day-29 reload remains dormant")
	v.simulation.day=29;v.simulation.minute=0
	q.advance();check(q.state.stage==1 and q.state.site.is_empty(),"time plus development qualifies separately")
	var qualified: Dictionary=s.snapshot().duplicate(true)
	s.load_state("",false,qualified);check(q.state.stage==1,"qualification survives reload")
	q.advance();check(q.state.stage==2,"safe site generated")
	if q.state.stage!=2:
		print("NO SITE");quit(1);return
	check(q.clear_site(q.point("site"),85),"site accessible clear terrain resources facilities spawn")
	check(q.point("site").distance_to(w.generator.spawn)>=1200,"away from spawn")
	var site: Vector2=q.point("site");var shore: Vector2=q.point("shore")
	await move_to(site+Vector2(-65,48));await snap("01-remains")
	check(s.chapter_view.props.has("remains") and s.chapter_view.props.has("belongings"),"real loaded investigation objects")
	var target: Node2D=s.chapter_view.props.remains
	check(preload("res://scripts/world_interaction.gd").in_reach(w.stream,w.player.position,target),"existing interaction reach")
	var slots: Array=s.inventory.slots.duplicate(true)
	for i in 40:s.inventory.slots[i]={"item_id":"wood","count":99}
	check(q.interact("remains").contains("空间不足") and q.state.stage==2,"full bag retains both clues")
	s.inventory.slots.assign(slots)
	for i in range(1,40):s.inventory.slots[i]={"item_id":"wood","count":99}
	s.inventory.slots[0]={}
	check(q.interact("remains").contains("空间不足") and count(q.MAP)==0 and q.state.stage==2,"one free slot rolls back partial clue grant")
	s.inventory.slots.assign(slots)
	w.persistent_world=true;s.save_path="res://reports/.tmp/exploration-v1/missing-parent/items.json"
	check(q.interact("remains").contains("保存失败") and q.state.stage==2 and count(q.MAP)==0,"failed disk write rolls back stage and both items")
	w.persistent_world=false
	w.player.facing="back";w.player.input_blocked=false
	Input.parse_input_event(key(KEY_E));await frames(2)
	var released:=key(KEY_E);released.pressed=false;Input.parse_input_event(released)
	check(s.chapter_view.panel.visible,"real E input opens investigation through existing selection")
	check(q.state.stage==3 and count(q.MAP)==1 and count(q.NOTE)==1,"map note and stage one transaction")
	await snap("02-investigation");s.chapter_view.close_page()
	q.interact("belongings");check(count(q.MAP)==1 and count(q.NOTE)==1,"repeat objects never duplicate")
	w.persistent_world=true;s.save_path="res://reports/.tmp/exploration-v1/items-isolated.json"
	check(s.save_state(),"atomic disk save")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(s.save_path))
	check(q.valid(saved.exploration_chapter),"JSON chapter schema validates after numeric conversion");q.state=q.initial();s.load_state("",false,saved)
	check(q.state.stage==3 and q.point("site")==site and count(q.MAP)==1,"disk reload exact site items progress")
	w.persistent_world=false
	await move_to(w.generator.spawn);await move_to(site+Vector2(0,60))
	check(q.point("site")==site,"leave and return stable location")
	check(not q.state.elder_spawned and not q.special(q.state.lake),"no immediate elder or special catch after investigation")
	var deadline: float=q.state.elder_due
	check(deadline-q.state.investigated_at in [1440.0,2880.0],"seeded one or two COMPLETE days")
	check(q.interact("shore")=="尚未发现线索" and q.state.stage==3,"forged old shore request cannot skip wait")
	var waiting: Dictionary=s.snapshot().duplicate(true)
	s.load_state("",false,waiting)
	check(q.state.elder_due==deadline,"reload preserves precise waiting deadline")
	v.simulation.advance_calendar((deadline-q.now()-1)*2.5)
	q.last_placement_attempt=-30000;q.advance()
	check(not q.state.elder_spawned,"one minute before deadline still no elder")
	v.simulation.advance_calendar(2.5);q.last_placement_attempt=-30000;q.advance()
	check(q.state.elder_spawned,"elder appears at complete-day deadline")
	if not q.state.elder_spawned:
		print("RIVERS ",w.generator.rivers.size());quit(1);return
	var elder: Vector2=q.point("elder")
	check(q.elder_on_coast() and w.generator.can_walk(elder,20) and w.generator.sample(q.point("river_fish")).z>.8,"real walkable outer coast and valid deep water")
	q.last_placement_attempt=-30000;q.advance();check(q.point("elder")==elder,"one stable elder after repeated advance")
	await move_to(elder+Vector2(-65,25));await snap("03-elder-world")
	var original_zoom: Vector2=w.player.camera.zoom
	w.player.camera.zoom=Vector2.ONE*1.65;await snap("03-elder-enlarged")
	w.player.camera.zoom=original_zoom
	await move_to(elder+Vector2(0,35))
	check(s.chapter_view.props.has("shore"),"loaded real elder entity")
	check(not q.special(q.state.lake),"no special before actual dialogue")
	w.player.input_blocked=false;w.player.facing="back"
	Input.parse_input_event(key(KEY_E));await frames(2)
	Input.parse_input_event(released)
	check(s.chapter_view.panel.visible and q.state.stage==4,"real E opens first elder dialogue")
	check(q.state.fishing_due-q.state.dialogue_at==1440.0 and not q.special(q.state.lake),"dialogue starts complete one-day wait")
	var fishing_deadline: float=q.state.fishing_due
	q.interact("shore");check(q.state.fishing_due==fishing_deadline,"repeated dialogue never resets wait")
	await snap("03-elder-dialogue");s.chapter_view.close_page()
	waiting=s.snapshot().duplicate(true);s.load_state("",false,waiting)
	check(q.state.fishing_due==fishing_deadline,"fishing wait survives restored world clock")
	v.simulation.advance_calendar((fishing_deadline-q.now()-1)*2.5);q.advance()
	check(not q.special(q.state.lake),"one minute before special opening")
	v.simulation.advance_calendar(2.5);q.advance()
	check(q.state.fishing_open and q.special(q.state.lake),"special catch opens after full day")
	FileAccess.open("res://reports/.tmp/exploration-waits-v2/ready.json",FileAccess.WRITE).store_string(JSON.stringify(s.snapshot()))
	for id in [q.MAP,q.NOTE]:
		s.chapter_view.open_item(id);await snap("paper-"+id)
		check(w.player.input_blocked,"paper blocks game input "+id);s.chapter_view.close_page()
	check(not q.special(-1),"other water keeps normal loot")
	var f=w.get_node("Fishing")
	f.loot_rng.seed=91234
	check(f.catch_for_roll(.9)=="lake_fish" and f.catch_for_roll(0)=="locked_chest" and f.catch_for_roll(.01)=="gold_coin","original loot table unchanged")
	s.inventory.add("fishing_rod",1)
	for i in 40:
		if s.inventory.slots[i].get("item_id","")=="fishing_rod":s.inventory.equip(i);break
	f.refresh_chapter_spots()
	var chosen: Dictionary=f.spots[-1]
	await move_to(chosen.stand+(chosen.water-chosen.stand).normalized().orthogonal()*30)
	check(w.generator.can_walk(w.player.position,12) and w.player.position.distance_to(elder)>20,"player fishes beside elder without overlapping collider")
	var attempts_before: int=q.state.attempts
	check(f.try_start(),"real fishing cancellation starts")
	f.finish("");check(q.state.attempts==attempts_before,"cancel never advances guarantee")
	check(f.try_start(),"real failure fishing starts")
	f.advance(1);f.advance(5);f.advance(1);f.resolve_attempt(false);f.resolve_attempt(false);f.finish("")
	check(q.state.attempts==attempts_before,"failed timing never advances guarantee")
	check(f.try_start(),"real fishing starts with rod and valid lake")
	var fishing_snapshot: Dictionary=f.network_snapshot()
	f.network_restore(fishing_snapshot)
	check(f.state=="cast" and f.selected==f.spots.size()-1 and f.spots[f.selected].get("chapter_only",false),"network restore preserves active river fishing index")
	# Normal game phases and timing judge. No direct inventory reward injection.
	f.advance(1);f.advance(5);f.advance(1)
	for hit in 2:
		f.bar.marker=f.bar.safe_center;f.input_cooldown=0;f.judge()
	check(f.state=="success","existing timing rounds reach success")
	await snap("04-fishing-success")
	var old: Dictionary=q.serialize();slots=s.inventory.slots.duplicate(true)
	for i in 40:s.inventory.slots[i]={"item_id":"wood","count":99}
	f.commit_reward();check(not q.state.bottle_claimed and q.state==old,"full bag catch preserves guarantee")
	s.inventory.slots.assign(slots);f.reward_committed=false;f.commit_reward()
	f.finish("")
	for attempt in 2:
		if q.state.bottle_claimed:break
		check(f.try_start(),"subsequent real fishing attempt")
		f.advance(1);f.advance(5);f.advance(1)
		for hit in 2:
			f.bar.marker=f.bar.safe_center;f.input_cooldown=0;f.judge()
		f.commit_reward();f.finish("")
	check(q.state.bottle_claimed and not q.state.bottle_read and count(q.BOTTLE)==1,"bottle acquired once remains unread")
	check(count("lake_fish")>0 and q.state.attempts==2,"ordinary fishing awards fish before bounded third special catch")
	f.commit_reward();check(count(q.BOTTLE)==1,"repeated fishing settlement idempotent")
	f.finish("")
	for i in 40:
		if s.inventory.slots[i].get("item_id","")==q.BOTTLE:
			w.item_ui.open_item_menu(i,Vector2(920,350))
			check(w.item_ui.use_button.text=="打开","real item context menu opens unread bottle")
			w.item_ui.use_button.pressed.emit();break
	check(q.state.stage==5 and q.state.bottle_read,"reading alone completes mine clue")
	await snap("05-mine-clue")
	q.use_item(q.BOTTLE);check(count(q.BOTTLE)==1 and q.state.stage==5,"reread persistent nonconsumable no rewards")
	check(q.interact("shore").contains("废弃矿洞"),"shared shore record retains opened mine clue")
	s.chapter_view.show_page(q.interact("shore"));await snap("06-shared-transcript")
	check(s.chapter_view.words.text.begins_with("垂钓老者"),"new dialogue is not overwritten by previously opened bottle")
	check(s.chapter_view.words.get_minimum_size().y<=s.chapter_view.words.size.y and s.chapter_view.words.position.y+s.chapter_view.words.size.y<=s.chapter_view.panel.size.y-24,"shared transcript text stays inside actual paper")
	s.chapter_view.close_page()
	check(q.valid(q.serialize()),"chapter valid roundtrip")
	check(q.mine_hook().get("landmark")=="three_slashes" and not q.mine_hook().unlocked and q.state.mine_due==q.state.bottle_read_at+1440.0,"mine hook records full-day gate, no same-frame unlock")
	var read_deadline: float=q.state.mine_due
	q.read(q.BOTTLE);check(q.state.mine_due==read_deadline,"repeat bottle read preserves future deadline")
	for dimensions in [Vector2i(960,540),Vector2i(1600,900)]:
		root.size=dimensions;root.content_scale_size=dimensions
		for id in [q.MAP,q.NOTE,q.BOTTLE]:
			s.chapter_view.open_item(id);await snap("paper-"+id+"-"+str(dimensions.x))
			var panel=s.chapter_view.panel
			check(panel.position.x>=0 and panel.position.y>=0 and (panel.position+panel.size*panel.scale).x<=dimensions.x and (panel.position+panel.size*panel.scale).y<=dimensions.y,"paper inside requested window "+str(dimensions)+id)
	root.size=default_size();root.content_scale_size=root.size
	# Isolated failure branch: no active ordinary schools must not block the clue.
	var final_chapter: Dictionary=q.serialize()
	var final_slots: Array=s.inventory.slots.duplicate(true)
	var final_population: Dictionary=s.fishing_population.serialize()
	s.chapter_view.close_page()
	q.state.stage=4;q.state.bottle_claimed=false;q.state.bottle_read=false;q.state.attempts=2
	for i in 40:
		if s.inventory.slots[i].get("item_id","")==q.BOTTLE:s.inventory.slots[i]={}
	for spot in s.fishing_population.spots:
		if spot.lake==q.state.lake:spot.remaining=0;spot.respawn_minutes=60
	f.refresh_chapter_spots();await move_to(q.point("elder"))
	check(f.try_start() and f.spots[f.selected].get("chapter_only",false),"depleted lake retains actual fishing fallback")
	f.advance(1);f.advance(5);f.advance(1)
	for hit in 2:
		f.bar.marker=f.bar.safe_center;f.input_cooldown=0;f.judge()
	check(f.catch_id==q.BOTTLE,"success animation shows actual bottle before settlement")
	w.persistent_world=true;s.save_path="res://reports/.tmp/exploration-v1/missing-parent/items.json"
	f.commit_reward()
	check(not q.state.bottle_claimed and count(q.BOTTLE)==0 and q.state.attempts==2,"failed catch save rolls back unique award and guarantee")
	w.persistent_world=false;f.reward_committed=false;f.commit_reward()
	check(q.state.bottle_claimed and count(q.BOTTLE)==1,"depleted lake catch succeeds without random gate")
	f.finish("");q.state=final_chapter;s.inventory.slots.assign(final_slots);s.fishing_population.restore(final_population)
	var invalid: Dictionary=q.serialize();invalid.version=99;check(not q.valid(invalid),"future version protected")
	var text: String=q.text(q.MAP)+q.text(q.NOTE)+q.shore_text()+q.text(q.BOTTLE)
	check(not ["海域","岛屿","航海","造船","宝箱"].any(func(word):return word in text),"no final secret exposed")
	var file:=FileAccess.open(DEST+"checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(checks,"  "));file.close()
	var failed:=checks.filter(func(c):return not c.pass).size();print("EXPLORATION ",checks.size()," checks ",failed," failed")
	quit(1 if failed else 0)
