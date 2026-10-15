class_name WildPlayer
extends CharacterBody2D

const WALK_SPEED := 115.0
const CANVAS := 128
const ANCHOR := Vector2(64,112)
var stream: WildStream
var generator: WildGenerator
var facing := "front"
var moving := false
var gait_distance := 0.0
var idle_clock := 0.0
var animation_frame := 0
var sprite := AnimatedSprite2D.new()
var actor: Dictionary
var camera := Camera2D.new()
var input_override := Vector2.ZERO
var automated := false
var blocked_by_loading := false
var last_displacement := Vector2.ZERO

func _ready() -> void:
	actor=JSON.parse_string(FileAccess.get_file_as_string("res://assets/hero/animation/runtime.json"))
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius=10
	collider.shape=circle
	add_child(collider)
	sprite.name="CompleteCharacter"
	sprite.sprite_frames=load("res://assets/hero/animation/hero.tres")
	sprite.centered=true
	sprite.offset=Vector2(CANVAS/2,CANVAS/2)-ANCHOR
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
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
	var direction := input_override if automated else Input.get_vector("move_left","move_right","move_up","move_down")
	direction=direction.limit_length(1.0)
	var wanted := direction*WALK_SPEED
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
	if actor.is_empty(): return
	var action := "walk" if moving else "idle"
	var view := "side" if facing in ["left","right"] else facing
	var animation := StringName("%s_%s"%[view,action])
	var count := sprite.sprite_frames.get_frame_count(animation)
	if moving:
		animation_frame=int(gait_distance/float(actor.stride_world_units)*count)%count
	else:
		# SpriteFrames stores relative frame durations, not necessarily one unit per pose.
		var cycle_units := 0.0
		for i in count: cycle_units+=sprite.sprite_frames.get_frame_duration(animation,i)
		var elapsed_units := fposmod(idle_clock*sprite.sprite_frames.get_animation_speed(animation),cycle_units)
		animation_frame=count-1
		for i in count:
			elapsed_units-=sprite.sprite_frames.get_frame_duration(animation,i)
			if elapsed_units<0:
				animation_frame=i
				break
	# Keep gait phase through turns. Actual travel after collision is the only walk clock.
	sprite.animation=animation
	sprite.frame=animation_frame
	sprite.flip_h=facing=="left"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var factor := 1.0
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: factor=1.1
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: factor=1.0/1.1
		if factor!=1.0:
			camera.zoom=Vector2.ONE*clampf(camera.zoom.x*factor,.65,1.65)
