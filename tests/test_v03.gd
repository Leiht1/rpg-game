extends SceneTree
var failures:Array[String]=[]
var checks:=0
var w:Node2D
var p:WildPlayer
var frame_index:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func tick(n:int,capture:bool=false)->void:
	for i in n:
		p._physics_process(1.0/60)
		await physics_frame
		if capture and i%2==0:
			await RenderingServer.frame_post_draw
			var picture:=root.get_texture().get_image()
			picture.resize(960,540,Image.INTERPOLATE_LANCZOS)
			picture.save_png("res://reports/v03-frames/%03d.png"%frame_index)
			frame_index+=1
func key(code:Key)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event)
	await process_frame
func run()->void:
	w=load("res://scenes/world.tscn").instantiate();root.add_child(w)
	p=w.player;p.automated=true;p.set_physics_process(false)
	while not w.started:await process_frame
	while w.map_view.row<512:await process_frame
	var origin:=p.position
	await key(KEY_M)
	check(w.map_view.visible and p.input_blocked,"M opens map and blocks gameplay")
	p.input_override=Vector2.RIGHT
	p.try_interact();await tick(10)
	check(p.position==origin and p.action=="","Map blocks movement and interaction")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/v03-map.png")
	var ev:=InputEventMouseButton.new();ev.button_index=MOUSE_BUTTON_WHEEL_UP;ev.pressed=true;ev.position=w.map_view.map_rect.get_center()
	w.map_view._input(ev)
	check(w.map_view.zoom>1,"Map wheel zoom")
	w.map_view.dragging=true
	var motion:=InputEventMouseMotion.new();motion.relative=Vector2(40,20)
	w.map_view._input(motion)
	check(w.map_view.center!=origin,"Map drag pans")
	await key(KEY_ESCAPE)
	check(not w.map_view.visible and not p.input_blocked,"Esc closes map")
	await key(KEY_M)
	check(w.map_view.center==p.position,"Reopen centers on player")
	await key(KEY_M)
	check(not w.map_view.visible,"M closes map")
	p.input_override=Vector2.ZERO
	var gen:=WildGenerator.new(w.world_seed,w.map_cells)
	var coord:Vector2i=w.stream.chunk_at(origin)
	var a:=gen.build_chunk(coord)
	var b:Dictionary=w.generator.build_chunk(coord)
	check(a.image.get_data()==b.image.get_data(),"Seed ground pixels reproduce")
	var neighbor:=gen.build_chunk(coord+Vector2i.RIGHT)
	var seam_ok:=true
	for y in 146:
		if a.image.get_pixel(145,y)!=neighbor.image.get_pixel(1,y):seam_ok=false
	check(seam_ok,"Shared chunk border samples identical")
	for xy in [Vector2i(80,160),Vector2i(250,350),Vector2i(380,220)]:
		var v:=gen.sample((Vector2(xy)+Vector2.ONE*.5)/512*gen.extent)
		var expected:=Color("adc979").lerp(Color("6d9c68"),smoothstep(.25,.75,v.x))
		expected=expected.lerp(Color("aaa58c"),smoothstep(.25,.75,v.y))
		if v.z>.35:expected=Color("70afb9")
		check(absf(w.map_view.image.get_pixelv(xy).r-expected.r)<.005 and absf(w.map_view.image.get_pixelv(xy).g-expected.g)<.005 and absf(w.map_view.image.get_pixelv(xy).b-expected.b)<.005,"Overview uses live terrain %s"%xy)
	var ground=w.stream.loaded[coord].ground
	var replica=load("res://scripts/ground_decals.gd").new()
	replica.configure(coord,ground.atlas,load("res://scripts/ground_decals.gd").plan(gen,coord,gen.props_for_chunk(coord)))
	check(ground.stamps==replica.stamps,"Ground decal placement reproduces by seed")
	check(not ground.stamps.is_empty(),"Finished ground decals installed")
	replica.free()
	var source_clip:=p.animation_player.get_animation("side_chop")
	var link_clip:=p.animation_player.get_animation("side_chop_link")
	var joins:=true
	for track in source_clip.get_track_count():
		var left=source_clip.value_track_interpolate(track,.64)
		var right=link_clip.value_track_interpolate(track,0)
		if left is Vector2:
			if left.distance_to(right)>.0001:joins=false;print("JOIN ",track," ",left," ",right)
		elif left is float:
			if absf(left-right)>.0001:joins=false;print("JOIN ",track," ",left," ",right)
		elif left!=right:joins=false;print("JOIN ",track," ",left," ",right)
	check(joins,"All native tracks join exact recovery pose including axe grip")
	var tree:Node2D
	for node in get_nodes_in_group("trees"):
		if node.get_meta("prop_id")=="clearing:0":tree=node
	p.position=tree.position-Vector2(44,0);p.camera.reset_smoothing()
	await physics_frame
	p.try_interact()
	await tick(20,true)
	check(w.stream.tree_hits.get("clearing:0",0)==0,"No hit before axe contact")
	await tick(4,true)
	check(w.stream.tree_hits.get("clearing:0",0)==1,"Contact commits one hit")
	p.try_interact()
	await tick(16,true)
	check(p.chained_chop and p.action_clock<.05,"Buffered second chop joins recovery")
	check(w.stream.tree_hits.get("clearing:0",0)==1,"Link cannot duplicate first hit")
	await tick(48,true)
	check(w.stream.tree_hits.get("clearing:0",0)==2 and w.stream.harvested.has("clearing:0"),"Exactly two hits fell tree")
	check(p.action=="","Chained action completes")
	var drop:Node2D=w.stream.drops.back()
	p.position=drop.position+Vector2(-18,12);p.camera.reset_smoothing();await physics_frame
	p.try_interact()
	await tick(20,true)
	check(w.stream.collected_wood==0,"Wood remains until hand contact")
	await tick(4,true)
	check(w.stream.collected_wood==1 and p.carried_wood.visible,"Wood transfers to hand at contact")
	var clock:=p.action_clock
	w.map_view.open_map();await tick(8)
	check(p.action_clock==clock,"Map freezes in-progress action")
	w.map_view.close_map();await tick(24,true)
	check(w.stream.collected_wood==1 and p.action=="","Pickup ends within .8 seconds exactly once")
	var report={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"generator":WildGenerator.VERSION,"chop_seconds":.82,"linked_chop_seconds":.80,"pickup_seconds":.72,"frames":frame_index}
	var file:=FileAccess.open("res://reports/v03-tests.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("V03 ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)

