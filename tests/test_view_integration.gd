extends SceneTree
var checks:Array=[]
var w:Node2D
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func settle()->void:
	w.stream.update_target(w.player.position+w.player.camera.position)
	var end=Time.get_ticks_msec()+30000
	while not w.stream.viewport_ready(w.player.position+w.player.camera.position,Vector2(720,430)) and Time.get_ticks_msec()<end:await process_frame
	check(w.stream.viewport_ready(w.player.position+w.player.camera.position,Vector2(720,430)),"viewport ready")
	for i in 8:await process_frame
func shot(label:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/view-integration/"+label+".png")
func run()->void:
	Engine.set_meta("world_v04_seed",271828)
	w=load("res://tests/world_v04_fixture.gd").new();root.add_child(w)
	w.player.automated=true;w.player.camera.position_smoothing_enabled=false
	await settle()
	while not w.started:await process_frame
	check(w.generator.VERSION=="windrest-biome-0.4.0" and w.generator.lakes.size()==78,"V0.4 layout and reduced lakes retained")
	check(w.stream.ART_VERSION=="scene-view-0.2.0","approved art version")
	for i in 4:
		check(w.stream.textures[i].resource_path=="res://assets/environment/view_v01/"+w.stream.FILES[i]+".png","formal prop reference %d"%i)
	check(w.stream.shared_material.shader.resource_path=="res://scripts/terrain.gdshader","formal lake shader")
	await shot("spawn")
	var start:Vector2=w.player.position
	w.player.input_override=Vector2.RIGHT
	for i in 30:await physics_frame
	w.player.input_override=Vector2.ZERO
	check(w.player.position.distance_to(start)>70 and w.generator.can_walk(w.player.position,20),"natural spawn actual movement and terrain collision")
	for kind in [0,1]:
		w.player.position=w.generator.region_cores[kind];w.player.camera.position=Vector2.ZERO;w.player.camera.reset_smoothing();await settle();await shot("forest" if kind==0 else "rocks")
	var found=false
	for lake in w.generator.lakes:
		if lake.z>420 or lake.w>300:continue
		var center=Vector2(lake.x,lake.y)
		for i in 3:center=Vector2(lake.x,lake.y)-Vector2(w.generator.warp.get_noise_2d(center.x,center.y),w.generator.warp.get_noise_2d(center.y+1200,center.x))*240
		var point=center-Vector2(lake.z*1.6,0)
		while not w.generator.can_walk(point,30):point.x-=20
		w.player.position=point;w.player.camera.position=center-point;w.player.camera.reset_smoothing();await settle();await shot("lake");found=true;break
	check(found,"complete irregular lake live capture")
	w.queue_free();await process_frame
	var failed=0
	for row in checks:
		if not row.pass:failed+=1
	FileAccess.open("res://reports/view-integration/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failures":failed},"  "))
	print("VIEW_INTEGRATION ",checks.size()," checks; failures=",failed);quit(1 if failed else 0)
