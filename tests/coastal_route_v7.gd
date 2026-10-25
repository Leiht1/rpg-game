extends "res://tests/mine_clues_route_v5.gd"
func run() -> void:
	Engine.set_meta("integration_seed",271828);w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w);current_scene=w
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view;w.set_process(false);s.set_process(false);v.set_process(false);w.player.set_physics_process(false);w.player.automated=true;w.player.camera.position_smoothing_enabled=false
	s.guide_stage=2;s.combat.state.boars.clear();s.combat.personal.phase="alive";root.size=default_size();root.content_scale_size=root.size
	var q=s.chapter;var m=q.mine;var p=q.puzzle;var ui=s.chapter_view
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/.tmp/mine-ready.json"))
	q.state=q.migrate(source.exploration_chapter);m.state.phase="open";m.state.entered=true;m.state.fuse_remaining_seconds=0.0;m.travel={"inside":true,"serial":1};m.state.puzzle=p.initial()
	p.state.order=[0,1,2,3];p.state.progress=4;p.state.solved=true;p.state.vein_unlocked=true;p.state.rubble_fallen=true
	for i in 40:s.inventory.slots[i]={}
	s.body.health=100;s.body.energy=100;s.body.hunger=100
	await go(p.point("chest")+Vector2(0,45));await frames(12);view=ui.get_node("PuzzleView");view.set_process(false);view._process(0)
	check(s.database.errors.is_empty(),"formal item definition valid")
	check(p.RECORD=="ancient_mine_record" and s.database.item(p.RECORD).max_stack==1,"original key item ID and stack limit unchanged")
	for i in 40:s.inventory.slots[i]={"item_id":"wood","count":99}
	check(m.interact("chest").contains("背包已满") and not p.state.claimed,"full bag still preserves unique reward")
	for i in 40:s.inventory.slots[i]={}
	var old_path: String=s.save_path;w.persistent_world=true;s.save_path="res://reports/coastal-route-v7/missing/sub/items.json"
	check(m.interact("chest").contains("保存失败") and not p.state.claimed and s.inventory.count_item(p.RECORD)==0,"failed save still rolls back original chest claim")
	w.persistent_world=false;s.save_path=old_path
	check(m.interact("chest").contains("路线记录") and p.state.claimed and not p.state.read,"original chest award remains claim-only")
	check(s.inventory.count_item(p.RECORD)==1,"exactly one unchanged reward ID")
	var before_hint: Dictionary=q.serialize();var hint: Dictionary=p.route_hint.resolve(s)
	check(q.serialize()==before_hint,"new clue contract has no saved-progress side effects")
	check(hint.terrain=="sea_eroded_ruins_plateau" and not hint.target_generated,"future coastal special terrain remains ungenerated")
	check(hint.requirements.different_rock_region_from_mine and hint.requirements.connected_to_ordinary_rock and hint.requirements.independent_special_terrain,"different ordinary rock area and independent platform constraints retained")
	check(hint.direction_resolved,"current isolated world's coastal bearing resolves")
	if hint.direction_resolved:
		var center:=Vector2(hint.search_area.center.x,hint.search_area.center.y)
		check(w.generator.biome(center)=="岩石区" and w.generator.can_walk(center,24),"coarse sector actually exists in ordinary rocky land")
		check(hint.source_rock_region!=hint.connected_rock_region,"coarse sector is not mine's connected rock region")
		check(w.generator.coast_distance(center)>=180 and w.generator.coast_distance(center)<=900,"actual outer coast proximity")
	check(q.use_item(p.RECORD) and ui.route_visible and p.state.read,"existing inventory reading opens new artwork")
	check(ui.route_paper.get_child_count()==1 and not ui.words.visible and not ui.paper.visible and ui.route_paper.picture.texture.resource_path.contains("coastal-route-v7/route-paper"),"coastal route painting is the visible reading content")
	check(ui.reading_layer.layer>w.item_ui.obtained.layer and page_fits(),"no reward toast overlay or paper cropping")
	await capture_page("01-route-default")
	var due: float=p.state.next_due;var read_at: float=p.state.read_at
	check(due-read_at==1440.0*(1+posmod(w.world_seed^73931,2)),"existing seed-based one-or-two full-day wait unchanged")
	var old_scale: Vector2=ui.panel.scale;var camera_zoom: Vector2=w.player.camera.zoom
	await wheel(true);await wheel(true);await wheel(true)
	check(ui.panel.scale.x>old_scale.x and ui.panel.scale.x==ui.panel.scale.y and page_fits(),"whole paper zoom remains proportional and uncropped")
	check(w.player.camera.zoom==camera_zoom,"reading zoom does not change game camera")
	await capture_page("02-route-zoom")
	for i in 3:
		ui.close_page();check(q.use_item(p.RECORD) and s.inventory.count_item(p.RECORD)==1 and p.state.next_due==due and p.state.read_at==read_at,"repeat reading preserves reward and wait "+str(i))
	ui.close_page();var saved: Dictionary=s.snapshot().duplicate(true);s.load_state("",false,JSON.parse_string(JSON.stringify(saved)));await frames(4)
	check(s.writable and s.inventory.count_item(p.RECORD)==1 and absf(p.state.next_due-due)<.000001,"save reload retains original ownership and deadline")
	check(q.use_item(p.RECORD) and ui.route_paper.hint==hint,"same coastal clue after save reload")
	root.push_input(key(KEY_ESCAPE),true);await frames(3);check(not ui.panel.visible and not w.player.input_blocked,"existing close control works")
	for size in [Vector2i(960,540),Vector2i(1600,900)]:
		root.size=size;root.content_scale_size=size;q.use_item(p.RECORD);ui.layout_page();await frames(4);check(page_fits(),"focused paper-fit check "+str(size));await capture_page("03-route-"+str(size.x));ui.close_page()
	root.size=default_size();root.content_scale_size=root.size
	check(p.state.solved and view.ores.size()==3 and q.valid(q.serialize()),"existing completed gameplay state remains valid")
	FileAccess.open("res://reports/coastal-route-v7/route-hint.json",FileAccess.WRITE).store_string(JSON.stringify(hint,"  "));FileAccess.open("res://reports/coastal-route-v7/ready.json",FileAccess.WRITE).store_string(JSON.stringify(s.snapshot()))
	var failed: int=checks.filter(func(row):return not row.pass).size();FileAccess.open("res://reports/coastal-route-v7/window.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "));print("COASTAL ROUTE V7 ",checks.size()," checks ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(1 if failed else 0)
func capture_page(name: String) -> void:
	w.item_ui.message_time=0;await create_timer(.2).timeout;await frames(3);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/coastal-route-v7/"+name+".png")


