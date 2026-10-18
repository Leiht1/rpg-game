extends SceneTree
const Gen = preload("res://scripts/world_generator.gd")
const Distribution = preload("res://scripts/harvest_distribution.gd")
const Service = preload("res://scripts/item_service.gd")
var checks: Array=[]
var counts := {}
var chunks: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func run() -> void:
	var cfg: Dictionary=preload("res://scripts/harvest_node.gd").configuration()
	check(cfg.version==Service.HARVEST_VERSION and Gen.PROP_VERSION=="windrest-props-0.7.1","explicit mineral and scenery policy versions")
	var mud := {};var other := {};var gen := Gen.new(271828,1024)
	for y in 100:
		for x in 100:
			for attempt in 2:
				var kind := Distribution.mineral_kind(cfg,gen,Vector2i(x,y),attempt,true)
				if not kind.is_empty():mud[kind]=int(mud.get(kind,0))+1
				kind=Distribution.mineral_kind(cfg,gen,Vector2i(x,y),attempt,false)
				if not kind.is_empty():other[kind]=int(other.get(kind,0))+1
	check(mud.stone_outcrop>mud.flint_outcrop and mud.flint_outcrop>mud.copper_outcrop and mud.copper_outcrop>mud.silver_outcrop and mud.silver_outcrop>mud.gold_outcrop,"mud candidates stone > flint > copper > silver > gold")
	check(other.size()==2 and other.has("stone_outcrop") and other.has("flint_outcrop"),"outside mud only sparse stone/flint candidates")
	check(mud.stone_outcrop>other.stone_outcrop*3 and mud.flint_outcrop>other.flint_outcrop*3,"both common ores much denser on mud")
	for seed_value in [271828,447349832]:
		gen=Gen.new(seed_value,1024)
		var layer := Service.new();layer.world={"generator":gen,"Gen":Gen}
		layer.patch_noise.seed=seed_value^87361;layer.patch_noise.frequency=1./float(layer.rules.noise_scale);layer.patch_noise.fractal_octaves=2;layer.prepare_navigation()
		var coords: Array[Vector2i]=[]
		for room in gen.rooms:
			var c := Vector2i(room.p/Gen.CHUNK_PX)
			if not coords.has(c):coords.append(c)
		var first_c: Vector2i=coords[0];coords.append(first_c+Vector2i.RIGHT);coords.append(first_c+Vector2i.DOWN)
		var all_minerals: Array=[]
		for coord in coords:
			var props := gen.props_for_chunk(coord)
			check(props.all(func(row):return row.kind not in [2,3]),"no legacy ordinary scenery rocks "+str(seed_value)+str(coord))
			var rows := Distribution.build(layer,coord)
			for row in rows:
				if not str(row.id).begins_with("mineral:2:"):continue
				counts[row.kind]=int(counts.get(row.kind,0))+1
				check(gen.can_walk(Vector2(row.x,row.y),52),"mine remains dry/walkable "+row.id)
				if row.kind in ["copper_outcrop","silver_outcrop","gold_outcrop"]:check(Distribution.dirt_region(gen,Vector2(row.x,row.y)),"metal restricted to stable mud interior "+row.id)
				all_minerals.append(row)
			chunks.append({"seed":seed_value,"coord":str(coord),"mines":rows.filter(func(row):return str(row.id).begins_with("mineral:2:")).size()})
			var filtered := layer.entries(coord)
			check(filtered.all(func(row):return row.item_id != "stone"),"no loose generated stone "+str(coord))
		var one := Distribution.build(layer,first_c)
		var worker: Dictionary=Service.build_distribution(gen,layer.rules,layer.reachable,first_c)
		check(one==worker.harvest,"same seed/resource worker deterministic "+str(seed_value))
		var ids := {};var spacing_ok := true
		for row in all_minerals:
			if ids.has(row.id):continue
			ids[row.id]=true
			for neighbor in all_minerals:
				if row.id!=neighbor.id and Vector2(row.x,row.y).distance_to(Vector2(neighbor.x,neighbor.y))<184.999:spacing_ok=false
		check(spacing_ok,"cross-chunk mineral spacing >=185 "+str(seed_value))
		layer.free()
	check(counts.has("gold_outcrop") and counts.has("silver_outcrop") and counts.has("copper_outcrop"),"real two-seed accepted samples contain all metals")
	var failed := checks.filter(func(row):return not row.pass)
	var f := FileAccess.open("res://reports/ores-v06/distribution.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"count":checks.size(),"failures":failed,"checks":checks,"accepted_counts":counts,"candidate_mud":mud,"candidate_other":other,"chunks":chunks},"  "));f.close()
	print("ORE_DISTRIBUTION ",checks.size()," checks; ",failed.size()," failures; counts=",counts)
	quit(0 if failed.is_empty() else 1)

