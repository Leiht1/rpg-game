extends SceneTree

const Gen = preload("res://scripts/world_generator.gd")
var failures: Array[String] = []
var report := {}

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message); push_error(message)

func digest(gen: WildGenerator) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for c in [Vector2i(7,14),Vector2i(18,21),Vector2i(25,6)]:
		var packet := gen.build_chunk(c)
		context.update(packet.image.get_data())
		context.update(JSON.stringify(packet.props).to_utf8_buffer())
	return context.finish().hex_encode()

func _initialize() -> void:
	var seeds := [271828,42,20261015,-17]
	var hashes: Array[String] = []
	for seed_value in seeds:
		var a := Gen.new(seed_value,1024)
		var hash_a := digest(a)
		var b := Gen.new(seed_value,1024)
		b.build_chunk(Vector2i(32,7)) # unrelated generation must not alter anything
		check(hash_a==digest(b),"Seed %d differs with generation order"%seed_value)
		check(not hashes.has(hash_a),"Different seeds returned the same map hash")
		hashes.append(hash_a)
		var counts := {"草原":0,"森林":0,"山地":0,"河流":0,"湖泊":0}
		var points := {}
		for y in range(128):
			for x in range(128):
				var p := Vector2(x+.5,y+.5)*a.extent/128.0
				var name := a.biome(p)
				counts[name]+=1
				if not points.has(name): points[name]=[p.x,p.y]
		for name in counts: check(counts[name]>0,"Seed %d has no %s"%[seed_value,name])
		for y in range(-6,7):
			for x in range(-6,7): check(a.can_walk(a.spawn+Vector2(x,y)*20),"Spawn clearance blocked")
		var spawn_chunk := Vector2i(a.spawn/Gen.CHUNK_PX)
		for prop in a.props_for_chunk(spawn_chunk): check(prop.position.distance_to(a.spawn)>=150,"Spawn intersects prop")
		var left: Image = a.build_chunk(Vector2i(10,12)).image
		var right: Image = a.build_chunk(Vector2i(11,12)).image
		var down: Image = a.build_chunk(Vector2i(10,13)).image
		for i in range(Gen.TEX_RES+2):
			check(left.get_pixel(Gen.TEX_RES,i)==right.get_pixel(0,i),"Horizontal apron mismatch A")
			check(left.get_pixel(Gen.TEX_RES+1,i)==right.get_pixel(1,i),"Horizontal apron mismatch B")
			check(left.get_pixel(i,Gen.TEX_RES)==down.get_pixel(i,0),"Vertical apron mismatch")
		var ford_found := false
		for k in range(1,15):
			var fy := k*3200.0-a.phase*200
			var ford := Vector2(a.river_x(fy),fy)
			if a.can_walk(ford): ford_found=true
		check(ford_found,"No passable river ford")
		report[str(seed_value)]={"hash":hash_a,"biomes":counts,"example_points":points,"spawn":str(a.spawn),"seams":"exact shared apron pixels","spawn_clearance_radius":120}
		if seed_value in [271828,42]:
			var image := Image.create(512,512,false,Image.FORMAT_RGB8)
			for y in range(512):
				for x in range(512):
					var v := a.sample(Vector2(x,y)*a.extent/512.0)
					var color := Color("9cbf79").lerp(Color("648d65"),v.x).lerp(Color("aaa48d"),v.y)
					color=color.lerp(Color("79b9c0"),v.z)
					image.set_pixel(x,y,color)
			image.save_png("res://reports/seed-%d-overview.png"%seed_value)
	report["generator"]=Gen.VERSION
	report["failures"]=failures
	report["status"]="pass" if failures.is_empty() else "fail"
	FileAccess.open("res://reports/generator-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("GENERATOR_TESTS ",report.status," | ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
