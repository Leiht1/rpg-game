extends SceneTree
const Layout=preload("res://prototypes/biome-v02/layout.gd")
func _initialize()->void:call_deferred("run")
func connectivity(layout)->Dictionary:
	var cells=Vector2i(96,64);var dry={};var seen={};var queue:Array[Vector2i]=[]
	for y in cells.y:
		for x in cells.x:
			var c=Vector2i(x,y)
			if layout.can_walk(Vector2(c)*64+Vector2(32,32)):dry[c]=true
	var start=Vector2i(layout.spawn/64);queue.append(start);seen[start]=true
	var head=0
	while head<queue.size():
		var c=queue[head];head+=1
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next=c+offset
			if dry.has(next) and not seen.has(next):seen[next]=true;queue.append(next)
	return {"dry_cells":dry.size(),"reachable":seen.size(),"fraction":float(seen.size())/dry.size()}
func run()->void:
	var scene=load("res://prototypes/biome-v02/preview.tscn").instantiate();root.add_child(scene)
	var reports=[]
	for seed_value in [271828,81273,902106]:
		scene.regenerate(seed_value,false)
		var a=scene.layout;var b=Layout.new(seed_value)
		var image=a.field();var repeated=b.field()
		var counts=[0,0,0,0]
		for y in image.get_height():
			for x in image.get_width():
				var w=image.get_pixel(x,y);var k=0 if w.r>w.g and w.r>w.b else (1 if w.g>w.b else 2)
				if w.a>.56:k=3
				counts[k]+=1
		var max_jump=0.0
		for x in range(512,6144,512):
			for y in range(0,4096,32):
				var l=a.weights(Vector2(x-.01,y));var r=a.weights(Vector2(x+.01,y))
				max_jump=maxf(max_jump,absf(l.r-r.r)+absf(l.g-r.g)+absf(l.a-r.a))
		var report={"seed":seed_value,"field_sha256":image.get_data().hex_encode().sha256_text(),"repeatable":image.get_data()==repeated.get_data(),"objects_repeatable":a.objects()==b.objects(),"coverage_samples":counts,"connectivity":connectivity(a),"boundary_weight_jump":max_jump,"props":a.objects().size()}
		reports.append(report)
		for index in [-1,0,1,2,3,4,5,6,-2]:
			scene.focus(index)
			for frame in 3:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://prototypes/biome-v02/seed-%s-view-%s.png"%[seed_value,index])
		scene.focus(-2);scene.player.automated=true;scene.player.input_override=Vector2.RIGHT
		var before=scene.player.position
		for frame in 60:await physics_frame
		report["walk_distance"]=scene.player.position.distance_to(before)
		report["animation"]=scene.player.animation_player.current_animation
		scene.player.automated=false
	FileAccess.open("res://prototypes/biome-v02/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"version":Layout.VERSION,"seeds":reports},"  "))
	print(JSON.stringify(reports));quit()
