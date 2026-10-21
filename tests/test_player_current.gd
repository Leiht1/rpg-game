extends SceneTree
## Current joint-rig contract, replacing the retired SpriteFrames template test.
var failures: Array[String]=[]
var checks := 0
var world: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n: int=2) -> void:
	for i in n:await process_frame
func run() -> void:
	world=preload("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	var p: WildPlayer=world.player
	while not world.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
	world.environment_view.simulation.paused=true;p.set_physics_process(false);p.automated=true
	var origin: Vector2=p.position
	check(WildPlayer.WALK_SPEED==200 and WildPlayer.RUN_SPEED==310,"authorized walk and run speeds")
	check(p.actor.schema=="windrest.cartoon_actor.v1","current native joint rig")
	check(p.character.position==-WildPlayer.ANCHOR,"native foot anchor")
	check(p.find_children("*","CollisionShape2D",true,false)[0].shape.radius==10,"original collision radius")
	for facing in ["front","back","right","left"]:
		p.facing=facing;p.moving=false
		var view: String="side" if facing in ["right","left"] else facing
		var clip: Animation=p.animation_player.get_animation(view+"_breathe")
		check(is_equal_approx(clip.length,1.8) and clip.loop_mode==Animation.LOOP_LINEAR,"breathing duration and loop "+facing)
		for sample in [0.0,.449,.45,.899,.9,1.349,1.35,1.799,1.8,2.25,3.6]:
			p.idle_clock=sample;p.update_animation()
			check(p.animation_player.current_animation==view+"_breathe" and is_equal_approx(p.animation_player.current_animation_position,fposmod(sample,clip.length)),"continuous joint breathing phase "+facing+str(sample))
			check(p.character.get_node("Visual").scale.x==(-1 if facing=="left" else 1),"breathing mirror "+facing)
			check(p.position==origin and p.character.position==-WildPlayer.ANCHOR,"breathing keeps physics body and anchor fixed")
	var distances: Array[float]=[]
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
		p.position=origin;p.gait_distance=0;p.input_override=direction
		for i in 12:p._physics_process(1.0/60.0)
		var distance: float=p.position.distance_to(origin);distances.append(distance)
		check(absf(distance-40)<.2,"normalized eight-direction movement "+str(direction))
		check(absf(p.gait_distance-distance)<.2,"gait follows actual movement")
		var clip: Animation=p.animation_player.get_animation(p.animation_player.current_animation)
		check(is_equal_approx(p.animation_player.current_animation_position,fposmod(p.gait_distance/float(p.actor.stride_world_units),1)*clip.length),"walk phase follows distance")
		p.input_override=Vector2.ZERO;p._physics_process(1.0/60.0)
		check(not p.moving and p.animation_player.current_animation.ends_with("breathe"),"release enters breathing")
	p.position=origin;p.moving=true;p.gait_distance=47
	for i in 180:
		p.facing=["front","back","left","right"][i%4];p.update_animation()
		var clip: Animation=p.animation_player.get_animation(p.animation_player.current_animation)
		check(is_equal_approx(p.animation_player.current_animation_position,fposmod(47/float(p.actor.stride_world_units),1)*clip.length),"rapid turn preserves distance phase")
		check(p.character.position==-WildPlayer.ANCHOR,"rapid turn preserves anchor")
	p.moving=false;p.input_override=Vector2.ZERO
	for pair in [[KEY_W,Vector2.UP],[KEY_A,Vector2.LEFT],[KEY_S,Vector2.DOWN],[KEY_D,Vector2.RIGHT]]:
		p.automated=false;p.position=origin
		var event:=InputEventKey.new();event.physical_keycode=pair[0];event.keycode=pair[0];event.pressed=true
		Input.parse_input_event(event);await frames();p._physics_process(1.0/60.0)
		check(p.velocity.normalized().dot(pair[1])>.99,"physical WASD binding")
		event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await frames()
	var wheel:=InputEventMouseButton.new();wheel.pressed=true;wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
	for i in 20:p.zoom_from_wheel(wheel)
	check(is_equal_approx(p.camera.zoom.x,.65),"minimum zoom")
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	for i in 40:p.zoom_from_wheel(wheel)
	check(is_equal_approx(p.camera.zoom.x,1.65),"maximum zoom")
	check(p.camera.position_smoothing_enabled and world.object_root.y_sort_enabled,"camera smoothing and Y sorting")
	FileAccess.open("res://reports/player-tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"distances":distances}))
	world.item_service.dirty=false;world.queue_free();await frames(6)
	print("PLAYER_CURRENT ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
