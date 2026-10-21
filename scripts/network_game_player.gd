extends "res://scripts/player.gd"
var pending_inputs: Array=[]
var input_id:=0
var confirmed_at:=0
var correction:=Vector2.ZERO
func _physics_process(delta: float) -> void:
	var previous:=position
	var world=get_parent().get_parent()
	var can_predict: bool=Time.get_ticks_msec()-confirmed_at<1500 and pending_inputs.size()<85 and not world.stopping
	if not can_predict:
		velocity=Vector2.ZERO;moving=false;running=false;update_animation();return
	super._physics_process(delta)
	var duration:=minf(delta,.05)
	var direction: Vector2=((position-previous)/((RUN_SPEED if running else WALK_SPEED)*maxf(duration,.001))).limit_length(1)
	if body.sleep_active():direction=Vector2.ZERO
	input_id+=1
	pending_inputs.append({"id":input_id,"dx":direction.x,"dy":direction.y,"run":running,"dt":duration})
	var adjustment:=correction*(1.0-exp(-16.0*delta))
	position+=adjustment;correction-=adjustment
func acknowledge(row: Dictionary, ack: int) -> void:
	while not pending_inputs.is_empty() and int(pending_inputs[0].id)<=ack:pending_inputs.pop_front()
	confirmed_at=Time.get_ticks_msec()
	var predicted:=Vector2(row.x,row.y)
	for item in pending_inputs:predicted+=Vector2(item.dx,item.dy)*(RUN_SPEED if item.run else WALK_SPEED)*item.dt
	correction=predicted-position
	if correction.length()>320:
		position=predicted;correction=Vector2.ZERO;reset_physics_interpolation()
