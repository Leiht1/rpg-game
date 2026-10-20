class_name WildPlayer
extends CharacterBody2D

const Interaction = preload("res://scripts/world_interaction.gd")
var appearance := preload("res://scripts/equipment_appearance.gd").new()
var character_look: Dictionary={}
var look_renderer := preload("res://scripts/character_look.gd").new()
var equipment_inventory: ItemInventory
var held_tool := preload("res://scripts/held_tool.gd").new()
var animal_feed := preload("res://scripts/animal_feed.gd").new()
var camp_throw := preload("res://scripts/campfire_throw.gd").new()

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
var body: RefCounted
var chop_buffer := 0.0
var chained_chop := false
var hold_chop := false
var action := ""
var action_clock := 0.0
var action_target: Node2D
var action_committed := false
var action_contact := false
var action_succeeded := false
var harvesting := false
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
	# Interpolate the body and native rig together between physics ticks.
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
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
	if body!=null: preload("res://scripts/body_shape.gd").apply(character,body.build)
	carried_wood.visible=false
	character.get_node("Visual/Pelvis/ArmR/Grip").add_child(carried_wood)
	animation_player=character.get_node("AnimationPlayer")
	animation_player.add_animation_library("harvest",load("res://assets/hero/cartoon/harvest_actions.tres"))
	animation_player.add_animation_library("camp",load("res://assets/hero/cartoon/campfire_throw.tres"))
	animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	camera.process_callback=Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position_smoothing_enabled=true
	camera.position_smoothing_speed=7.0
	camera.limit_left=0
	camera.limit_top=0
	camera.limit_right=roundi(generator.extent)
	camera.limit_bottom=roundi(generator.extent)
	add_child(camera)
	update_animation()

func set_equipment(inventory: ItemInventory) -> void:
	equipment_inventory=inventory
	appearance.apply(character,inventory,facing)
	if not action.is_empty() and not action_committed and (not is_instance_valid(action_target) or not Interaction.allowed(inventory,Interaction.action_for(action_target))): cancel_action()
	update_animation()

func selected_target() -> Node2D:
	return stream.interaction_target(position,facing,get_global_mouse_position())

func _draw() -> void:
	draw_discomfort()
	if body!=null and body.sleep_active(): return
	draw_set_transform(Vector2(0,-2),0,Vector2(1,.35))
	draw_circle(Vector2.ZERO,16,Color(.17,.23,.16,.19))

func _physics_process(delta: float) -> void:
	if action=="feed":
		velocity=Vector2.ZERO;last_displacement=Vector2.ZERO
		animal_feed.advance(delta);update_animation()
		return
	if action=="throw":
		velocity=Vector2.ZERO;last_displacement=Vector2.ZERO
		camp_throw.advance(delta);update_animation()
		return
	if body!=null and (body.down or body.sleep_active()):
		cancel_action()
		moving=false
		running=false
		update_animation()
	if input_blocked or (body!=null and (body.down or body.sleep_active())):
		velocity=Vector2.ZERO
		last_displacement=Vector2.ZERO
		return
	chop_buffer=maxf(0.0,chop_buffer-delta)
	var direction := input_override if automated else Input.get_vector("move_left","move_right","move_up","move_down")
	direction=direction.limit_length(1.0)
	running=run_override if automated else Input.is_action_pressed("run")
	if body!=null and body.exhausted: running=false
	if action in ["chop","mine","dig","demolish"]:
		if not Input.is_action_pressed("interact"): hold_chop=false
		if action=="chop" and not stream.tree_in_reach(position,action_target):
			hold_chop=false
			if not action_committed or (is_instance_valid(action_target) and action_target.is_in_group("trees")):
				cancel_action()
	if action in ["mine","dig","demolish"] and not action_committed and (not is_instance_valid(action_target) or not Interaction.in_reach(stream,position,action_target)):
		cancel_action()
	if not action.is_empty():
		direction=Vector2.ZERO
		if action_clock==0.0 and action in ["chop","mine","dig","demolish"]:AudioFX.play_sfx("sfx_tool_swing",position)
		action_clock+=delta*(equipment_inventory.labor_speed() if equipment_inventory!=null and action in ["chop","mine","dig","demolish"] else 1.0)*(body.efficiency() if body!=null and action in ["chop","mine","dig","demolish"] else 1.0)
		if action=="dig" and not action_contact and action_clock>=.43:
			action_contact=true
			if Interaction.in_reach(stream,position,action_target) and Interaction.allowed(equipment_inventory,"dig"):
				action_target.contact_feedback(position)
		if not action_committed and action_clock>=(.55 if action in ["mine","demolish"] else .68 if action=="dig" else .48 if harvesting else .36):
			action_committed=true
			action_succeeded=Interaction.execute(stream,self,action_target)
			if action_succeeded and action in ["mine","dig"]:
				AudioFX.play_sfx("sfx_mine_hit" if action=="mine" else "sfx_dig_soil",position)
		var view := "side" if facing in ["left","right"] else facing
		var clip_name := ("harvest/" if action in ["mine","dig","demolish"] else "")+view+"_"+("mine" if action=="demolish" else action)
		if action=="fertilize":clip_name=view+"_pickup"
		if action=="shear":clip_name="camp/"+view+"_throw_right"
		if action_clock>=animation_player.get_animation(clip_name).length:
			if action in ["chop","mine","dig","demolish"] and action_succeeded and hold_chop and Input.is_action_pressed("interact") and is_instance_valid(action_target) and Interaction.in_reach(stream,position,action_target) and Interaction.allowed(equipment_inventory,action) and (body==null or body.can_labor(action)):
				action_clock=0.0
				action_committed=false
				action_contact=false
			else:
				cancel_action()
	var wanted: Vector2 = direction*(RUN_SPEED if running else WALK_SPEED)*(body.efficiency() if body!=null else 1.0)
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
	if body!=null:
		body.discomfort=maxf(0,body.discomfort-get_physics_process_delta_time())
		queue_redraw()
	if actor.is_empty() or animation_player==null: return
	held_tool.release_pose()
	if body!=null and not body.sleep_session.is_empty():
		# Sleeping body is concealed; the current side head is displayed separately.
		var still := get_node_or_null("SleepHeadCover")
		character.visible=not is_instance_valid(still) or not still.visible
		held_tool.apply(character,null,"right","pickup");carried_wood.hide()
		return
	character.show()
	for name_value in ["SleepCover","SleepStill","SleepHeadCover"]:
		var resting := get_node_or_null(name_value)
		if resting: resting.hide()
	character.position=-ANCHOR
	var next_action := action if not action.is_empty() else (("run" if running else "walk") if moving else "breathe")
	var view := "side" if facing in ["left","right"] else facing
	var animation := StringName(("harvest/" if action in ["mine","dig","demolish"] else "")+"%s_%s"%[view,"mine" if next_action=="demolish" else next_action]+("_link" if action=="chop" and chained_chop else ""))
	if view=="back" and action in ["chop","mine","dig","demolish"]: animation=&"harvest/back_mine"
	if action=="fertilize": animation=StringName(view+"_pickup")
	if action=="shear": animation=StringName("camp/%s_throw_right"%view)
	if action=="feed": animation=StringName("camp/%s_throw_%s"%[view,animal_feed.hand])
	if action=="throw": animation=StringName("camp/%s_throw_%s"%[view,camp_throw.hand])
	var clip := animation_player.get_animation(animation)
	var stride := float(actor.stride_world_units)
	var clock := action_clock if not action.is_empty() else (fposmod(gait_distance/stride,1.0)*clip.length if moving else fposmod(idle_clock,clip.length))
	if view=="back" and action in ["chop","dig"]:
		# Share the hammer's native pose, preserving each original action's hit and end time.
		var logical: Animation=animation_player.get_animation("back_chop" if action=="chop" else "harvest/back_dig")
		var contact := .36 if action=="chop" else .68
		clock=action_clock*.55/contact if action_clock<=contact else .55+(action_clock-contact)*(clip.length-.55)/(logical.length-contact)
	# Preserve gait through turns; only post-collision travel advances walking.
	if animation_player.current_animation!=animation: animation_player.play(animation)
	animation_player.seek(clock,true)
	appearance.apply(character,equipment_inventory,facing)
	look_renderer.apply(character,character_look,equipment_inventory,facing)
	held_tool.apply(character,equipment_inventory,facing,"" if action in ["throw","feed","fertilize"] else action)
	if body!=null: preload("res://scripts/body_shape.gd").apply(character,body.build)
	carried_wood.visible=action=="pickup" and action_succeeded and not harvesting and carried_wood.texture!=null and action_clock<.63
	carried_wood.modulate.a=clampf((.69-action_clock)/.10,0,1)
	var visual: Node2D=character.get_node("Visual")
	var mirror_scale:float=-1.0 if facing=="left" else 1.0
	if visual.scale.x!=mirror_scale:
		visual.scale.x=mirror_scale
		visual.position.x=128.0 if facing=="left" else 0.0
		# A facing flip is instantaneous, not a scale tween through zero width.
		visual.reset_physics_interpolation()
	if action in ["mine","dig","demolish"] and facing in ["left","right"] and is_instance_valid(action_target):
		held_tool.show_strike_in_front(character,get_parent(),action_target)
	if action=="throw": camp_throw.render()
	if action=="feed": animal_feed.render()


func _exit_tree() -> void:
	animal_feed.cancel()
	camp_throw.cancel()
	held_tool.clear_strike_layer()

func cancel_action() -> void:
	animal_feed.cancel()
	camp_throw.cancel()
	held_tool.release_pose()
	action=""
	action_target=null
	action_clock=0.0
	action_committed=false
	action_contact=false
	action_succeeded=false
	harvesting=false
	chained_chop=false
	hold_chop=false
	chop_buffer=0.0

func try_interact() -> void:
	if input_blocked or (body!=null and (body.down or body.sleep_active() or body.energy<=0)): return
	if action=="chop":
		return
	if not action.is_empty() or blocked_by_loading: return
	var target := selected_target()
	if target==null: return
	var requested := Interaction.action_for(target)
	if requested in ["chop","mine","dig","demolish"] and body!=null and not body.can_labor(requested):
		stream.items.notice.emit("体力不足，休息片刻再试")
		return
	if not Interaction.allowed(equipment_inventory,requested):
		if stream.items: stream.items.notice.emit(Interaction.caption(target,equipment_inventory))
		return
	if requested in ["animal","sow","cook","open","talk","inspect","sleep"]:
		Interaction.execute(stream,self,target)
		return
	var offset := target.position-position
	if requested in ["chop","mine","dig","demolish"]:
		facing=("right" if offset.x>0 else "left") if absf(offset.x)>=absf(offset.y) else ("front" if offset.y>0 else "back")
	else: facing="left" if offset.x<0 else "right"
	action=requested
	harvesting=action=="pickup" and (target.get_meta("mode","pickup")=="harvest" or target.get_meta("planting_soil",false))
	if target.get_meta("planting_soil",false) and action=="pickup":
		var crop: String=stream.items.builds.states[target.building_id].crop
		target.set_meta("item_id",stream.items.planting.rules.crops[crop].produce)
	action_succeeded=false
	if action=="pickup" and stream.items:
		carried_wood.texture=stream.items.texture(str(target.get_meta("item_id","wood")),"icon")
		if carried_wood.texture: carried_wood.scale=Vector2.ONE*22.0/maxf(carried_wood.texture.get_width(),carried_wood.texture.get_height())
	action_target=target
	hold_chop=action=="demolish" or (action in ["chop","mine","dig"] and not target.get_meta("planting_soil",false))
	action_clock=0.0
	chained_chop=false
	action_committed=false
	action_contact=false
	moving=false
	update_animation()

func _unhandled_input(event: InputEvent) -> void:
	if input_blocked or (body!=null and (body.down or body.sleep_active() or body.energy<=0)): return
	if event.is_action_pressed("interact") and not event.is_echo():
		try_interact()
	zoom_from_wheel(event)

func zoom_from_wheel(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed:
		var factor := 1.0
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: factor=1.1
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: factor=1.0/1.1
		if factor!=1.0:
			camera.zoom=Vector2.ONE*clampf(camera.zoom.x*factor,.65,1.65)
			return true
	return false

func draw_discomfort() -> void:
	if body==null or body.discomfort<=0 or not action.is_empty() or body.sleep_active():return
	# Small sweat marks use no pose or input overrides.
	var offset := Vector2(12,-88)
	draw_circle(offset+Vector2(0,sin(body.discomfort*6)*2),2.0,Color(.4,.72,.9,.9))
	draw_circle(offset+Vector2(5,-5),1.3,Color(.4,.72,.9,.8))
