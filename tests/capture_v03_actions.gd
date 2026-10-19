extends SceneTree
var index:=0
func _initialize()->void:call_deferred("run")
func record(p:WildPlayer,n:int)->void:
	for i in n:
		p._physics_process(1.0/60)
		await physics_frame
		if i%2==0:
			await RenderingServer.frame_post_draw
			var picture:=root.get_texture().get_image()
			picture.resize(960,540,Image.INTERPOLATE_LANCZOS)
			picture.save_png("res://reports/v03-frames/%03d.png"%index);index+=1
func run()->void:
	var w=load("res://scenes/world.tscn").instantiate();root.add_child(w)
	var p:WildPlayer=w.player;p.automated=true;p.set_physics_process(false)
	while not w.started:await process_frame
	var tree:Node2D
	for node in get_nodes_in_group("trees"):
		if node.get_meta("prop_id")=="clearing:0":tree=node
	p.position=tree.position-Vector2(44,0);p.camera.reset_smoothing();await physics_frame
	p.try_interact();await record(p,24)
	p.try_interact();await record(p,64)
	var drop:Node2D=w.stream.drops.back()
	p.position=drop.position+Vector2(-18,12);p.camera.reset_smoothing();await physics_frame
	p.try_interact();await record(p,48)
	print("ACTUAL RUNTIME FRAMES ",index);quit()
