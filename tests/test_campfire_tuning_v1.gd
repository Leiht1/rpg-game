extends SceneTree
const OUT := "res://reports/campfire-tuning-v1/"
var checks: Array=[]
var capture := false
var world: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n: int=3) -> void:
	for i in n:await process_frame
func reset(camps: RefCounted, fuel: float=100.0, lit: bool=true) -> void:
	camps.states={"tuning":{"x":world.generator.spawn.x+100,"y":world.generator.spawn.y,"fuel":fuel,"lit":lit,"recipe":"roast_carrot","elapsed":0.0,"ready":false}}
	camps.rebuild()
func run() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	world.player.set_physics_process(false);world.environment_view.set_process(false)
	var service: Node=world.item_service
	var camps: RefCounted=service.camps
	for id in {"wild_carrot":4,"wild_apple":4,"wild_berry":3,"brown_mushroom":3,"wildflower":1,"roasted_carrot":12,"roasted_mushroom":10}:
		var expected: int={"wild_carrot":4,"wild_apple":4,"wild_berry":3,"brown_mushroom":3,"wildflower":1,"roasted_carrot":12,"roasted_mushroom":10}[id]
		for i in 40:service.inventory.slots[i]={}
		service.body.hunger=20;service.body.health=100;service.inventory.add(id,1)
		check(service.inventory.use_slot(8) and service.body.hunger==20+expected and service.inventory.count_item(id)==0,"actual food benefit "+id+" +"+str(expected))
		service.body.hunger=100;service.inventory.add(id,1)
		check(not service.inventory.use_slot(8) and service.inventory.count_item(id)==1,"full hunger preserves "+id)
	check(camps.burn_multiplier(0,0)==1 and camps.burn_multiplier(1,0)==1.5 and camps.burn_multiplier(1,1)==2,"clear small rain and storm multipliers configured")
	check(camps.burn_multiplier(.5,0)==1.25 and camps.burn_multiplier(1,.5)==1.75,"weather blend smoothly interpolates fuel multiplier")
	reset(camps);camps.advance(4)
	check(camps.states.tuning.fuel==96 and camps.states.tuning.elapsed==4,"clear fuel and cooking unchanged")
	reset(camps);camps.advance(4,1,0)
	check(camps.states.tuning.fuel==94 and camps.states.tuning.elapsed==4,"small rain burns faster without speeding cooking")
	reset(camps);camps.advance(4,1,1)
	check(camps.states.tuning.fuel==92 and camps.states.tuning.elapsed==4,"storm burns twice as fast with normal cooking")
	reset(camps,3);camps.advance(4,1,1)
	check(camps.states.tuning.fuel==0 and camps.states.tuning.elapsed==1.5 and not camps.states.tuning.lit,"storm depletion advances only actual available cooking seconds")
	camps.advance(20,1,1);check(camps.states.tuning.elapsed==1.5,"extinguished rainy camp remains paused")
	reset(camps,100,false);camps.advance(5,1,1)
	check(camps.states.tuning.fuel==100 and camps.states.tuning.elapsed==0,"unlit fire does not lose fuel even in storm")
	reset(camps);camps.advance(0,1,1);check(camps.states.tuning.fuel==100,"zero time cannot consume rainy fuel")
	var environment: Node=world.environment_view
	var simulation: Node=environment.simulation
	reset(camps);simulation.blend=Vector3(0,0,1);simulation.paused=false;simulation.time_scale=1
	environment._process(2)
	check(camps.states.tuning.fuel==97 and camps.states.tuning.elapsed==2,"actual environment adapter supplies small rain exposure")
	reset(camps);simulation.blend=Vector3(0,1,0);environment._process(2)
	check(camps.states.tuning.fuel==96 and camps.states.tuning.elapsed==2,"actual environment adapter supplies storm exposure")
	reset(camps);simulation.paused=true;environment._process(5)
	check(camps.states.tuning.fuel==100,"pause still excludes rainy fuel consumption")
	simulation.paused=false;environment.preview=true;environment._process(5)
	check(camps.states.tuning.fuel==100,"debug day preview still excludes rainy fuel consumption")
	environment.preview=false;simulation.paused=true
	check(camps.validate(camps.serialize()),"rain uses existing valid save fields without new state version")
	while not world.stream.viewport_ready(world.player.position,Vector2(640,360)):await process_frame
	reset(camps);camps.install(world.stream.chunk_at(Vector2(camps.states.tuning.x,camps.states.tuning.y)))
	var node: Node2D=camps.visuals.tuning
	node.set_process(false);node._process(0)
	var original_transform: Transform2D=node.flame.transform
	var original_color: Color=node.flame.modulate
	for i in 40:node._process(.03)
	check(node.flame.transform==original_transform and node.flame.modulate==original_color,"animation no longer scales translates or fades whole flame")
	check(node.flame_material.get_shader_parameter("phase")>1,"native flame shader receives animation phase")
	if capture:
		# Freeze both the world grading and scene transforms; compare actual rendered flame pixels.
		world.player.camera.position_smoothing_enabled=false;world.player.camera.force_update_scroll()
		simulation.blend=Vector3(1,0,0);simulation.set_time(12);environment._process(0)
		node.age=0;node._process(0);await frames();await RenderingServer.frame_post_draw
		var first: Image=root.get_texture().get_image();first.save_png(OUT+"flame-a.png")
		node._process(.35);await frames();await RenderingServer.frame_post_draw
		var second: Image=root.get_texture().get_image();second.save_png(OUT+"flame-b.png")
		var top_left: Vector2=root.get_canvas_transform()*(node.flame.global_position-Vector2.ONE*25.6)
		var lower_changed := 0;var upper_changed := 0;var lower_samples := 0
		for y in range(3,49):
			for x in range(2,49):
				var point := Vector2i(top_left)+Vector2i(x,y)
				var changed: bool=first.get_pixelv(point)!=second.get_pixelv(point)
				if y>=44:
					lower_samples+=1
					if changed:lower_changed+=1
				elif y<36 and changed:upper_changed+=1
		check(lower_samples>0 and lower_changed==0,"rendered flame lower band remains pixel stationary")
		check(upper_changed>0,"rendered flame upper silhouette visibly changes")
		print("FLAME_PIXELS lower_changed=",lower_changed," lower_samples=",lower_samples," upper_changed=",upper_changed)
	var failed: int=checks.filter(func(row):return not row.pass).size()
	FileAccess.open(OUT+("window" if capture else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("CAMPFIRE TUNING: ",checks.size()," checks; ",failed," failures")
	service.dirty=false;world.queue_free();await frames(6);quit(0 if failed==0 else 1)
