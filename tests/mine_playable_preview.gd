extends SceneTree
## Disposable, playable mine chapter setup. Every launch starts fresh.
var w: Node
var ready:=false
var bench_id:=""
func _initialize() -> void:run.call_deferred()
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w);current_scene=w
	while not w.started:await process_frame
	var s=w.item_service;var q=s.chapter;var m=q.mine
	w.player.input_blocked=true;w.player.set_physics_process(false);s.guide_stage=2
	s.combat.state.boars.clear();s.combat.personal.phase="alive";s.combat.personal.attack={}
	s.body.health=100;s.body.energy=100;s.body.hunger=100
	var env=w.environment_view.simulation;env.day=5;env.minute=600;env.force_weather(0)
	q.state=q.initial()
	q.state.merge({"stage":5,"eligible_at":0.0,"site":{"x":w.generator.spawn.x+1400,"y":w.generator.spawn.y},"shore":{"x":w.generator.spawn.x+1300,"y":w.generator.spawn.y},"lake":0,"bottle_claimed":true,"bottle_read":true,"bottle_read_at":0.0,"mine_due":1440.0,"investigated_at":0.0,"elder_due":1000000000.0,"dialogue_at":0.0,"fishing_due":0.0,"fishing_open":true},true)
	m.place()
	if m.state.site.is_empty():push_error("试玩矿洞未找到安全地点");quit(1);return
	for i in 40:s.inventory.slots[i]={}
	for id in ["wood","stone","copper_ingot"]:s.inventory.add(id,80)
	var b=s.builds
	for offset in [Vector2(384,0),Vector2(-384,0),Vector2(480,0),Vector2(-480,0),Vector2(384,128),Vector2(-384,128)]:
		var point: Vector2=m.at()+offset
		if Rect2(point+Vector2(0,90)-Vector2(700,440),Vector2(1400,880)).has_point(m.record_at()):continue
		w.player.position=point+Vector2(0,95);w.stream.update_target(point)
		while not w.stream.viewport_ready(point,Vector2(640,360)):await process_frame
		var row: Dictionary=b.candidate("metal_workbench",point,false,true,0)
		if not b.reason(row).is_empty():continue
		var before_ids: Array=b.states.keys()
		if not b.place(row,s.inventory.slots.duplicate(true)).is_empty():continue
		for id in b.states:
			if id not in before_ids:bench_id=id
		if not bench_id.is_empty():break
	if bench_id.is_empty():push_error("试玩加工台未找到安全地点");quit(1);return
	for i in 40:s.inventory.slots[i]={}
	# Only ingredients, never a pre-crafted pack or an unlocked recipe.
	for id in m.config.materials:s.inventory.add(id,int(m.config.materials[id])*2)
	s.inventory.add(q.BOTTLE,1);s.inventory.changed.emit()
	m.sync_recipe();s.craft_station_id=""
	var bench: Dictionary=b.states[bench_id]
	w.player.position=Vector2(bench.x,bench.y)+Vector2(0,90)
	w.player.input_blocked=false;w.player.set_physics_process(true);w.player.reset_physics_interpolation();w.player.camera.reset_smoothing()
	w.stream.update_target(w.player.position)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	DisplayServer.window_set_title("风栖原野 · 矿洞探索独立试玩 · 重开重置")
	w.item_ui.message_time=0
	ready=true
	if "--smoke" in OS.get_cmdline_user_args():await smoke()
func smoke() -> void:
	var s=w.item_service;var m=s.chapter.mine
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/mine-v1/preview-start.png")
	assert(not w.persistent_world and w.environment_view.save_path.is_empty())
	assert(m.state.phase=="sealed" and not m.state.recipe and m.count_pack()==0)
	assert(m.at().distance_to(m.record_at())>=650)
	assert(not s.craft_book.available("全部","metal_workbench").any(func(r):return r.output_id=="miner_blast_pack"))
	for id in m.config.materials:assert(s.inventory.count_item(id)==int(m.config.materials[id])*2)
	w.player.facing="back";w.player.try_interact()
	assert(w.item_ui.craft_panel.visible and s.craft_station_id==bench_id)
	assert(not w.item_ui.craft_panel.recipe_buttons.has(m.config.recipe_id))
	w.item_ui.close_panels();w.item_ui.update_input_block()
	var at: Vector2=m.record_at()
	w.player.position=at+Vector2(0,60);w.stream.update_target(w.player.position)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	await create_timer(.2).timeout
	w.player.facing="back";w.player.try_interact()
	assert(m.state.recipe and s.chapter_view.panel.visible)
	s.chapter_view.close_page()
	assert(not s.craft_book.available().any(func(r):return r.output_id=="miner_blast_pack"))
	assert(s.craft_book.available("全部","metal_workbench").any(func(r):return r.output_id=="miner_blast_pack"))
	var bench: Dictionary=s.builds.states[bench_id]
	w.player.position=Vector2(bench.x,bench.y)+Vector2(0,85);w.stream.update_target(w.player.position)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	await create_timer(.2).timeout
	w.player.facing="back";w.player.try_interact()
	assert(w.item_ui.craft_panel.visible and s.craft_station_id==bench_id)
	assert(w.item_ui.craft_panel.recipe_buttons.has(m.config.recipe_id))
	w.item_ui.craft_panel.recipe_buttons[m.config.recipe_id].pressed.emit()
	w.item_ui.craft_panel.once.pressed.emit()
	await create_timer(1.8).timeout;assert(m.count_pack()==1)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/mine-v1/preview-craft.png")
	w.item_ui.close_panels();w.item_ui.update_input_block()
	w.player.position=m.at()+Vector2(0,115);w.stream.update_target(w.player.position)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	assert(m.interact("place").is_empty())
	await create_timer(5.2).timeout;m.advance()
	assert(m.state.phase=="open" and m.interact("enter").is_empty() and m.travel.inside)
	w.player.position=m.origin()+Vector2(0,340)
	assert(m.interact("exit").is_empty() and not m.travel.inside)
	print("MINE PREVIEW: isolated setup, distant record, discovered metal-workbench recipe, real craft/blast/entry/exit passed")
	w.queue_free();await process_frame;quit()
