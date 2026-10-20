extends SceneTree
var checks:Array=[]
func _initialize()->void:call_deferred("run")
func check(name:String,pass_value:bool,detail:Variant="")->void:
	checks.append({"name":name,"pass":pass_value,"detail":detail})
func run()->void:
	var Candidate=load("res://prototypes/view-v01/generator.gd")
	var counts=[]
	for seed_value in [271828,81273,902106]:
		Engine.set_meta("view_before",false)
		var old=WildGenerator.new(seed_value,1024)
		var gen=Candidate.new(seed_value,1024)
		var same=Candidate.new(seed_value,1024)
		counts.append({"seed":seed_value,"before":old.lakes.size(),"after":gen.lakes.size(),"spawn_biome":gen.biome(gen.spawn)})
		check("lake thinning %d"%seed_value,gen.lakes.size()<old.lakes.size() and gen.lakes.size()>0,counts[-1])
		check("same seed lake retention %d"%seed_value,gen.lakes==same.lakes)
		var unchanged=true
		for lake in gen.lakes:
			if not old.lakes.has(lake):unchanged=false
		check("retained lake center and envelope %d"%seed_value,unchanged)
		check("macro sites unchanged %d"%seed_value,gen.region_sites==old.region_sites)
		var deterministic=true
		var macro_equal=true
		var changed_water=0
		for lake in gen.lakes.slice(0,8):
			for i in 24:
				var angle=i*TAU/24.0
				var point=Vector2(lake.x,lake.y)+Vector2(cos(angle)*lake.z,sin(angle)*lake.w)
				var value=gen.sample(point)
				var reference=old.sample(point,false)
				if value!=same.sample(point):deterministic=false
				if Vector3(value.x,value.y,value.w)!=Vector3(reference.x,reference.y,reference.w):macro_equal=false
				if absf(value.z-reference.z)>.12:changed_water+=1
		check("irregular shore reproducible %d"%seed_value,deterministic)
		check("land macro weights preserved %d"%seed_value,macro_equal)
		check("water contour differs from ellipse %d"%seed_value,changed_water>12,changed_water)
		# Small world-coordinate overview; underlying macro fields retain exact original sites.
		for before in [true,false]:
			var source=old if before else gen
			var img=Image.create(512,512,false,Image.FORMAT_RGB8)
			for y in 512:
				for x in 512:
					var v=source.sample(Vector2(x+.5,y+.5)*source.extent/512.0)
					var col=Color(.30,.43,.24)*v.x+Color(.57,.55,.47)*v.y+Color(.51,.64,.34)*v.w
					if v.z>.4:col=col.lerp(Color(.24,.49,.56),smoothstep(.4,.7,v.z))
					img.set_pixel(x,y,col)
			img.save_png("res://prototypes/view-v01/map-%d-%s.png"%[seed_value,"before" if before else "after"])
	var fail=0
	for item in checks:
		if not item.pass:fail+=1
	var result={"candidate_version":"windrest-view-0.2.0","engine":Engine.get_version_info().string,"checks":checks,"failures":fail,"lake_counts":counts,"note":"Map images are generated data visualization, not new painted terrain assets. No full regression or performance benchmark."}
	FileAccess.open("res://prototypes/view-v01/checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result))
	quit(1 if fail else 0)
