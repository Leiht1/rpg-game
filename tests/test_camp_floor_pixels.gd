extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var result: Array=[]
	for kind in ["wood_floor","stone_path"]:
		var view := SubViewport.new();view.size=Vector2i(384,256);view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.world_2d=World2D.new();root.add_child(view)
		var background := ColorRect.new();background.color=Color(0,1,0);background.size=Vector2(384,256);background.z_index=-2;view.add_child(background)
		var manager=preload("res://scripts/camp_buildings.gd").new()
		for y in 4:
			for x in 4:
				var id: String="tile:%d:%d"%[x,y];var at := Vector2(48+x*96,32+y*64)
				manager.states[id]=manager.candidate(kind,at,false,true,0)
				var tile=preload("res://scripts/camp_building.gd").new();tile.preview=true;tile.manager=manager;tile.building_id=id;tile.position=at;view.add_child(tile)
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		var screenshot := view.get_texture().get_image()
		var grass := 0
		for y in 256:
			for x in 384:
				var color := screenshot.get_pixel(x,y)
				if color.g>.95 and color.r<.05 and color.b<.05: grass+=1
		screenshot.save_png("res://reports/camp-build-fix-v1/after/tiles-"+kind+".png")
		result.append({"kind":kind,"rendered_pixels":384*256,"exposed_green_pixels":grass,"pass":grass==0})
		view.free();await process_frame
	FileAccess.open("res://reports/camp-build-fix-v1/after/floor-pixels.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("FLOOR PIXELS: ",JSON.stringify(result))
	quit(0 if result.all(func(v): return v.pass) else 1)

