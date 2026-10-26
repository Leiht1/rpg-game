extends SceneTree
## Ordinary final-chapter view in a disposable world; no preview art switch.
var w: Node
var checks: Array=[]
const OUT="res://reports/guardian-wolf-formal-v1/"
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"pass":ok,"test":label});print("PASS " if ok else "FAIL ",label)
func frames(n: int) -> void:
	for i in n:await process_frame
func shot(file: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await frames(2);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+file+".png")
func run() -> void:
	var wolf: Node2D=load("res://assets/exploration/wolf-v1/wolf.tscn").instantiate()
	root.add_child(wolf);await process_frame
	check(wolf.has_method("update_motion"),"formal wolf includes presentation driver")
	var ap: AnimationPlayer=wolf.get_node("AnimationPlayer")
	check(ap.has_animation("side_idle") and ap.has_animation("side_walk"),"approved idle and walk available")
	var textures: Dictionary={};var part_count:=0
	for node in wolf.get_children():
		if node is Node2D:
			part_count+=1
			var pic: Sprite2D=node.get_node("Sprite")
			textures[pic.texture.resource_path]=true
	check(part_count==19 and textures.size()==12,"nineteen layered parts use twelve formal textures")
	check(textures.keys().all(func(p):return str(p).begins_with("res://assets/exploration/wolf-v1/")),"runtime has no candidate texture dependency")
	var idle: Dictionary={"mode":"idle","attack":"","direction":{"x":0.0,"y":1.0}}
	wolf.update_motion(Vector2.ZERO,idle,1.0/60)
	check(ap.current_animation=="side_idle" and not wolf.moving,"stationary boss idles on first frame")
	var chase: Dictionary=idle.duplicate(true);chase.mode="chase"
	wolf.update_motion(Vector2(1.1,0),chase,1.0/60)
	check(wolf.moving and ap.current_animation=="side_walk" and wolf.scale.x==1,"rightward motion starts approved walk")
	check(absf(ap.speed_scale-66.0/wolf.WALK_SPEED)<.001,"walk rate follows actual displacement")
	wolf.update_motion(Vector2.ZERO,chase,1.0/60)
	check(wolf.scale.x==-1 and wolf.scale.y==1,"left uses whole-body mirror without compression")
	var state_before: Dictionary=idle.duplicate(true)
	wolf.update_motion(Vector2.ZERO,idle,1.0/60)
	check(ap.current_animation=="side_idle" and ap.speed_scale==1,"stopping restores idle")
	check(idle==state_before,"presentation does not mutate authoritative state")
	var windup: Dictionary={"mode":"windup","attack":"slam","direction":{"x":1.0,"y":0.0}}
	wolf.update_motion(Vector2.ZERO,windup,1.0/60)
	check(wolf.scale.x==1 and ap.current_animation=="side_idle","windup faces authoritative attack direction")
	var charge: Dictionary=windup.duplicate(true);charge.mode="active";charge.attack="charge"
	wolf.update_motion(Vector2(6,0),charge,1.0/60)
	check(ap.current_animation=="side_walk" and absf(ap.speed_scale-360.0/wolf.WALK_SPEED)<.001,"existing charge reuses walk at actual speed")
	wolf.update_motion(Vector2(1000,0),chase,1.0/60)
	check(not wolf.moving and ap.current_animation=="side_idle","large restore jump does not sprint in place")
	for clip in ["side_idle","side_walk"]:
		ap.play(clip)
		var duration: float=ap.get_animation(clip).length
		for i in 97:
			ap.seek(duration*i/96.0,true)
			var finite:=true
			for node in wolf.get_children():
				if node is Node2D:finite=finite and node.transform.is_finite()
			if not finite:check(false,"finite formal animation: "+clip);break
		check(true,"formal clip sampled at 97 positions: "+clip)
	wolf.queue_free();await frames(2)
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w);current_scene=w
	while not w.started:await process_frame
	var s=w.item_service
	w.set_process(false);s.set_process(false);w.environment_view.set_process(false)
	w.player.set_physics_process(false);w.player.automated=true;w.player.camera.position_smoothing_enabled=false
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/final-chapter-v1/ready.json"))
	s.load_state("",false,source)
	check(not w.persistent_world and w.environment_view.save_path.is_empty(),"fixture never writes player world or environment")
	var f=s.chapter.finale
	for key in ["discovered","triggered","defeated","core_claimed","chest_open","letter_claimed","blueprint_claimed","dock_unlocked"]:f.state[key]=false
	f.reset_boss();s.guide_stage=2;s.combat.state.boars.clear();s.body.health=100;s.combat.personal.phase="alive"
	check(f.valid(f.state),"existing final-chapter state remains valid")
	w.environment_view.simulation.day=30;w.environment_view.simulation.minute=600;w.environment_view.simulation.force_weather(0)
	var at: Vector2=f.boss_at()
	w.player.position=at+Vector2(-260,80);w.player.camera.offset=Vector2(130,-150);w.player.camera.zoom=Vector2.ONE
	w.player.camera.reset_smoothing();w.player.reset_physics_interpolation();w.stream.update_target(w.player.position)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	await frames(8)
	var view: Node=s.chapter_view.get_node("FinaleView");view.set_process(false);view._process(1.0/60)
	check(view.body.scene_file_path=="res://assets/exploration/wolf-v1/wolf.tscn","ordinary game view directly uses formal wolf")
	check(view.guardian.visible and view.body.visible,"living wolf visible in real arena")
	check(view.body.position==Vector2.ZERO and view.body.rotation==0,"old whole-picture bob and tilt excluded")
	check(view.guardian.get_node("Volume").get_child(0).shape.radius==35,"original collision footprint preserved")
	view.body.get_node("AnimationPlayer").speed_scale=0
	await shot("01-world-normal")
	w.player.camera.zoom=Vector2.ONE*1.45;w.player.camera.reset_smoothing();await shot("02-world-large")
	f.state.triggered=true;f.state.discovered=true;f.state.boss.mode="chase"
	for i in 18:
		f.state.boss.x+=1.1;view._process(1.0/60);await process_frame
	check(view.body.moving,"real model movement drives walking")
	view.body.get_node("AnimationPlayer").speed_scale=0;await shot("03-walk-right")
	for i in 18:
		f.state.boss.x-=1.1;view._process(1.0/60);await process_frame
	check(view.body.scale.x==-1,"real arena movement mirrors left")
	view.body.get_node("AnimationPlayer").speed_scale=0;await shot("04-walk-left")
	f.state.boss.mode="windup";f.state.boss.attack="core";f.state.boss.health=150;f.state.boss.direction={"x":-1.0,"y":0.0}
	view.previous_health=150;view.hit_flash=0
	var before: Dictionary=f.state.duplicate(true);view._process(1.0/60)
	check(view.health.visible and view.health.value==150,"original health presentation retained")
	check(view.body.modulate==Color(1.18,1.3,1.3),"original core-attack tint retained")
	check(f.state==before,"view leaves boss and rewards state untouched")
	view.body.get_node("AnimationPlayer").speed_scale=0;await shot("05-core-warning")
	f.state.boss.health=140;view._process(1.0/60)
	check(view.hit_flash>0,"original damage flash retained")
	f.state.boss.mode="idle";f.state.boss.attack="";view.hit_flash=0;view._process(1.0/60)
	w.player.position=f.boss_at()+Vector2(-90,10);w.player.reset_physics_interpolation();await physics_frame;await physics_frame
	var hit: KinematicCollision2D=w.player.move_and_collide(Vector2(180,0))
	check(hit!=null and hit.get_collider()==view.guardian.get_node("Volume"),"player is blocked by original guardian collision")
	w.player.position=f.boss_at()+Vector2(-94,-10);w.player.camera.offset=Vector2(94,-60);w.player.camera.zoom=Vector2.ONE;w.player.camera.reset_smoothing();w.player.reset_physics_interpolation();await shot("06-player-behind")
	w.player.position=f.boss_at()+Vector2(-94,10);w.player.camera.offset=Vector2(94,-80);w.player.camera.reset_smoothing();w.player.reset_physics_interpolation();await shot("07-player-front")
	f.state.defeated=true;f.state.boss.health=0;f.state.boss.mode="dead";view._process(1.0/60);await frames(3);await physics_frame
	check(not view.guardian.visible and view.core.visible,"victory hides wolf and retains existing core pickup")
	check(view.guardian.get_node("Volume").get_child(0).disabled,"defeated guardian no longer blocks")
	check(not f.state.core_claimed and not f.state.chest_open,"view never awards loot on its own")
	var failed: int=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("GUARDIAN WOLF FORMAL ",checks.size()," checks ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(1 if failed else 0)
