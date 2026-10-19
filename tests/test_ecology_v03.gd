extends SceneTree
const Gen=preload("res://scripts/world_generator.gd")
var failures:Array[String]=[]
var checks:=0
var report:Dictionary={}
var w:Node2D
var p:WildPlayer
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func shot(label:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/ecology-v03-"+label+".png")
func ready_view()->void:
	w.stream.update_target(p.position)
	var deadline=Time.get_ticks_msec()+25000
	while not w.stream.viewport_ready(p.position,Vector2(1000,650)) and Time.get_ticks_msec()<deadline:await process_frame
	check(w.stream.viewport_ready(p.position,Vector2(1000,650)),"stream viewport ready")
func tick(n:int)->void:
	for i in n:
		p._physics_process(1.0/60)
		await physics_frame
func find_tree(id:String)->Node2D:
	for t in get_nodes_in_group("trees"):
		if t.get_meta("prop_id")==id:return t
	return null
func macro_tests()->void:
	for seed_value in [271828,81273,902106]:
		var gen=Gen.new(seed_value)
		var image=Image.create(384,384,false,Image.FORMAT_RGB8)
		var labels:PackedInt32Array=[]
		var counts=[0,0,0]
		for y in 192:
			for x in 192:
				var v=gen.sample((Vector2(x,y)+Vector2.ONE*.5)*gen.extent/192,false)
				var k=0 if v.x>=v.y and v.x>=v.w else (1 if v.y>=v.w else 2)
				labels.append(k);counts[k]+=1
		var components:Array[Dictionary]=[]
		var visited={}
		for index in labels.size():
			if visited.has(index):continue
			var k=labels[index];var queue=[index];visited[index]=true;var cursor=0
			while cursor<queue.size():
				var at:int=queue[cursor];cursor+=1
				for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var cell=Vector2i(at%192,at/192)+delta
					var next=cell.y*192+cell.x
					if cell.x<0 or cell.y<0 or cell.x>=192 or cell.y>=192 or visited.has(next) or labels[next]!=k:continue
					visited[next]=true;queue.append(next)
			components.append({"kind":k,"area_px2":queue.size()*256*256,"cells":queue.size()})
		for y in 384:
			for x in 384:
				var v=gen.sample((Vector2(x,y)+Vector2.ONE*.5)*gen.extent/384,false)
				var col=Color("adc979").lerp(Color("6d9c68"),v.x).lerp(Color("aaa58c"),v.y)
				if v.z>.35:col=Color("70afb9")
				image.set_pixel(x,y,col)
		image.save_png("res://reports/ecology-v03-seed-%d-overview.png"%seed_value)
		check(counts.min()>1500,"all three large macro biomes seed %d"%seed_value)
		var minimum=9999999999
		for entry in components:minimum=mini(minimum,entry.area_px2)
		check(minimum>=1280*720*2,"no tiny independent macro regions seed %d"%seed_value)
		var chunk=Vector2i(19,20);var a=gen.build_chunk(chunk);var b=gen.build_chunk(chunk+Vector2i.RIGHT);var c=gen.build_chunk(chunk+Vector2i.DOWN)
		var seam=true
		for i in Gen.TEX_RES+2:
			seam=seam and a.image.get_pixel(145,i)==b.image.get_pixel(1,i) and a.image.get_pixel(i,145)==c.image.get_pixel(i,1)
		check(seam,"exact shared chunk coordinates seed %d"%seed_value)
		check(a.image.get_data()==Gen.new(seed_value).build_chunk(chunk).image.get_data(),"seed reproducibility %d"%seed_value)
		report[str(seed_value)]={"counts":counts,"components":components,"smallest_area_px2":minimum,"overview_hash":str(hash(labels))}
func run()->void:
	macro_tests()
	w=load("res://scenes/world.tscn").instantiate();root.add_child(w)
	p=w.player;p.automated=true;p.set_physics_process(false)
	await ready_view()
	while not w.started or w.map_view.row<512:await process_frame
	# Nine positions, full map and enlarged map. Test extreme pan and both zoom limits.
	var extent=w.generator.extent
	for zoom in [1.0,4.0,16.0]:
		var index=0
		for y in [12.0,extent*.5,extent-12]:
			for x in [12.0,extent*.5,extent-12]:
				p.position=Vector2(x,y);w.map_view.open_map();w.map_view.zoom=zoom;w.map_view.clamp_center()
				var half=extent/(2*zoom);var center=w.map_view.center
				check(center.x>=half and center.y>=half and center.x<=extent-half and center.y<=extent-half,"map viewport inside world z%s position%d"%[zoom,index])
				if zoom==4:await shot("map-%d"%index)
				index+=1
	w.map_view.center=Vector2(-1e6,1e6);w.map_view.clamp_center()
	check(w.map_view.center==Vector2(extent/32,extent-extent/32),"pan clamps by viewport half extent")
	w.map_view.close_map();p.position=w.generator.spawn;await ready_view()
	# Each initial facing and relative tree direction. Reset only test state between cases.
	var t=find_tree("clearing:0")
	for pair in [["front",Vector2(0,44)],["back",Vector2(0,-44)],["left",Vector2(-44,0)],["right",Vector2(44,0)]]:
		p.position=t.position+pair[1];p.facing=pair[0];await physics_frame
		p.try_interact()
		check(p.action=="chop" and p.facing in ["left","right"],"all sides trigger "+pair[0])
		var start=p.position
		await tick(20);check(w.stream.tree_hits.get("clearing:0",0)==0,"no early damage "+pair[0])
		await tick(4);check(w.stream.tree_hits.get("clearing:0",0)==1,"one timed contact "+pair[0])
		await tick(60);check(p.action=="" and p.position==start,"tap once and no teleport "+pair[0])
		w.stream.tree_hits.erase("clearing:0")
	# Short taps and live chunk unload/reload retain hit count and existing drops.
	p.position=t.position-Vector2(44,0);await physics_frame
	var drops_before=w.stream.drops.size()
	p.try_interact();await tick(52)
	check(w.stream.tree_hits["clearing:0"]==1 and w.stream.drops.size()==drops_before,"large hit1 retains no drop")
	p.try_interact();await tick(52)
	check(w.stream.tree_hits["clearing:0"]==2 and w.stream.drops.size()==drops_before+1 and t.is_in_group("trees"),"large hit2 drops once retains tree")
	var coord=w.stream.chunk_at(t.position);var packet=w.generator.build_chunk(coord)
	var stamps:Array[Dictionary]=[];packet["ground_stamps"]=stamps
	w.stream.unload_chunk(coord);await process_frame;w.stream.install_chunk(packet);await physics_frame
	t=find_tree("clearing:0")
	check(t!=null and w.stream.tree_hits["clearing:0"]==2 and w.stream.drops.size()==drops_before+1,"reload retains hit2 and drop")
	p.position=t.position+Vector2(44,0);await physics_frame
	p.try_interact();await tick(52)
	check(w.stream.tree_hits["clearing:0"]==3 and w.stream.drops.size()==drops_before+1,"large hit3 no duplicate drop")
	p.try_interact();await tick(52)
	check(w.stream.tree_hits["clearing:0"]==4 and w.stream.drops.size()==drops_before+2 and not t.is_in_group("trees"),"large hit4 drops second and removes")
	check(not t.has_node("FootprintBody"),"final hit clears collision")
	w.stream.unload_chunk(coord);await process_frame;w.stream.install_chunk(packet);await physics_frame
	check(find_tree("clearing:0")==null and w.stream.drops.size()==drops_before+2,"reload harvested tree cannot farm")
	# Real held input, same target only, completed animation cadence.
	t=find_tree("clearing:1");p.position=t.position+Vector2(0,44);await physics_frame
	Input.action_press("interact");p.try_interact()
	await tick(20);check(w.stream.tree_hits.get("clearing:1",0)==0,"held small no early hit")
	await tick(4);check(w.stream.tree_hits["clearing:1"]==1,"held small hit1")
	await tick(24);check(w.stream.tree_hits["clearing:1"]==1,"full animation before repeat")
	await tick(50)
	check(w.stream.tree_hits["clearing:1"]==2 and w.stream.harvested.has("clearing:1"),"small second hit removes")
	var after=w.stream.drops.size();await tick(100)
	check(w.stream.drops.size()==after and p.action=="" and w.stream.collected_wood==0,"held felled tree stops no pickup or repeat")
	Input.action_release("interact")
	# Long-hold four hits on a large tree, and normal release/movement cancellation.
	t=find_tree("clearing:2");p.position=t.position-Vector2(44,0);await physics_frame
	Input.action_press("interact");p.try_interact();await tick(205)
	check(w.stream.tree_hits["clearing:2"]==4 and w.stream.harvested.has("clearing:2") and w.stream.drops.size()==after+2,"held large exactly four contacts two drops")
	Input.action_release("interact");await tick(5)
	t=find_tree("clearing:4");p.position=t.position-Vector2(44,0);await physics_frame
	Input.action_press("interact");p.try_interact();await tick(8);p.position+=Vector2(-100,0);await tick(70)
	check(p.action=="" and not w.stream.tree_hits.has("clearing:4"),"leaving reach cancels hold before damage")
	Input.action_release("interact")
	p.position=t.position-Vector2(44,0);await physics_frame
	Input.action_press("interact");p.try_interact();await tick(8);w.map_view.open_map();w.map_view.close_map();await tick(70)
	check(p.action=="" and not w.stream.tree_hits.has("clearing:4"),"map interrupts hold without restarting")
	Input.action_release("interact")
	var drop=w.stream.drops.back();p.position=drop.position+Vector2(20,0);await physics_frame
	p.try_interact();await tick(50)
	check(w.stream.collected_wood==1,"original explicit pickup remains functional")
	await shot("after-chopping")
	report["engine"]=Engine.get_version_info().string;report["generator"]=Gen.VERSION
	report["checks"]=checks;report["failures"]=failures
	FileAccess.open("res://reports/ecology-v03-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ECOLOGY_V03 ",checks," checks; failures ",failures)
	quit(0 if failures.is_empty() else 1)

