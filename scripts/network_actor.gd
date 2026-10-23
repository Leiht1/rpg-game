extends "res://scripts/player.gd"
var target_position:=Vector2.ZERO
var own:=false
var network_equipment:Dictionary={}
var correction:=Vector2.ZERO
var confirmed_at:=0
var pending_inputs:Array=[]
var input_id:=0
var sample_time:=-1.0
var remote_velocity:=Vector2.ZERO
var remote_age:=0.0
var remote_motion_time:=-1.0
var combat_soul: Node2D
var remote_hit_serial:=-1
var remote_flash:=0.0
var sleep_cover=preload("res://scripts/sleep_head_cover.gd").new()
var sleep_symbols: Label
func _ready()->void:
	remote_presentation=true
	super._ready()
	# Remote interpolated poses are presentation only. Their local colliders
	# otherwise push the predicted player without a matching server movement.
	collision_layer=0
	collision_mask=0
func _physics_process(delta:float)->void:
	if not remote_combat.get("attack",{}).is_empty():remote_combat.attack.elapsed=float(remote_combat.attack.elapsed)+delta
	if remote_combat.get("phase","alive")!="alive":remote_combat.clock=float(remote_combat.get("clock",0))+delta
	var previous:=position
	if own:
		var world:=objects_world()
		var direction:Vector2=world.movement_direction()
		var outstanding:=0.0
		for item in pending_inputs:outstanding+=float(item.dt)
		var can_predict:=Time.get_ticks_msec()-confirmed_at<=1000 and outstanding<1.48
		if not can_predict:direction=Vector2.ZERO
		running=not direction.is_zero_approx() and Input.is_action_pressed("run")
		moving=not direction.is_zero_approx()
		if moving:facing=("right" if direction.x>0 else "left") if absf(direction.x)>absf(direction.y) else ("front" if direction.y>0 else "back")
		var duration:=minf(delta,.05)
		if can_predict and pending_inputs.size()<90:
			input_id+=1
			pending_inputs.append({"id":input_id,"dx":direction.x,"dy":direction.y,"run":running,"dt":duration})
			position+=direction*(RUN_SPEED if running else WALK_SPEED)*duration
		var adjustment:=correction*(1.0-exp(-16.0*delta))
		position+=adjustment;correction-=adjustment

	else:
		remote_age+=delta
		var destination:=target_position+remote_velocity*minf(remote_age,.2)
		var adjustment:Vector2=(destination-position)*(1.0-exp(-16.0*delta))
		position+=adjustment.limit_length((RUN_SPEED if running else WALK_SPEED)*1.5*delta)
	gait_distance+=position.distance_to(previous)
	idle_clock+=delta
	update_animation()
	if remote_combat.get("phase","alive")=="dying":
		if not is_instance_valid(combat_soul):combat_soul=preload("res://scripts/combat_world_view.gd").Soul.new();add_child(combat_soul)
		combat_soul.position=Vector2(14,-12-float(remote_combat.get("clock",0))*28);combat_soul.modulate.a=sin(clampf(float(remote_combat.get("clock",0))/3,0,1)*PI)
		character.modulate=Color.WHITE
	else:
		if is_instance_valid(combat_soul):combat_soul.queue_free()
		remote_flash=maxf(0,remote_flash-delta)
		character.modulate=(Color(1,.55,.55) if int(remote_flash*35)%2 else Color.WHITE) if remote_flash>0 else Color.WHITE
	if not own and body!=null and body.sleep_active() and not body.sleep_session.is_empty():
		var world=objects_world()
		var anchor: Vector2=sleep_cover.render(self,body.sleep_session,world.item_service.builds)
		if not is_instance_valid(sleep_symbols):sleep_symbols=Label.new();sleep_symbols.text="z  z  z";add_child(sleep_symbols)
		sleep_symbols.show();sleep_symbols.position=anchor+Vector2(-12,-38+sin(idle_clock*1.5)*2)
	elif is_instance_valid(sleep_symbols):sleep_symbols.hide()
func _unhandled_input(event:InputEvent)->void:
	if own:zoom_from_wheel(event)
func objects_world()->Node:
	return get_parent().get_parent()
func receive(row:Dictionary,reconcile:bool=true,round_trip:float=0.0)->void:
	if not own and row.has("sample_time"):
		if float(row.sample_time)<sample_time:return
		sample_time=float(row.sample_time)
	var old_phase:=str(remote_combat.get("phase","alive"))
	remote_combat=row.get("combat",{}).duplicate(true)
	if remote_hit_serial>=0 and remote_hit_serial!=int(remote_combat.get("hit_serial",0)):remote_flash=.3
	remote_hit_serial=int(remote_combat.get("hit_serial",0))
	if reconcile:
		if not own:
			var next:=Vector2(row.x,row.y)
			if old_phase!=str(remote_combat.get("phase","alive")) and remote_combat.get("phase")=="entering":
				position=next;target_position=next;remote_velocity=Vector2.ZERO;reset_physics_interpolation()
			var clock:float=float(row.get("sample_time",Time.get_ticks_msec()/1000.0))
			if not bool(row.moving):remote_velocity=Vector2.ZERO;remote_age=0.0
			elif next!=target_position:
				remote_velocity=((next-target_position)/maxf(.016,clock-remote_motion_time)).limit_length(RUN_SPEED if bool(row.running) else WALK_SPEED) if remote_motion_time>=0 else Vector2.ZERO
				remote_age=0.0
			if next!=target_position or not bool(row.moving):remote_motion_time=clock
		target_position=Vector2(row.x,row.y);confirmed_at=Time.get_ticks_msec()
		if own:
			var predicted:=target_position
			for item in pending_inputs:
				predicted+=Vector2(item.dx,item.dy)*(RUN_SPEED if item.run else WALK_SPEED)*item.dt
			correction=predicted-position
			if correction.length()>320.0:position=predicted;correction=Vector2.ZERO;reset_physics_interpolation()
		else:facing=row.facing;moving=row.moving;running=row.running
	character_look=row.appearance
	if row.has("visual_body"):
		if body==null:body=preload("res://scripts/body_state.gd").new()
		body.build=float(row.visual_body.get("build",50));body.sleeping=bool(row.visual_body.get("sleeping",false));body.sleep_session=row.visual_body.get("sleep_session",{}).duplicate(true)
		var pose: Dictionary=row.get("pose",{})
		action=str(pose.get("action",""));action_clock=float(pose.get("clock",0))
		if pose.has("facing"):facing=pose.facing
	if equipment_inventory==null or row.get("equipment",{})!=network_equipment:
		network_equipment=row.get("equipment",{}).duplicate(true)
		var db:=preload("res://scripts/item_database.gd").new()
		preload("res://scripts/character_catalog.gd").enable_candidate(db)
		equipment_inventory=preload("res://scripts/item_inventory.gd").new(db)
		equipment_inventory.restore_equipment(network_equipment)

func acknowledge(row:Dictionary,ack:int)->void:
	while not pending_inputs.is_empty() and int(pending_inputs[0].id)<=ack:pending_inputs.pop_front()
	receive(row)
