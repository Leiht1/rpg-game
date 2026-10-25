extends "res://tests/sleep_v8_fixture.gd"
const DEST="res://reports/mine-v1/"
func snap(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	v.dial.queue_redraw();v.season_dial.queue_redraw()
	if label in ["05-inside","06-return"]:await create_timer(3.1).timeout
	await frames(8);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DEST+label+".png")
func move_to(at: Vector2) -> void:
	w.player.position=at;w.player.camera.position_smoothing_enabled=false
	w.stream.update_target(at)
	while not w.stream.viewport_ready(at,Vector2(640,360)):await process_frame
	await frames(8)
func wait_transition() -> void:
	while s.chapter_view.transition.active:await process_frame
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds
	w.set_process(false);s.set_process(false);v.set_process(false);w.player.set_physics_process(false)
	w.player.automated=true;s.combat.state.boars.clear();s.combat.personal.phase="alive";s.guide_stage=2
	root.size=default_size();root.content_scale_size=root.size
	var q=s.chapter;var m=q.mine
	check(s.database.errors.is_empty() and s.craft_book.errors.is_empty(),"formal item and recipe schemas")
	check(not s.craft_book.available().any(func(r):return r.output_id=="miner_blast_pack"),"unknown recipe hidden")
	q.advance();check(m.state.site.is_empty(),"unread no mine")
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/.tmp/exploration-waits-v2/ready-coast.json"))
	q.state=q.migrate(source.exploration_chapter)
	q.state.bottle_claimed=true;q.state.bottle_read=false;q.state.stage=4
	s.inventory.add(q.BOTTLE,1)
	check(q.read(q.BOTTLE),"actual bottle read records deadline")
	var due: float=q.state.mine_due
	m.advance();check(m.state.site.is_empty(),"read before day no mine")
	q.read(q.BOTTLE);check(q.state.mine_due==due,"reread cannot reset deadline")
	v.simulation.advance_calendar(3599)
	m.advance();check(m.state.site.is_empty(),"normal time rule full day minus one second")
	v.simulation.advance_calendar(2);m.last_attempt=-30000;m.advance()
	check(not m.state.site.is_empty(),"rocky area mine generated after full world day")
	if m.state.site.is_empty():finish();return
	check(w.generator.biome(m.at())=="岩石区" and m.safe(m.at()),"safe seeded rocky location")
	var snapshot: Dictionary=s.snapshot().duplicate(true)
	s.load_state("",false,JSON.parse_string(JSON.stringify(snapshot)));check(s.writable and m.state.site==snapshot.exploration_chapter.mine.site,"old chapter and current mine roundtrip")
	await move_to(m.at()+Vector2(0,115));await snap("01-sealed")
	var view=s.chapter_view.get_node("MineView")
	check(view.targets.has("entrance") and not view.barrier.get_child(0).disabled,"actual sealed collider and interaction")
	check(preload("res://scripts/world_interaction.gd").action_for(view.targets.entrance)=="inspect","ordinary mining cannot target seal")
	w.player.input_blocked=false;w.player.input_override=Vector2.UP;w.player.set_physics_process(true)
	await create_timer(.7).timeout;w.player.input_override=Vector2.ZERO;w.player.set_physics_process(false)
	check(w.player.position.y-m.at().y>=43 and w.player.position.y-m.at().y<90,"real actor walking stops at sealed collision")
	w.player._unhandled_input(key(KEY_F));s.combat.advance(.9)
	check(m.state.phase=="sealed","normal F attack cannot break special seal")
	await move_to(m.at()+Vector2(0,115))
	w.player.input_blocked=false;w.player.facing="back"
	w.player._unhandled_input(key(KEY_E))
	check(m.state.investigated,"native E input investigates actual seal")
	await move_to(m.record_at()+Vector2(0,65))
	check(m.interact("record").contains("矿工") and m.state.recipe,"record unlocks actual recipe")
	check(s.craft_book.available("全部","metal_workbench").any(func(r):return r.output_id=="miner_blast_pack"),"recipe listed in existing craft UI")
	s.chapter_view.show_page(m.interact("record"));await snap("02-record");s.chapter_view.close_page()
	
	for id in ["wood","stone","copper_ingot"]:s.inventory.add(id,80)
	var bench_id:=""
	for offset in [Vector2(384,192),Vector2(-384,192),Vector2(480,0),Vector2(-480,0)]:
		await move_to(m.at()+offset+Vector2(0,95))
		var row: Dictionary=b.candidate("metal_workbench",m.at()+offset,false,true,0)
		if not b.reason(row).is_empty():continue
		var ids: Array=b.states.keys()
		if not b.place(row,s.inventory.slots.duplicate(true)).is_empty():continue
		for id in b.states:
			if id not in ids:bench_id=id
		break
	check(not bench_id.is_empty(),"advanced station placed for discovered recipe")
	s.craft_station_id=bench_id
	check(not s.start_craft(m.config.recipe_id,1).is_empty(),"insufficient materials rejected")
	for id in m.config.materials:s.inventory.add(id,int(m.config.materials[id])*3)
	var material_slots: Array=s.inventory.slots.duplicate(true)
	for i in 40:s.inventory.slots[i]={"item_id":"wood","count":99}
	var mat_index:=8
	for id in m.config.materials:
		s.inventory.slots[mat_index]={"item_id":id,"count":99};mat_index+=1
	check(not s.start_craft(m.config.recipe_id,1).is_empty(),"full inventory rejects real recipe without deduction")
	s.inventory.slots.assign(material_slots)
	check(s.start_craft(m.config.recipe_id,1).is_empty(),"craft rollback attempt starts")
	var path_before: String=s.save_path;w.persistent_world=true;s.save_path="res://reports/mine-v1/missing/sub/items.json"
	s.advance_craft(1.6)
	check(m.count_pack()==0 and s.inventory.slots==material_slots,"craft disk failure restores every ingredient and no output")
	w.persistent_world=false;s.save_path=path_before
	check(s.start_craft(m.config.recipe_id,1).is_empty(),"real timed crafting starts")
	check(not s.start_craft(m.config.recipe_id,1).is_empty(),"duplicate craft start rejected")
	s.advance_craft(1.6);check(m.count_pack()==1,"real crafting awards inventory pack")
	check(not m.interact("place").is_empty() and m.count_pack()==1,"wrong distance no consumption")
	await move_to(m.at()+Vector2(0,115))
	var old_path: String=s.save_path;w.persistent_world=true;s.save_path="res://reports/mine-v1/missing/sub/items.json"
	check(m.interact("place").contains("保存失败") and m.count_pack()==1 and m.state.phase=="sealed","placement disk failure rolls back inventory and seal")
	w.persistent_world=false;s.save_path=old_path
	check(m.interact("place").is_empty() and m.count_pack()==0 and m.state.phase=="armed","actual placement consumes exactly one and persists fuse")
	await snap("03-armed")
	var armed: Dictionary=s.snapshot().duplicate(true)
	s.load_state("",false,armed);check(m.state.phase=="armed" and m.state.fuse_due==armed.exploration_chapter.mine.fuse_due,"armed restart retains finalization deadline")
	check(not m.interact("place").is_empty() and m.count_pack()==0,"repeated placement never charges again")
	m.advance(5.01)
	for wait_visual in 300:
		if view.barrier.get_child(0).disabled and not view.rubble.visible:break
		await process_frame
	await snap("04-open")
	check(m.state.phase=="open" and view.barrier.get_child(0).disabled and not view.rubble.visible,"persisted opening removes physical and visual seal")
	w.player.input_blocked=false;w.player.input_override=Vector2.UP;w.player.set_physics_process(true)
	await create_timer(.55).timeout;w.player.input_override=Vector2.ZERO;w.player.set_physics_process(false)
	check(w.player.position.y-m.at().y<35,"real actor crosses former seal after blast")
	await move_to(m.at()+Vector2(0,115))
	var serial_before: int=int(m.travel.serial);w.persistent_world=true;s.save_path="res://reports/mine-v1/missing/sub/items.json"
	check(m.interact("enter").contains("保存失败") and not m.travel.inside and int(m.travel.serial)==serial_before,"entry disk failure restores own region position and serial")
	w.persistent_world=false;s.save_path=old_path
	await wait_transition()
	w.player.input_blocked=false;w.player.facing="back";w.player._unhandled_input(key(KEY_E))
	await wait_transition()
	check(m.travel.inside and m.state.entered,"native E enters open mine with original actor")
	await frames(15);await snap("05-inside")
	check(w.generator.can_walk(w.player.position) and not w.generator.can_walk(m.origin()+Vector2(900,0)),"interior walkable area bounded")
	var inside: Dictionary=s.snapshot().duplicate(true);var position: Vector2=w.player.position
	s.load_state("",false,JSON.parse_string(JSON.stringify(inside)));check(s.writable and w.player.position==position and m.travel.inside,"interior personal position save and restore")
	await move_to(m.origin()+Vector2(0,340))
	check(m.interact("exit").is_empty() and not m.travel.inside and w.player.position.distance_to(m.at())<150,"actual exit returns to saved surface mine")
	await frames(12);await snap("06-return")
	check(m.interact("enter").is_empty() and m.travel.inside,"repeat entry open state retained")
	await wait_transition()
	var f:=FileAccess.open("res://reports/.tmp/mine-ready.json",FileAccess.WRITE);f.store_string(JSON.stringify(s.snapshot()));f.close()
	finish()
func finish() -> void:
	var failures:=checks.filter(func(c):return not c.pass).size()
	var f:=FileAccess.open(DEST+"window.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));f.close()
	print("MINE_CHECKS ",checks.size()," FAILURES ",failures)
	w.queue_free();await frames(3);quit(1 if failures else 0)
