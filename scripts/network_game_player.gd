extends "res://scripts/player.gd"
var pending_inputs: Array=[]
var input_id:=0
var sent_input_id:=0
var confirmed_at:=0
var acknowledged_input_id:=0
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
	record_input(direction,duration,running)
	var adjustment:=correction*(1.0-exp(-16.0*delta))
	position+=adjustment;correction-=adjustment
func record_input(direction: Vector2, duration: float, run: bool) -> void:
	# Only unsent inputs may merge: an in-flight ID must remain immutable.
	if not pending_inputs.is_empty():
		var last: Dictionary=pending_inputs[-1]
		if int(last.id)>sent_input_id and last.run==run and Vector2(last.dx,last.dy).is_equal_approx(direction) and float(last.dt)+duration<=.05:
			last.dt=float(last.dt)+duration
			return
	input_id+=1
	pending_inputs.append({"id":input_id,"dx":direction.x,"dy":direction.y,"run":run,"dt":duration})
func movement_batch(limit_id: int=-1) -> Array:
	var result: Array=[]
	var duration:=0.0
	for item in pending_inputs:
		if limit_id>=0 and int(item.id)>limit_id:break
		if duration+float(item.dt)>1.0:break
		result.append(item.duplicate(true));duration+=float(item.dt)
	if not result.is_empty():sent_input_id=maxi(sent_input_id,int(result[-1].id))
	return result
func acknowledge(row: Dictionary, ack: int) -> void:
	# Independent movement and interaction connections may complete out of order.
	if ack<acknowledged_input_id:return
	acknowledged_input_id=maxi(acknowledged_input_id,ack)
	while not pending_inputs.is_empty() and int(pending_inputs[0].id)<=ack:pending_inputs.pop_front()
	confirmed_at=Time.get_ticks_msec()
	var predicted:=Vector2(row.x,row.y)
	for item in pending_inputs:predicted+=Vector2(item.dx,item.dy)*(RUN_SPEED if item.run else WALK_SPEED)*item.dt
	correction=predicted-position
	if correction.length()>320:
		position=predicted;correction=Vector2.ZERO;reset_physics_interpolation()
