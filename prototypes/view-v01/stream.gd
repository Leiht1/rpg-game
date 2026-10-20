extends WildStream
func configure(gen: WildGenerator, sort_root: Node2D) -> void:
	super.configure(gen,sort_root)
	if Engine.get_meta("view_before",false):
		for i in 4:
			textures[i]=load("res://assets/environment/stylized_v3/"+FILES[i]+".png")
		shared_material.shader=load("res://prototypes/view-v01/lake-v01-archive/terrain.gdshader")
	if not Engine.get_meta("view_before",false):
		shared_material.shader=load("res://prototypes/view-v01/terrain.gdshader")
		for i in 4:
			textures[i]=ImageTexture.create_from_image(Image.load_from_file("res://prototypes/view-v01/"+FILES[i]+".png"))
func _generate(coord: Vector2i) -> void:
	# Each worker owns its noises; no RenderingServer or scene nodes here.
	var local_gen:WildGenerator = load("res://prototypes/view-v01/generator.gd").new(generator.world_seed,generator.map_cells)
	var packet := local_gen.build_chunk(coord)
	var empty_stamps:Array[Dictionary]=[] # Approved surface replaces legacy stamps.
	packet["ground_stamps"]=empty_stamps
	mutex.lock()
	ready_data.append(packet)
	mutex.unlock()
