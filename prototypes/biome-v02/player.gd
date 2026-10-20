extends "res://scripts/player.gd"
var layout:RefCounted
func _physics_process(delta:float)->void:
	if input_blocked:return
	var direction=Input.get_vector("move_left","move_right","move_up","move_down") if not automated else input_override
	running=Input.is_action_pressed("run") if not automated else run_override
	var wanted=direction*(RUN_SPEED if running else WALK_SPEED)
	var travel=wanted*delta
	if not layout.can_walk(position+Vector2(travel.x,0)):wanted.x=0
	if not layout.can_walk(position+Vector2(0,travel.y)):wanted.y=0
	velocity=wanted
	var previous=position
	move_and_slide()
	last_displacement=position-previous
	moving=last_displacement.length_squared()>.0001
	if direction.length_squared()>.1:
		if absf(direction.x)>=absf(direction.y):facing="right" if direction.x>0 else "left"
		else:facing="front" if direction.y>0 else "back"
	if moving:gait_distance+=last_displacement.length();idle_clock=0
	else:idle_clock+=delta
	update_animation()
func try_interact()->void:
	pass
