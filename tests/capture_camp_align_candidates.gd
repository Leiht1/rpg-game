extends SceneTree
const OUT := "res://reports/camp-build-fix-v1/"
var world: Node
var managers: Array=[]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	world.player.set_physics_process(false);world.environment_view.simulation.paused=true;world.environment_view.simulation.minute=720
	root.size=Vector2i(1280,720)
	var center: Vector2=world.generator.spawn
	world.player.position=center;world.player.camera.force_update_scroll()
	while not world.stream.viewport_ready(center,Vector2(640,360)): await process_frame
	var ui := CanvasLayer.new();root.add_child(ui)
	for i in 2:
		var label_value := Label.new();label_value.text="正式原图（保留）" if i==0 else "独立候选（待确认，未接入）";label_value.position=Vector2(320+i*340,175);label_value.add_theme_font_size_override("font_size",22);ui.add_child(label_value)
		var manager=preload("res://scripts/camp_buildings.gd").new();manager.service=world.item_service;managers.append(manager)
		if i==1:
			for pair in [[13,"wood_chest"],[14,"workbench"],[4,"wood_fence_vertical"]]: manager.textures[pair[0]]=ImageTexture.create_from_image(Image.load_from_file("res://prototypes/camp-align-v1/final/"+pair[1]+".png"))
		for entry in [["wood_chest",Vector2(-60,-52)],["workbench",Vector2(60,-52)],["wood_fence",Vector2(-48,64)]]:
			var at: Vector2=center+Vector2(-170 if i==0 else 170,0)+entry[1]
			var row: Dictionary=manager.candidate(entry[0],at,entry[0]=="wood_fence",true,0)
			# Free static comparison avoids adding connections which could obscure the art under review.
			if entry[0]=="wood_fence":
				var sprite := Sprite2D.new();sprite.texture=manager.textures.get(4,load("res://assets/buildings/v1/frame-04.png"));sprite.position=at+Vector2(0,-18);sprite.scale=Vector2(28,100)/sprite.texture.get_size();world.object_root.add_child(sprite)
			else:
				var id: String="candidate:"+str(i)+":"+entry[0];manager.states[id]=row
				var node=preload("res://scripts/camp_building.gd").new();node.preview=true;node.manager=manager;node.building_id=id;node.position=at;world.object_root.add_child(node)
		var gate := Sprite2D.new();gate.texture=load("res://assets/buildings/v1/frame-10.png") if i==0 else ImageTexture.create_from_image(Image.load_from_file("res://prototypes/camp-align-v1/final/fence_gate_vertical.png"));gate.position=center+Vector2(-110 if i==0 else 230,46);gate.scale=Vector2(28,100)/gate.texture.get_size();world.object_root.add_child(gate)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"candidate-comparison.png")
	print("CANDIDATE COMPARISON: real Godot rendering, static art review only; no formal asset adoption")
	world.free();ui.free();managers.clear();await process_frame;quit()
