extends SceneTree
var checks: Array=[]
var measurements: Array=[]
func _initialize() -> void:call_deferred('run')
func check(ok: bool,name: String) -> void:
	checks.append({'pass':ok,'name':name})
	if not ok:push_error(name)
func run() -> void:
	root.get_node('AudioFX').muted=true
	for cells in [1024,1536]:
		for seed_value in [81273,271828,902106]:
			var path:='res://reports/world-map-v3/distribution-%d-%d-save.json'%[cells,seed_value]
			if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
			Engine.set_meta('map_v3_seed',seed_value);Engine.set_meta('map_v3_cells',cells);Engine.set_meta('map_v3_save',path)
			var start:=Time.get_ticks_usec();var mem:=OS.get_static_memory_usage()
			var w=load('res://tests/world_map_v3_fixture.gd').new();root.add_child(w)
			while not w.started:await process_frame
			var startup_ms:=(Time.get_ticks_usec()-start)/1000.
			var service: Node=w.item_service
			w.environment_view.simulation.paused=true
			check(service.writable and w.generator.can_walk(w.player.position,20),'safe entry and save %d/%d'%[cells,seed_value])
			var sampled:={};var ordinary:=0;var ores:=0;var trees:=0;var nonempty:=0
			var types:={};var biome_counts:={}
			for attempt in 4000:
				if sampled.size()>=32:break
				var p: Vector2=Vector2(w.generator.random_at(attempt,0,320),w.generator.random_at(attempt,1,320))*w.generator.extent
				if w.generator.coast_distance(p)<800 or w.generator.sample(p).z>.02:continue
				var coord:=Vector2i(p/1152.)
				if sampled.has(coord):continue
				sampled[coord]=true
				var packet: Dictionary=service.chunk_distribution(coord)
				var harvest: Array=preload('res://scripts/harvest_distribution.gd').build(service,coord)
				var accepted: Array=packet.accepted
				if not accepted.is_empty() or not harvest.is_empty():nonempty+=1
				ordinary+=accepted.size();ores+=harvest.size()
				for row in accepted:types[row.item_id]=int(types.get(row.item_id,0))+1
				for row in w.generator.props_for_chunk(coord):
					if row.kind in [0,1]:trees+=1
				var biome: String=w.generator.biome(p);biome_counts[biome]=int(biome_counts.get(biome,0))+1
			check(sampled.size()==32 and nonempty>=24,'distributed resource-bearing land chunks %d/%d'%[cells,seed_value])
			check(ordinary>70 and ores>10 and trees>20,'basic resources remain abundant %d/%d'%[cells,seed_value])
			var camps:={}
			for id in service.builds.states:
				if id.begins_with('abandoned:'):camps[id.get_slice(':',2)]=true
			check(camps.size()<=(5 if cells>1024 else 3),'camp total %d/%d'%[cells,seed_value])
			check(service.fishing_population.spots.size()<=(28 if cells>1024 else 20),'fish total %d/%d'%[cells,seed_value])
			var merchant: Node=service.merchant
			check(is_instance_valid(merchant.actor) and merchant.safe_point(merchant.actor.position),'single reachable merchant %d/%d'%[cells,seed_value])
			var occupied_quadrants:={}
			for i in 24:
				var point: Vector2=merchant.choose_point()
				if point!=Vector2.INF:occupied_quadrants[Vector2i(point/(w.generator.extent*.5))]=true
			check(occupied_quadrants.size()>=2,'merchant samples distant world sectors %d/%d'%[cells,seed_value])
			var stats:={'cells':cells,'seed':seed_value,'startup_ms':startup_ms,'navigation_ms':service.navigation_ms,'static_memory_delta_mib':(OS.get_static_memory_usage()-mem)/1048576.,'sampled_chunks':sampled.size(),'nonempty_chunks':nonempty,'natural_resources':ordinary,'harvest_nodes':ores,'trees':trees,'resource_types':types,'biomes':biome_counts,'camps':camps.size(),'fish_schools':service.fishing_population.spots.size(),'merchant_sample_sectors':occupied_quadrants.size()}
			measurements.append(stats);print(JSON.stringify(stats))
			# Commit and read the same independent world in a new instance.
			service.exploration.reveal(w.player.position);check(service.save_state(),'save %d/%d'%[cells,seed_value])
			var text:=FileAccess.get_file_as_string(path)
			w.persistent_world=false;w.queue_free()
			for i in 6:await process_frame
			var again=load('res://tests/world_map_v3_fixture.gd').new();root.add_child(again)
			check(again.item_service.writable and again.map_cells==cells and again.world_seed==seed_value,'size/seed reload %d/%d'%[cells,seed_value])
			again.persistent_world=false;again.queue_free()
			for i in 6:await process_frame
	var failed:=checks.filter(func(c):return not c.pass).size()
	FileAccess.open('res://reports/world-map-v3/distribution.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failed':failed,'measurements':measurements},'  '))
	print('DISTRIBUTION ',checks.size(),' checks ',failed,' failures');quit(0 if failed==0 else 1)
