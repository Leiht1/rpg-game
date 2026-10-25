extends "res://tests/final_chapter_v1.gd"
func run() -> void:
	Engine.set_meta("integration_seed",271828);w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w);current_scene=w
	while not w.started:await process_frame
	s=w.item_service;w.set_process(false);s.set_process(false);w.environment_view.set_process(false);w.player.set_physics_process(false);w.player.automated=true;w.player.camera.position_smoothing_enabled=false
	s.load_state("",false,JSON.parse_string(FileAccess.get_file_as_string("res://reports/final-chapter-v1/ready.json")))
	s.body.health=100;s.body.energy=100;s.combat.personal.phase="alive";s.combat.personal.attack={};s.guide_stage=2
	var f=s.chapter.finale;var builds=s.builds
	f.state.dock_unlocked=false;f.sync_recipe()
	check(builds.reason(builds.candidate("dock",w.player.position,false,true,0)).contains("尚未掌握"),"direct placement cannot bypass blueprint unlock")
	f.state.dock_unlocked=true;f.sync_recipe()
	for i in 40:s.inventory.slots[i]={}
	for id in f.config.dock_cost:s.inventory.add(id,int(f.config.dock_cost[id]))
	var chosen: Dictionary={}
	for bank in s.fishing_population.candidates:
		if bank.lake!=-1:continue
		var inward: Vector2=(bank.stand-bank.water).normalized()
		for distance in [100,150,190]:
			var at: Vector2=bank.stand+inward*distance
			if w.generator.coast_distance(at)<35 or w.generator.coast_distance(at)>220:continue
			w.player.position=at+Vector2(0,90);w.stream.update_target(w.player.position)
			for i in 180:
				if w.stream.viewport_ready(w.player.position,Vector2(640,360)):break
				await process_frame
			await frames(3);var row: Dictionary=builds.candidate("dock",at,false,true,0)
			if builds.reason(row).is_empty():chosen=row;break
		if not chosen.is_empty():break
	check(not chosen.is_empty(),"actual safe coastal dock placement exists")
	if not chosen.is_empty():
		var result: String=builds.place(chosen,s.inventory.slots.duplicate(true))
		check(result.is_empty(),"dock genuinely built through original construction transaction")
		check(builds.states.values().filter(func(row):return row.kind=="dock").size()==1,"one real dock facility created")
		for id in builds.visuals:
			if builds.states.get(id,{}).get("kind","")=="dock":check(preload("res://scripts/world_interaction.gd").action_for(builds.visuals[id]).is_empty(),"idle dock has no nonfunctional interaction prompt")
		for id in f.config.dock_cost:check(s.inventory.count_item(id)==0,"configured construction cost deducted: "+str(id))
		await create_timer(.4).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/final-chapter-v2/dock.png")
		var saved: Dictionary=JSON.parse_string(JSON.stringify(s.snapshot()));s.load_state("",false,saved);check(s.writable and s.builds.states.values().any(func(row):return row.kind=="dock"),"built dock survives JSON restore")
	var failed: int=checks.filter(func(c):return not c.pass).size();FileAccess.open("res://reports/final-chapter-v1/dock.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "));print("DOCK ",checks.size()," checks ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(1 if failed else 0)
