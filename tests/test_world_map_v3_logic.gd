extends SceneTree
const Gen=preload('res://scripts/world_generator.gd')
const Old=preload('res://prototypes/world-map-v3/baseline_generator.gd')
const Explore=preload('res://scripts/world_exploration.gd')
var checks: Array=[]
var measurements: Array=[]
func _initialize() -> void:call_deferred('run')
func check(ok: bool, name: String) -> void:
	checks.append({'pass':ok,'name':name})
	if not ok:push_error(name)
func run() -> void:
	for seed_value in [81273,271828,902106]:
		var start:=Time.get_ticks_usec();var old=Old.new(seed_value,1024)
		var old_ms:=(Time.get_ticks_usec()-start)/1000.
		start=Time.get_ticks_usec();var current=Gen.new(seed_value,1024)
		var same:=true
		for y in 100:
			for x in 100:
				var p: Vector2=Vector2(x+.5,y+.5)/100.*old.extent
				if old.sample(p)!=current.sample(p) or old.coast_distance(p)!=current.coast_distance(p):same=false
		check(same and old.lakes==current.lakes and old.spawn==current.spawn,'old topology/water/ecology unchanged seed %d'%seed_value)
		var coord:=Vector2i(old.spawn/1152.)
		check(old.props_for_chunk(coord)==current.props_for_chunk(coord),'old props unchanged %d'%seed_value)
		start=Time.get_ticks_usec();var gen=Gen.new(seed_value,1536)
		var generation_ms:=(Time.get_ticks_usec()-start)/1000.
		check(gen.map_cells==1536 and gen.extent==73728,'1536 extent %d'%seed_value)
		check(gen.rooms.size()>=18 and gen.rooms.size()<=24,'continuous room count %d'%seed_value)
		var worker=Gen.new(seed_value,1536,gen.plan_snapshot())
		var counts:={};var coast_cells:=0;var land_cells:=0;var mismatch:=0
		for y in 160:
			for x in 160:
				var p: Vector2=Vector2(x+.5,y+.5)/160.*gen.extent
				var biome: String=gen.biome(p);counts[biome]=int(counts.get(biome,0))+1
				if gen.sample(p)!=worker.sample(p):mismatch+=1
				if gen.coast_distance(p)>0:land_cells+=1
				if absf(gen.coast_distance(p))<400:coast_cells+=1
		check(mismatch==0,'worker same world %d'%seed_value)
		check(counts.get('草原',0)>100 and counts.get('森林',0)>100 and counts.get('岩石区',0)>50,'large continuous ecologies %d'%seed_value)
		check(gen.sample(gen.spawn).z<.03 and gen.coast_distance(gen.spawn)>0,'generator spawn dry %d'%seed_value)
		var pop=preload('res://scripts/fishing_population.gd').new();start=Time.get_ticks_usec();pop.configure(gen)
		var fishing_ms:=(Time.get_ticks_usec()-start)/1000.
		check(pop.max_schools==56 and pop.spots.size()<=56 and pop.valid(pop.serialize()),'bounded fish populations %d'%seed_value)
		var data:={'seed':seed_value,'old_generation_ms':old_ms,'new_generation_ms':generation_ms,'rooms':gen.rooms.size(),'lakes':gen.lakes.size(),'rivers':gen.rivers.size(),'sampled_land_fraction':land_cells/25600.,'biome_samples':counts,'fish':pop.spots.size(),'fish_candidates':pop.candidates.size(),'fish_build_ms':fishing_ms,'static_memory_mib':OS.get_static_memory_usage()/1048576.}
		measurements.append(data);print(JSON.stringify(data))
	var a=Explore.new();a.configure('world-a',73728)
	var b=Explore.new();b.configure('world-a',73728)
	check(a.bits.size()==73728,'bounded 1536 bitset 72KiB')
	check(a.reveal(Vector2(10000,10000)) and a.explored(Vector2(10000,10000)),'spawn revealed')
	check(not a.explored(Vector2(60000,60000)),'unknown remains concealed')
	var first: Dictionary=a.serialize();var revision: int=a.revision
	check(not a.reveal(Vector2(10000,10000)) and a.revision==revision,'stationary explorer no growth')
	b.reveal(Vector2(60000,60000));var second: Dictionary=b.serialize()
	check(a.merge_local(second) and a.explored(Vector2(10000,10000)) and a.explored(Vector2(60000,60000)),'world shared union')
	var united: Dictionary=a.serialize();a.merge_local(second)
	check(a.serialize()==united,'union idempotent')
	check(not a.explored(Vector2(35000,35000)),'teleport reveals no intervening corridor')
	b.restore(united);check(b.serialize()==united,'exact exploration roundtrip')
	var bad: Dictionary=first.duplicate(true);bad.world_id='other'
	check(not a.merge_local(bad) and a.serialize()==united,'cross-world merge rejected')
	bad=first.duplicate(true);bad.bits=bad.bits.left(12)
	check(not a.restore(bad) and a.serialize()==united,'truncated bitset preserves memory')
	bad=first.duplicate(true);bad.sha256='broken'
	check(not a.valid(bad),'checksum corruption rejected')
	var failed:=checks.filter(func(c):return not c.pass).size()
	FileAccess.open('res://reports/world-map-v3/logic.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failed':failed,'measurements':measurements},'  '))
	print('MAP V3 LOGIC ',checks.size(),' checks ',failed,' failed');quit(0 if failed==0 else 1)
