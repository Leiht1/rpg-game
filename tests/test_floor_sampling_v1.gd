extends SceneTree
const OUT="res://reports/planting-ui-floor-v2/"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var views=[];var roots=[]
	var raw: Texture2D=load("res://assets/buildings/v3/wood-top.png")
	var reference := raw.get_image();reference.resize(96,64,Image.INTERPOLATE_LANCZOS)
	for mode in 3:
		var view := SubViewport.new();view.size=Vector2i(384,256);view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view);views.append(view)
		var layer := Node2D.new();view.add_child(layer);roots.append(layer)
		var manager=preload("res://scripts/camp_buildings.gd").new()
		if mode==2:manager.textures["res://assets/buildings/v3/wood-top.png"]=ImageTexture.create_from_image(reference)
		for y in 5:
			for x in 5:
				var id: String="%d:%d"%[x,y];var at := Vector2(x*96,y*64)
				manager.states[id]=manager.candidate("wood_floor",at,false,true,0)
				var node=preload("res://scripts/camp_building.gd").new();node.manager=manager;node.building_id=id;node.preview=true;node.position=at;layer.add_child(node)
				if mode!=1:node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var results=[];var old_error:=0.0;var new_error:=0.0
	for step in 8:
		var offset:=Vector2((step%4)*.25,(step/4)*.5)
		for layer in roots:layer.position=offset
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var pictures=[]
		for view in views:pictures.append(view.get_texture().get_image())
		var errors=[0.0,0.0]
		for y in range(40,210):
			for x in range(60,330):
				for mode in 2:
					var a:Color=pictures[mode].get_pixel(x,y);var b:Color=pictures[2].get_pixel(x,y)
					errors[mode]+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
		old_error+=errors[0];new_error+=errors[1];results.append({"offset":str(offset),"old_error":errors[0],"mipmap_error":errors[1]})
		if step==3:
			pictures[0].save_png(OUT+"floor-old-sampling.png");pictures[1].save_png(OUT+"floor-mipmap.png")
	var passed:bool=new_error<old_error*.8
	FileAccess.open(OUT+"floor-sampling.json",FileAccess.WRITE).store_string(JSON.stringify({"reference":"same PNG resized once to actual 96x64 with Lanczos, rendered at same 8 subpixel offsets; RGB absolute error, not perceptual ghosting score","samples":results,"old_error":old_error,"mipmap_error":new_error,"ratio":new_error/old_error,"pass":passed},"  "))
	print("FLOOR SAMPLING ratio ",new_error/old_error," pass ",passed)
	for view in views:view.queue_free()
	await process_frame;quit(0 if passed else 1)
