extends SceneTree
const OUT := "res://reports/camp-refine-v5/"
var results: Array=[]
func _initialize(): call_deferred("run")
func run():
	for kind in ["wood_floor","stone_path"]:
		var view := SubViewport.new();view.size=Vector2i(448,320);view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
		var bg := ColorRect.new();bg.color=Color(0,1,0);bg.size=Vector2(448,320);bg.z_index=-2;view.add_child(bg)
		var manager=preload("res://scripts/camp_buildings.gd").new()
		for y in 4:
			for x in 4:
				var id: String="tile:%d:%d"%[x,y];var at := Vector2(48+x*96,32+y*64)
				manager.states[id]=manager.candidate(kind,at,false,true,0)
				var tile=preload("res://scripts/camp_building.gd").new();tile.preview=true;tile.manager=manager;tile.building_id=id;tile.position=at+Vector2(32,32);view.add_child(tile)
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		var image := view.get_texture().get_image();var green := 0
		for y in range(48,272):
			for x in range(56,392):
				var c := image.get_pixel(x,y)
				if c.g>.95 and c.r<.05 and c.b<.05: green+=1
		image.save_png(OUT+"whole-art-connected-"+kind+".png")
		results.append({"kind":kind,"interior_pixels":75264,"exposed_green":green,"pass":green==0})
		view.free();await process_frame
		# Compare one runtime tile against an untouched original Sprite with uniform scale.
		var actual := SubViewport.new();actual.size=Vector2i(192,160);actual.world_2d=World2D.new();actual.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(actual)
		var reference := SubViewport.new();reference.size=Vector2i(192,160);reference.world_2d=World2D.new();reference.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(reference)
		manager=preload("res://scripts/camp_buildings.gd").new();manager.states.one=manager.candidate(kind,Vector2.ZERO,false,true,0)
		var tile=preload("res://scripts/camp_building.gd").new();tile.preview=true;tile.manager=manager;tile.building_id="one";tile.position=Vector2(96,80);actual.add_child(tile)
		var sprite := Sprite2D.new();sprite.texture=load("res://assets/buildings/v1/frame-11.png" if kind=="wood_floor" else "res://assets/buildings/v1/frame-12.png");sprite.scale=Vector2.ONE*110.0/sprite.texture.get_width();sprite.position=Vector2(96,80);reference.add_child(sprite)
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		var a := actual.get_texture().get_image();var b := reference.get_texture().get_image();var different := 0
		for y in 160:
			for x in 192:
				var c := a.get_pixel(x,y);var d := b.get_pixel(x,y)
				if maxf(absf(c.r-d.r),maxf(absf(c.g-d.g),absf(c.b-d.b)))>3.1/255: different+=1
		a.save_png(OUT+"whole-art-single-"+kind+".png")
		results.append({"kind":kind,"original_sprite_comparison_pixels":30720,"pixels_over_tolerance":different,"pass":different==0})
		actual.free();reference.free();await process_frame
	var failed: Array=results.filter(func(v): return not v.pass)
	FileAccess.open(OUT+"whole-art-floor-tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":results,"failed":failed.size()},"  "))
	print("WHOLE ART FLOOR: %d checks, %d failed"%[results.size(),failed.size()])
	quit(0 if failed.is_empty() else 1)
