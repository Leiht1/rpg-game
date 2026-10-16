class_name WildPlayer
extends CharacterBody2D

const WALK_SPEED := 200.0
const RUN_SPEED := 310.0
const CANVAS := 128
const ANCHOR := Vector2(64,112)
var stream: WildStream
var generator: WildGenerator
var facing := "front"
var moving := false
var running := false
var run_override := false
var input_blocked := false
var chop_buffer := 0.0
var chained_chop := false
var hold_chop := false
var action := ""
var action_clock := 0.0
var action_target: Node2D
var action_committed := false
var carried_wood: Sprite2D
var gait_distance := 0.0
var idle_clock := 0.0
var character: Node2D
var animation_player: AnimationPlayer
var actor: Dictionary
var camera := Camera2D.new()
var input_override := Vector2.ZERO
var automated := false
var blocked_by_loading := false
var last_displacement := Vector2.ZERO

func _ready() -> void:
	actor=JSON.parse_string(FileAccess.get_file_as_string("res://assets/hero/cartoon/runtime.json"))
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius=10
	collider.shape=circle
	add_child(collider)
	character=load("res://assets/hero/cartoon/character.tscn").instantiate()
	character.position=-ANCHOR
	character.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(character)
	carried_wood=Sprite2D.new()
	carried_wood.name="CarryWood"
	carried_wood.texture=load("res://assets/environment/cartoon_v2/wood.png")
	carried_wood.scale=Vector2.ONE*.65
	carried_wood.visible=false
	character.get_node("Visual/Pelvis/ArmR/Grip").add_child(carried_wood)
	animation_player=character.get_node("AnimationPlayer")
	animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	camera.position_smoothing_enabled=true
	camera.position_smoothing_speed=7.0
	camera.limit_left=0
	camera.limit_top=0
	camera.limit_right=roundi(generator.extent)
	camera.limit_bottom=roundi(generator.extent)
	add_child(camera)
	update_animation()

func _draw() -> void:
	draw_set_transform(Vector2(0,-2),0,Vector2(1,.35))
	draw_circle(Vector2.ZERO,16,Color(.17,.23,.16,.19))

func _physics_process(delta: float) -> void:
	if input_blocked:
		velocity=Vector2.ZERO
		last_displacement=Vector2.ZERO
		return
	chop_buffer=maxf(0.0,chop_buffer-delta)
	var direction := input_override if automated else Input.get_vector("move_left","move_right","move_up","move_down")
	direction=direction.limit_length(1.0)
	running=run_override if automated else Input.is_action_pressed("run")
	if action=="chop":
		if not Input.is_action_pressed("interact"): hold_chop=false
		if not stream.tree_in_reach(position,action_target):
			hold_chop=false
			if not action_committed or (is_instance_valid(action_target) and action_target.is_in_group("trees")):
				cancel_action()
	if not action.is_empty():
		direction=Vector2.ZERO
		action_clock+=delta
		if not action_committed and action_clock>=.36:
			action_committed=true
			if action=="chop" and stream.tree_in_reach(position,action_target):
				stream.chop_tree(action_target)
			elif action=="pickup" and is_instance_valid(action_target) and position.distance_to(action_target.position)<52:
				stream.pickup_drop(action_target)
		var view := "side" if facing in ["left","right"] else facing
		var clip_name := view+"_"+action
		if action_clock>=animation_player.get_animation(clip_name).length:
			if action=="chop" and hold_chop and Input.is_action_pressed("interact") and stream.tree_in_reach(position,action_target):
				action_clock=0.0
				action_committed=false
			else:
				cancel_action()
	var wanted := direction*(RUN_SPEED if running else WALK_SPEED)
	var travel := wanted*delta
	blocked_by_loading=false
	var half_view := get_viewport_rect().size/(2.0*camera.zoom)
	if not stream.viewport_ready(position+travel,half_view):
		wanted=Vector2.ZERO
		blocked_by_loading=direction.length_squared()>.1
	elif not generator.can_walk(position+travel):
		# Slide along shores without tunnelling through the water or world border.
		if not generator.can_walk(position+Vector2(travel.x,0)): wanted.x=0
		if not generator.can_walk(position+Vector2(0,travel.y)): wanted.y=0
		if not generator.can_walk(position+wanted*delta): wanted=Vector2.ZERO
	velocity=wanted
	var previous := position
	move_and_slide()
	last_displacement=position-previous
	moving=last_displacement.length_squared()>.0001
	if direction.length_squared()>.1:
		if absf(direction.x)>=absf(direction.y): facing="right" if direction.x>0 else "left"
		else: facing="front" if direction.y>0 else "back"
	if moving:
		gait_distance+=last_displacement.length()
		idle_clock=0
	else:
		idle_clock+=delta
	update_animation()
	stream.update_target(position)

func update_animation() -> void:
	if actor.is_empty() or animation_player==null: return
	var next_action := action if not action.is_empty() else (("run" if running else "walk") if moving else "breathe")
	var view := "side" if facing in ["left","right"] else facing
	var animation := StringName("%s_%s"%[view,next_action]+("_link" if action=="chop" and chained_chop else ""))
	var clip := animation_player.get_animation(animation)
	var stride := float(actor.stride_world_units)
	var clock := action_clock if not action.is_empty() else (fposmod(gait_distance/stride,1.0)*clip.length if moving else fposmod(idle_clock,clip.length))
	# Preserve gait through turns; only post-collision travel advances walking.
	if animation_player.current_animation!=animation: animation_player.play(animation)
	animation_player.seek(clock,true)
	carried_wood.visible=action=="pickup" and action_committed and action_clock<.63
	carried_wood.modulate.a=clampf((.69-action_clock)/.10,0,1)
	var visual: Node2D=character.get_node("Visual")
	visual.scale.x=-1.0 if facing=="left" else 1.0
	visual.position.x=128.0 if facing=="left" else 0.0

func cancel_action() -> void:
	action=""
	action_target=null
	action_clock=0.0
	action_committed=false
	chained_chop=false
	hold_chop=false
	chop_buffer=0.0

func try_interact() -> void:
	if input_blocked: return
	if action=="chop":
		return
	if not action.is_empty() or blocked_by_loading: return
	var target := stream.interaction_target(position)
	if target==null: return
	var offset := target.position-position
	facing="left" if offset.x<0 else "right"
	action="pickup" if target.is_in_group("drops") else "chop"
	action_target=target
	hold_chop=action=="chop"
	action_clock=0.0
	chained_chop=false
	action_committed=false
	moving=false
	update_animation()

func _unhandled_input(event: InputEvent) -> void:
	if input_blocked: return
	if event.is_action_pressed("interact") and not event.is_echo():
		try_interact()
	if event is InputEventMouseButton and event.pressed:
		var factor := 1.0
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: factor=1.1
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: factor=1.0/1.1
		if factor!=1.0:
			camera.zoom=Vector2.ONE*clampf(camera.zoom.x*factor,.65,1.65)
