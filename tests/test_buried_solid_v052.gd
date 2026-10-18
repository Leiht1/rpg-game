extends SceneTree
const OUT := "res://reports/buried-solid-v052/"
var world: Node
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func frames(n: int=3) -> void:
	for i in n:await process_frame
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func run() -> void:
	Engine.max_fps=60;Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	world.player.automated=true;world.player.set_physics_process(false)
	world.environment_view.simulation.set_time(10);world.environment_view.simulation.paused=true
	var p: Vector2=world.generator.spawn
	for node in get_nodes_in_group("world_interactables"):node.queue_free()
	for drop in world.stream.drops.duplicate():
		if is_instance_valid(drop) and drop.position.distance_to(p)<400:world.stream.drops.erase(drop);drop.queue_free()
	await frames()
	world.player.position=p+Vector2(180,50);world.player.reset_physics_interpolation();world.player.camera.reset_smoothing()
	var gallery: Array=[]
	var col := 0
	for kind in ["buried_root","buried_bone","buried_supply"]:
		for row in 3:
			var id: String="solid:"+kind+str(row)
			var node: Node2D=world.item_service.create_harvest(id,{"kind":kind,"x":p.x-110+col*100,"y":p.y-90+row*85})
			var texture: Texture2D=node.sprite.texture
			var transform: Transform2D=node.sprite.transform
			var soil_transform: Transform2D=node.soil.transform
			for progress in range(int(node.definition.hits)+1):
				world.item_service.resource_hits[id]=progress;node.refresh_stage()
				check(node.sprite.texture==texture and node.sprite.transform==transform and node.sprite.modulate.a==1,"solid subject registration/opacity "+id+str(progress))
				check(node.soil.transform==soil_transform and node.soil.visible==(progress<int(node.definition.hits)),"painted soil fixed and removed at completion "+id+str(progress))
			world.item_service.resource_hits[id]=[0,1,int(node.definition.hits)][row];node.refresh_stage();gallery.append(node)
		col+=1
	var source := FileAccess.get_file_as_string("res://scripts/harvest_hit.gdshader")
	check(not source.contains("soil_cover") and not source.contains("c.a*=") and source.contains("discard"),"subject has opaque cutout, no tinted translucent burial veil")
	await frames(12);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"game-stages.png")
	# Tight native game crop for viewing at actual pixel scale.
	root.get_texture().get_image().get_region(Rect2i(210,100,850,470)).save_png(OUT+"game-stages-detail.png")
	# Direct alpha observation of a source-opaque carrot pixel in the exposed portion.
	var viewport := SubViewport.new();viewport.size=Vector2i(280,280);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var specimen := Sprite2D.new();specimen.centered=false;specimen.texture=load("res://assets/harvest/v05/frame-11.png")
	var material := ShaderMaterial.new();material.shader=load("res://scripts/harvest_hit.gdshader");material.set_shader_parameter("buried",true);material.set_shader_parameter("exposure",.35);material.set_shader_parameter("damage_texture",specimen.texture)
	specimen.material=material;viewport.add_child(specimen)
	await frames(5);await RenderingServer.frame_post_draw
	var image: Image=viewport.get_texture().get_image()
	var input: Image=specimen.texture.get_image()
	var opaque := 0;var nonopaque := 0
	for y in range(145,188):
		for x in range(95,155):
			var c := input.get_pixel(x,y)
			if c.a>.99 and c.r>c.g*1.6:
				opaque+=1
				if image.get_pixel(x,y).a<.99:nonopaque+=1
	check(opaque>30 and nonopaque==0,"exposed carrot retains opaque source pixels, no ghosting")
	viewport.queue_free();await frames()
	var failed := checks.filter(func(c):return not c.pass)
	var f := FileAccess.open(OUT+"tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"count":checks.size(),"failures":failed,"checks":checks,"opaque_carrot_pixels":opaque,"faded_pixels":nonopaque},"  "));f.close()
	print("BURIED_SOLID ",checks.size()," checks; ",failed.size()," failures; opaque=",opaque," faded=",nonopaque)
	world.queue_free();await frames(8);quit(0 if failed.is_empty() else 1)
