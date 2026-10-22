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
	var old:=config.duplicate(true)
	old.biomes.meadow.weights.flint=2;old.biomes.forest.weights.flint=1;old.biomes.mountain.weights.flint=6
	var totals:=[0,0]
	for seed_value in [271828,81273,604619]:
		var gen=load("res://scripts/world_generator.gd").new(seed_value,1536)
		var before=layer_for(gen,old);var after=layer_for(gen,config)
		var counts:=[0,0]
		var base:=Vector2i(gen.spawn/1152)
		for y in range(base.y-4,base.y+5):
			for x in range(base.x-4,base.x+5):
				var cell:=Vector2i(x,y)
				var prior:Array=before.raw_cell(cell);var current:Array=after.raw_cell(cell)
				assert(prior.size()==current.size())
				for i in prior.size():assert(prior[i].id==current[i].id and prior[i].x==current[i].x and prior[i].y==current[i].y)
				for row in before.chunk_distribution(cell).accepted:
					if row.item_id=="flint":counts[0]+=1
				for row in after.chunk_distribution(cell).accepted:
					if row.item_id=="flint":counts[1]+=1
		print("FLINT_SAMPLE ",seed_value," ",counts)
		totals[0]+=counts[0];totals[1]+=counts[1]
		before.free();after.free()
	assert(totals[1]>totals[0]);print("FLINT_TOTAL ",totals)
	var world=load("res://scripts/network_game_world.gd").new()
	world.session_data={"profile":{"nickname":"自己的名字"}}
	world.player=load("res://scripts/player.gd").new()
	world.add_child(world.object_root);world.object_root.add_child(world.player)
	world.player.position=Vector2(500,500)
	var actor:=Node2D.new();actor.position=Vector2(700,600)
	var label:=Label.new();label.name="Nickname";label.text="同伴名字";actor.add_child(label)
	world.object_root.add_child(actor);world.actors["companion"]=actor
	var map=load("res://scripts/world_map.gd").new();map.player=world.player
	map.generator=load("res://scripts/world_generator.gd").new(271828,128)
	map.center=Vector2(650,550);map.zoom=4;map.map_rect=Rect2(250,100,570,570)
	var markers:Array=map.player_markers()
	assert(markers.size()==2 and markers[0].name=="自己的名字" and markers[0].self)
	assert(markers[1].name=="同伴名字" and not markers[1].self)
	actor.position+=Vector2(200,100);label.text="新名字"
	assert(map.player_markers()[1].position==actor.position and map.player_markers()[1].name=="新名字")
	var canvas:=Control.new();root.add_child(canvas)
	canvas.draw.connect(map.draw_markers.bind(canvas));canvas.queue_redraw()
	await create_timer(.2).timeout
	DirAccess.make_dir_recursive_absolute("res://reports/.tmp/flint-map")
	root.get_texture().get_image().save_png("res://reports/.tmp/flint-map/markers.png")
	world.actors.erase("companion");actor.free();assert(map.player_markers().size()==1)
	world.free();map.free();canvas.queue_free();await process_frame
	print("FLINT_MAP_MARKERS_PASS density, stable IDs/coordinates, own/companion names, movement, rename, leave, drawing")
	quit()
