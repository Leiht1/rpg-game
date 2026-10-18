extends "res://tests/capture_world_v06.gd"
const Mask=preload("res://scripts/grounding_mask.gd")
var samples:Array=[]
func shot(label:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/grounding-integration/"+label+".png")
func packet_at(c:Vector2i)->Dictionary:
	var worker=load("res://scripts/world_generator.gd").new(w.world_seed,1024,w.generator.plan_snapshot())
	var packet:Dictionary=worker.build_chunk(c)
	var empty:Array[Dictionary]=[];packet["ground_stamps"]=empty
	packet["grounding_mask"]=Mask.build(worker,c,{})
	return packet
func run()->void:
	for seed_value in [447349832,1332185389]:
		Engine.set_meta("integration_seed",seed_value)
		w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
		w.player.automated=true;w.player.camera.position_smoothing_enabled=false
		await settle()
		check(w.stream.ART_VERSION=="scene-grounding-0.1.0","formal grounding version %d"%seed_value)
		check(w.generator.VERSION=="windrest-continent-0.6.0","map version retained %d"%seed_value)
		var path:PackedVector2Array=w.generator.connections[0]
		w.player.position=path[0]+(path[1]-path[0]).normalized()*2050.
		w.player.reset_physics_interpolation();w.player.camera.reset_smoothing();await settle()
		if seed_value==447349832:
			w.player.position=Vector2(20819.6640625,20888.078125)
			w.player.reset_physics_interpolation();w.player.camera.reset_smoothing();await settle()
		await shot("seed-%d-mixed"%seed_value)
		var node_count:=0;var trees:=0
		for chunk in w.stream.loaded.values():
			check(chunk.canopy.z_index==-1,"canopy is below actors %s %d"%[str(chunk.terrain.position),seed_value])
			for p in chunk.props:
				if p.kind>=4:continue
				node_count+=1
				if p.kind<2:trees+=1
				check(p.material==w.stream.prop_material and p.edge.size()>0,"shared live-ground material and base %s %d"%[p.name,seed_value])
		var c:Vector2i=w.stream.chunk_at(w.player.position)
		var before:=packet_at(c)
		var neighbour:=Mask.build(w.generator,c+Vector2i.RIGHT,{})
		var mask:Image=before.grounding_mask
		var seam_ok:=true
		for y in mask.get_height():
			for i in 6:
				if mask.get_pixel(144+i,y)!=neighbour.get_pixel(i,y):seam_ok=false
		check(seam_ok,"mask shared border exact bytes %d"%seed_value)
		w.stream.unload_chunk(c);await process_frame
		w.stream.install_chunk(before)
		var after:=packet_at(c)
		check(before.props==after.props and before.image.get_data()==after.image.get_data(),"same objects and terrain after unload reinstall %d"%seed_value)
		check(before.grounding_mask.get_data()==after.grounding_mask.get_data(),"same mask after unload reinstall %d"%seed_value)
		# Capture each biome's actual resource position; teleport only the test actor.
		for kind in 3:
			var core_index:int=w.generator.region_kinds.find(kind)
			w.player.position=w.generator.region_cores[core_index]
			w.player.reset_physics_interpolation();w.player.camera.offset=Vector2.ZERO;w.player.camera.reset_smoothing()
			await settle()
			var target:Node2D
			for group in ["trees","rocks"]:
				for p in get_nodes_in_group(group):
					var weights:Vector4=w.generator.sample(p.position)
					var dominant:=0 if weights.x>=maxf(weights.y,weights.w) else 1 if weights.y>=weights.w else 2
					if dominant==kind and p.position.distance_to(w.player.position)<900.:target=p;break
				if target!=null:break
			check(target!=null,"actual resource in biome %d seed %d"%[kind,seed_value])
			if target==null:continue
			w.player.position=target.position+Vector2(110,85)
			w.player.camera.offset=Vector2.ZERO
			w.player.camera.zoom=Vector2.ONE*1.65
			w.player.reset_physics_interpolation();w.player.camera.reset_smoothing()
			await settle()
			await shot("seed-%d-biome-%d"%[seed_value,kind])
			# Short normal walk with the formal streamer; no missing visible ground.
			w.player.camera.offset=Vector2.ZERO
			w.player.input_override=Vector2.RIGHT
			var gaps:=0
			for i in 30:
				await physics_frame
				if not w.stream.viewport_ready(w.player.position,Vector2(400,240)):gaps+=1
			w.player.input_override=Vector2.ZERO
			check(gaps==0,"moving view covered biome %d seed %d"%[kind,seed_value])
		samples.append({"seed":seed_value,"loaded_objects":node_count,"trees":trees,"canopy_nodes":w.stream.loaded.size(),"max_install_ms":w.stream.max_install_ms,"last_worker_build_ms":w.stream.last_build_ms})
		w.queue_free();await process_frame
	var failures:=0
	for item in checks:
		if not item.pass:failures+=1
	FileAccess.open("res://reports/grounding-integration/runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"checks":checks,"failures":failures,"samples":samples,"note":"Actual formal scene with shared GPU ground sampling, no CPU readback. Timing is chunk installation, not a GPU frame guarantee."},"  "))
	print("GROUNDING_CHECKS ",checks.size()," FAILURES ",failures)
	quit(1 if failures else 0)
