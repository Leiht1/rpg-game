extends SceneTree
func _initialize() -> void:run.call_deferred()
func layer_for(gen, rules):
	var layer=load("res://scripts/item_service.gd").new()
	layer.world={"generator":gen,"Gen":load("res://scripts/world_generator.gd")}
	layer.rules=rules;layer.navigation_ready=true
	for y in ceili(gen.extent/float(rules.navigation_step)):
		for x in ceili(gen.extent/float(rules.navigation_step)):layer.reachable[Vector2i(x,y)]=true
	layer.patch_noise.seed=gen.world_seed ^ 87361
	layer.patch_noise.frequency=1.0/float(rules.noise_scale);layer.patch_noise.fractal_octaves=2
	return layer
func run() -> void:
	var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/natural_resources.json"))
	var old:=config.duplicate(true);old.starter_resource_double=false
	var total:={"flint":[0,0],"branch":[0,0]};var checks:=0
	for seed_value in [271828,81273,604619]:
		var gen=load("res://scripts/world_generator.gd").new(seed_value,1536)
		var before=layer_for(gen,old);var after=layer_for(gen,config)
		var base:=Vector2i(gen.spawn/1152)
		for y in range(base.y-3,base.y+4):
			for x in range(base.x-3,base.x+4):
				var coord:=Vector2i(x,y)
				var prior:Array=before.chunk_distribution(coord).accepted
				var current:Array=after.chunk_distribution(coord).accepted
				var known:={}
				for row in current:known[row.id]=row
				for row in prior:
					assert(known.has(row.id) and known[row.id].x==row.x and known[row.id].y==row.y and known[row.id].item_id==row.item_id);checks+=1
					if total.has(row.item_id):total[row.item_id][0]+=1
				for row in current:
					if total.has(row.item_id):total[row.item_id][1]+=1
		print("RESOURCE_SAMPLE seed=",seed_value," running=",total)
		before.free();after.free()
	for id in total:
		assert(total[id][0]>0 and total[id][1]==total[id][0]*2,"exact double "+id);checks+=1
	print("STARTER_DOUBLE_PASS checks=",checks," totals=",total)
	quit()
