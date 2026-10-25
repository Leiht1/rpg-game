extends "res://tests/season_features_preview.gd"
const OUT="res://reports/season-snow-density-v2/"
func run() -> void:
	await super.run()
	world.set_process(false);world.item_service.set_process(false)
	world.environment_view.set_process(false);world.player.set_physics_process(false)
	world.player.camera.position_smoothing_enabled=false
	world.environment_view.simulation.snow=.85
	var visual=world.get_node("SeasonFlecks")
	var config: Dictionary=preload("res://scripts/season_rules.gd").data.features.ground_snow
	var records: Array=[]
	var sites: Dictionary={"camp":world.generator.spawn}
	for yy in range(4,95,3):
		for xx in range(4,95,3):
			var at: Vector2=Vector2(xx,yy)*world.generator.extent/100
			var biome: String=world.generator.biome(at)
			if biome in ["草原","森林","泥地","岩石区"] and not sites.has(biome) and world.generator.can_walk(at,30):sites[biome]=at
	for name in sites:
		world.player.position=sites[name];world.stream.update_target(world.player.position)
		while not world.stream.viewport_ready(world.player.position,Vector2(640,360)):await process_frame
		for value in [.77,.745]:
			config.threshold=value;visual.update_clock=0;visual._process(0)
			world.environment_view._process(0)
			await create_timer(.3).timeout;await RenderingServer.frame_post_draw
			var label: String="camp" if name=="camp" else str(["草原","森林","泥地","岩石区"].find(name))
			root.get_texture().get_image().save_png(OUT+label+("-before" if value==.77 else "-after")+".png")
			records.append({"site":name,"threshold":value,"snow":.85})
	config.threshold=.745
	FileAccess.open(OUT+"results.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	print("SNOW_DENSITY_V2: ",sites.size()," scenes, before/after pairs")
	world.queue_free();await process_frame;quit()
