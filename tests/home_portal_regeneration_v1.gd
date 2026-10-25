extends SceneTree
var checks: Array=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(int(ProjectSettings.get_setting("display/window/size/window_width_override")),int(ProjectSettings.get_setting("display/window/size/window_height_override")))
	for iteration in 3:
		Engine.set_meta("integration_seed",271828+iteration*100)
		var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
		while not w.started:await process_frame
		w.item_service.combat.personal.phase="alive"
		while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
		await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		var portal: Node2D=w.item_service.combat_view.portal
		var viewport_image:=root.get_texture().get_image()
		var at: Vector2=root.get_canvas_transform()*portal.position
		var bounds:=Rect2i(Vector2i(at+Vector2(-100,-240)),Vector2i(200,250)).intersection(Rect2i(Vector2i.ZERO,root.size))
		var tan_pixels:=0
		for y in range(bounds.position.y,bounds.end.y):
			for x in range(bounds.position.x,bounds.end.x):
				var c:=viewport_image.get_pixel(x,y)
				if c.r>c.g+.025 and c.g>c.b+.08 and c.r>.35:tan_pixels+=1
		var ok:=tan_pixels>500
		checks.append({"world":iteration,"pass":ok,"visible_frame_pixels":tan_pixels})
		if not ok:push_error("portal frame absent after world regeneration "+str(iteration))
		viewport_image.save_png("res://reports/home-local-v1/regenerated-world-%d.png"%iteration)
		w.queue_free();await process_frame;await process_frame
	FileAccess.open("res://reports/home-local-v1/regeneration.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	var failed:=checks.filter(func(x):return not x.pass).size()
	print("WORLD_REGEN ",checks.size()," FAILED ",failed)
	quit(1 if failed else 0)
