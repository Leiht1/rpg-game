extends SceneTree
var w:Node2D
var samples:Array=[]
var checks:Array=[]
func _initialize()->void:call_deferred("run")
func run()->void:
	Engine.max_fps=120
	var zoom_value:=1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fps="):Engine.max_fps=int(arg.get_slice("=",1))
		if arg.begins_with("--zoom="):zoom_value=float(arg.get_slice("=",1))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	w.player.automated=true
	w.player.camera.zoom=Vector2.ONE*zoom_value
	var path:PackedVector2Array=w.generator.connections[0]
	var direction:Vector2=(path[1]-path[0]).normalized()
	w.player.position=path[0]+direction*250.
	w.player.reset_physics_interpolation();w.player.camera.reset_smoothing()
	w.stream.update_target(w.player.position)
	var deadline:=Time.get_ticks_msec()+30000
	while (not w.started or not w.stream.viewport_ready(w.player.position,Vector2(750,450)) or not w.stream.tasks.is_empty() or not w.stream.requested.is_empty()) and Time.get_ticks_msec()<deadline:await process_frame
	var marker:=Polygon2D.new()
	marker.polygon=PackedVector2Array([Vector2(-3,-3),Vector2(3,-3),Vector2(3,3),Vector2(-3,3)])
	marker.color=Color(1,0,1);marker.z_index=100
	w.player.add_child(marker)
	var began:=Time.get_ticks_msec()
	for speed in [false,true]:
		w.player.run_override=speed
		w.player.input_override=direction
		var end:=Time.get_ticks_msec()+1800
		while Time.get_ticks_msec()<end:
			await RenderingServer.frame_post_draw
			if Time.get_ticks_msec()<end-850:continue
			var image:Image=root.get_texture().get_image()
			var sx:=0.;var sy:=0.;var count:=0
			for y in range(260,470):
				for x in range(520,790):
					var color:=image.get_pixel(x,y)
					if color.r>.9 and color.g<.1 and color.b>.9:sx+=x;sy+=y;count+=1
			samples.append({"run":speed,"time":Time.get_ticks_usec(),"screen_x":sx/maxi(1,count),"screen_y":sy/maxi(1,count),"pixels":count,"loading":w.player.blocked_by_loading,"position":str(w.player.position)})
	w.player.input_override=Vector2.ZERO
	marker.queue_free()
	await RenderingServer.frame_post_draw
	var label:="baseline"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):label=arg.get_slice("=",1)
	root.get_texture().get_image().save_png("res://reports/movement-jitter/%s.png"%label)
	FileAccess.open("res://reports/movement-jitter/%s.json"%label,FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"interpolation":ProjectSettings.get_setting("physics/common/physics_interpolation",false),"camera_callback":w.player.camera.process_callback,"camera_smoothing":w.player.camera.position_smoothing_enabled,"samples":samples,"render_fps_cap":Engine.max_fps,"zoom":zoom_value,"seconds":(Time.get_ticks_msec()-began)/1000.},"  "))
	w.queue_free();await process_frame;quit()
