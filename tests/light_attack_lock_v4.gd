extends SceneTree
var failed:=false
var checks:=0
var effect: ColorRect
var material_effect: ShaderMaterial
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failed=true
func _initialize() -> void:run.call_deferred()
func frame() -> Image:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func lights(centers: PackedVector2Array) -> void:
	material_effect.set_shader_parameter("camp_count",centers.size())
	centers.resize(32);material_effect.set_shader_parameter("camp_centers",centers)
	var radii:=PackedFloat32Array();radii.resize(32);radii.fill(300)
	var strengths:=PackedFloat32Array();strengths.resize(32);strengths.fill(1)
	material_effect.set_shader_parameter("camp_radii",radii);material_effect.set_shader_parameter("camp_strengths",strengths)
func lighter(a: Color,b: Color) -> bool:return a.r>=b.r-.004 and a.g>=b.g-.004 and a.b>=b.b-.004
func run() -> void:
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.set_process(false);w.player.set_physics_process(false);w.item_service.set_process(false);w.environment_view.set_process(false)
	var p=w.player;var s=w.item_service
	p.automated=true;p.input_override=Vector2.RIGHT;p.run_override=true;p.input_blocked=false
	s.body.energy=100;s.body.stamina=100;s.body.down=false;s.combat.personal.phase="alive";s.combat.personal.attack={}
	while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
	var at: Vector2=p.position
	for id in ["unarmed","wood_club","tusk_club"]:
		s.inventory.equipment={} if id=="unarmed" else {"main_hand":s.inventory.instance(id)}
		for elapsed in [.01,float(s.combat.rules.weapons[id].windup),float(s.combat.rules.weapons[id].windup)+.15]:
			s.combat.personal.attack={"weapon":s.combat.rules.weapons[id],"elapsed":elapsed,"direction":{"x":1,"y":0},"targets":{}}
			p._physics_process(1.0/60)
			check(p.position==at and p.velocity==Vector2.ZERO and not p.moving and not p.running,"movement locked "+id+" "+str(elapsed))
	s.combat.personal.attack={};p._physics_process(1.0/60)
	check(p.velocity.length()>0,"movement resumes after attack")
	var worker=load("res://tests/light_attack_movement_harness_v4.gd").new();root.add_child(worker)
	var req: Dictionary={"character":{"x":1000.0,"y":1000.0,"gameplay":{"body":s.body.serialize(),"combat_personal":{"phase":"alive","attack":{"elapsed":.1}}}},"inputs":[{"dx":1.0,"dy":0.0,"dt":.05,"run":true}]}
	worker.movement(req);check(worker.result=={"x":1000.0,"y":1000.0},"authority rejects movement during attack")
	req.character.gameplay.combat_personal.attack={};worker.movement(req);check(worker.result.x>1000,"authority unlocks after attack");worker.queue_free()
	# Real shader on a uniform test surface, using the default project viewport.
	var layer:=CanvasLayer.new();layer.layer=2100;root.add_child(layer)
	var bg:=ColorRect.new();bg.size=Vector2(1280,720);bg.color=Color(.4,.5,.3);layer.add_child(bg)
	effect=ColorRect.new();effect.size=Vector2(1280,720);material_effect=ShaderMaterial.new();material_effect.shader=load("res://scripts/world_environment.gdshader");effect.material=material_effect;layer.add_child(effect)
	material_effect.set_shader_parameter("brightness",.22)
	lights(PackedVector2Array());var dark: Image=await frame()
	lights(PackedVector2Array([Vector2(520.0/1280,.5)]));var left: Image=await frame()
	lights(PackedVector2Array([Vector2(760.0/1280,.5)]));var right: Image=await frame()
	lights(PackedVector2Array([Vector2(520.0/1280,.5),Vector2(760.0/1280,.5)]));var both: Image=await frame()
	var overlap: Color=both.get_pixel(640,360)
	check(overlap.r>left.get_pixel(640,360).r+.02 and overlap.r>right.get_pixel(640,360).r+.02,"overlap adds light beyond either source")
	check(overlap.r>=both.get_pixel(624,360).r-.004 and overlap.r>=both.get_pixel(656,360).r-.004,"overlap midpoint has no dark valley")
	var monotonic:=true
	for x in range(1280):
		if not lighter(both.get_pixel(x,360),left.get_pixel(x,360)) or not lighter(both.get_pixel(x,360),right.get_pixel(x,360)):monotonic=false
	check(monotonic,"adding light never darkens any sampled channel")
	lights(PackedVector2Array([Vector2(760.0/1280,.5),Vector2(520.0/1280,.5)]));var reversed: Image=await frame()
	var difference:=0.0
	for x in 1280:
		var a: Color=both.get_pixel(x,360);var b: Color=reversed.get_pixel(x,360)
		difference=maxf(difference,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
	check(difference<=1.01/255,"light order independent within framebuffer quantization")
	material_effect.set_shader_parameter("lantern_center",Vector2(.5,.5));material_effect.set_shader_parameter("lantern_radius",300);material_effect.set_shader_parameter("lantern_strength",1)
	var mixed: Image=await frame();check(lighter(mixed.get_pixel(640,360),overlap) and mixed.get_pixel(640,360).r>overlap.r+.01,"lantern adds to camp lights")
	var mask:=Image.create(1,1,false,Image.FORMAT_RGBA8);mask.fill(Color.TRANSPARENT)
	material_effect.set_shader_parameter("torch_player_mask",ImageTexture.create_from_image(mask))
	material_effect.set_shader_parameter("torch_count",2)
	var centers:=PackedVector2Array();centers.resize(32);centers.fill(Vector2(.35,.5));var directions:=PackedVector2Array();directions.resize(32);directions.fill(Vector2.RIGHT)
	material_effect.set_shader_parameter("torch_centers",centers);material_effect.set_shader_parameter("torch_directions",directions)
	var torch_two: Image=await frame();material_effect.set_shader_parameter("torch_count",1);var torch_one: Image=await frame()
	check(torch_two.get_pixel(640,360).r>torch_one.get_pixel(640,360).r+.01,"overlapping flashlights accumulate")
	mask.fill(Color.WHITE);material_effect.set_shader_parameter("torch_player_mask",ImageTexture.create_from_image(mask))
	var masked: Image=await frame();check(masked.get_pixel(640,360).is_equal_approx(mixed.get_pixel(640,360)),"flashlight player mask still excludes light")
	material_effect.set_shader_parameter("merchant_glow_scale",1.0);material_effect.set_shader_parameter("merchant_center",Vector2(.5,.5));material_effect.set_shader_parameter("merchant_ground",Vector2(.5,.5))
	var merchant: Image=await frame();check(lighter(merchant.get_pixel(640,360),masked.get_pixel(640,360)) and merchant.get_pixel(640,360).b>masked.get_pixel(640,360).b+.01,"merchant aura adds without darkening")
	material_effect.set_shader_parameter("merchant_glow_scale",0.0)
	material_effect.set_shader_parameter("torch_count",0);material_effect.set_shader_parameter("lantern_strength",0);lights(PackedVector2Array());var off: Image=await frame()
	check(off.get_data()==dark.get_data(),"all lights off restores ambient")
	# Screenshot of actual game rendering with the same registered light shader.
	layer.queue_free();await process_frame
	var real: ShaderMaterial=w.environment_view.material_effect
	real.set_shader_parameter("brightness",.22);real.set_shader_parameter("light_tint",Color.WHITE)
	var a:=PackedVector2Array([Vector2(.35,.45),Vector2(.6,.45),Vector2(.48,.7)]);a.resize(32)
	var r:=PackedFloat32Array();r.resize(32);r.fill(300)
	var strengths:=PackedFloat32Array();strengths.resize(32);strengths.fill(1)
	real.set_shader_parameter("camp_count",3);real.set_shader_parameter("camp_centers",a);real.set_shader_parameter("camp_radii",r);real.set_shader_parameter("camp_strengths",strengths)
	var world_image: Image=await frame();world_image.save_png("res://reports/.tmp/light-overlap-v4-world.png")
	both.save_png("res://reports/.tmp/light-overlap-v4-uniform.png")
	print("LIGHT_MOVEMENT_V4 ",checks," ","FAIL" if failed else "PASS");quit(1 if failed else 0)
