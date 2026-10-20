extends Node2D
## Approved fishing V1. Uses the existing inventory, atomic save and side-view rig.
const ItemSkin = preload("res://scripts/item_ui_style.gd")
const FISH_ID := "lake_fish"
const COIN_ID := "gold_coin"
const CHEST_ID := "locked_chest"
const COIN_CHANCE := .01
const CHEST_CHANCE := .005
const CAST_TIME := .85
const BITE_TIME := .65
const ROUND_TIME := 4.5
const SUCCESS_TIME := 1.85
const INTERACT_RANGE := 175.0
var world: Node2D
var player: WildPlayer
var service: Node
var spots: Array[Dictionary]=[]
var state := "idle"
var clock := 0.0
var ambient_clock := 0.0
var wait_time := 2.8
var hits := 0
var misses := 0
var round_clock := 0.0
var input_cooldown := 0.0
var marker_phase := 0.0
var selected := -1
var held_instance := ""
var reward_committed := false
var reward_count := 0
var phase_history: Array[String]=[]
var splashes: Array[Dictionary]=[]
var rng := RandomNumberGenerator.new()
var loot_rng := RandomNumberGenerator.new()
var catch_id := FISH_ID
var catch_textures: Dictionary={}
var rod: Sprite2D
var registration: Dictionary
var poses: Dictionary
var line_points := PackedVector2Array()
var bobber_position := Vector2.ZERO
var fish_texture: Texture2D
var float_texture: Texture2D
var layer := CanvasLayer.new()
var blocker := Control.new()
var game := PanelContainer.new()
var game_title := Label.new()
var game_score := Label.new()
var bar := preload("res://scripts/fishing_timing_bar.gd").new()
var status_panel := PanelContainer.new()
var status_text := Label.new()
var target_panel := PanelContainer.new()
var target_text := Label.new()
var bite_mark := Label.new()
var message_remaining := 0.0
var message := ""

func configure(owner_world: Node2D, shore_spots: Array[Dictionary]) -> void:
	world=owner_world;player=world.player;service=world.item_service;spots=shore_spots
	registration=JSON.parse_string(FileAccess.get_file_as_string("res://data/fishing_registration.json"))
	poses=JSON.parse_string(FileAccess.get_file_as_string("res://data/fishing_side_poses.json"))
	fish_texture=load("res://assets/fishing/v1/fish.res")
	float_texture=load("res://assets/fishing/v1/float.res")
	rng.randomize();loot_rng.randomize()
	catch_textures={FISH_ID:fish_texture,COIN_ID:load("res://assets/fishing/v1/coin.res"),CHEST_ID:load("res://assets/fishing/v1/locked_chest.res")}
	build_ui()
	phase_history.append("idle")

func build_ui() -> void:
	layer.layer=25;add_child(layer)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter=Control.MOUSE_FILTER_STOP;layer.add_child(blocker);blocker.hide()
	for panel in [game,status_panel,target_panel]:
		panel.theme=ItemSkin.theme();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel",ItemSkin.section(12));layer.add_child(panel)
	var box := VBoxContainer.new();game.add_child(box)
	box.add_theme_constant_override("separation",7)
	for control in [game_title,bar,game_score]: box.add_child(control)
	game_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	game_title.add_theme_font_size_override("font_size",18)
	game_score.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	game_score.add_theme_font_size_override("font_size",15)
	game.custom_minimum_size=Vector2(356,115)
	status_panel.add_child(status_text);status_text.add_theme_font_size_override("font_size",16)
	target_panel.add_child(target_text);target_text.text="E  钓鱼"
	for control in [box,game_title,bar,game_score,status_text,target_text]: control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bite_mark.text="!";bite_mark.add_theme_font_size_override("font_size",44)
	bite_mark.add_theme_color_override("font_color",Color("fff1b3"))
	bite_mark.add_theme_color_override("font_outline_color",Color("69523b"))
	bite_mark.add_theme_constant_override("outline_size",7)
	bite_mark.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(bite_mark)
	game.hide();bite_mark.hide();target_panel.hide()

func nearest_spot() -> int:
	var best := -1
	var distance := INTERACT_RANGE
	for i in spots.size():
		var spot: Dictionary=spots[i]
		if int(spot.get("remaining",6))<=0: continue
		var d := player.position.distance_to(spot.water)
		if d<distance and player.position.distance_to(spot.stand)<90 and world.generator.can_walk(player.position) and world.stream.clear_reach(player.position,spot.water):
			best=i;distance=d
	return best

func ui_open() -> bool:
	return service.storage_ui.panel.visible or service.industry_ui.visible or service.planting_ui.visible or world.map_view.visible or world.item_ui.bag.visible or world.item_ui.catalog.visible or world.item_ui.craft_panel.visible or world.item_ui.item_modal_open() or world.camp_ui.panel.visible or service.body.sleep_active() or get_viewport().gui_is_dragging() or get_viewport().gui_get_focus_owner() is LineEdit

func try_start() -> bool:
	if state!="idle" or ui_open() or not player.action.is_empty() or service.body.down: return false
	if not service.writable or not service.inventory.has_capability("fishing_ready"): return false
	var index := nearest_spot()
	if index<0: return false
	selected=index;held_instance=str(service.inventory.equipment.main_hand.instance_id)
	hits=0;misses=0;reward_committed=false
	catch_id=catch_for_roll(loot_rng.randf())
	player.cancel_action();player.moving=false;player.running=false;player.velocity=Vector2.ZERO
	player.facing="right" if spots[index].water.x>=player.position.x else "left"
	player.set_physics_process(false);player.input_blocked=true
	player.character.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	world.item_ui.hide_item_hover();world.item_ui.target_tip.hide()
	blocker.show()
	wait_time=rng.randf_range(2.4,4.0)
	transition("cast");pose()
	return true

func transition(next: String) -> void:
	state=next;clock=0;phase_history.append(next)
	if next=="cast":AudioFX.play_sfx("sfx_fishing_cast",player.position)
	if next=="bite":AudioFX.play_sfx("sfx_fishing_bite",player.position)
	if next=="wait": splash(spots[selected].water,.75)
	if next=="bite": splash(spots[selected].water,.45)
	if next=="game":
		round_clock=0;marker_phase=0;input_cooldown=.22
		randomize_safe_zone()
	if next=="success": splash(spots[selected].water,1.3)
	if next=="failure": message="鱼游走了";message_remaining=2.0

func advance(delta: float) -> void:
	ambient_clock+=delta
	message_remaining=maxf(0,message_remaining-delta)
	for drop in splashes: drop.age+=delta
	splashes=splashes.filter(func(drop: Dictionary): return drop.age<.65)
	if state=="idle": return
	# Re-check the exact equipment instance throughout, including just before reward.
	if not valid_session(): finish("钓鱼已取消");return
	clock+=delta
	if state=="cast" and clock>=CAST_TIME: transition("wait")
	elif state=="wait" and clock>=wait_time: transition("bite")
	elif state=="bite" and clock>=BITE_TIME: transition("game")
	elif state=="game":
		input_cooldown=maxf(0,input_cooldown-delta)
		round_clock+=delta;marker_phase+=delta*.72
		bar.marker=pingpong(marker_phase,1.0)
		bar.feedback=maxf(0,bar.feedback-delta)
		if round_clock>=ROUND_TIME: resolve_attempt(false)
	elif state=="success":
		if clock>=1.15 and not reward_committed: commit_reward()
		if clock>=SUCCESS_TIME: finish("")
	elif state=="failure" and clock>=.7: finish(message)

func valid_session() -> bool:
	var held: Dictionary=service.inventory.equipment.main_hand
	return (int(spots[selected].get("remaining",6))>0 or (state=="success" and reward_committed)) and not held.is_empty() and str(held.get("instance_id",""))==held_instance and service.inventory.has_capability("fishing_ready") and not service.body.down and not service.body.sleep_active() and player.position.distance_to(spots[selected].stand)<100

func judge() -> void:
	if state!="game" or input_cooldown>0: return
	resolve_attempt(bar.is_hit())

func resolve_attempt(hit: bool) -> void:
	if hit:
		hits+=1;bar.feedback=.3
		message="稳住了！";message_remaining=.7
	else:
		misses+=1;message="偏了一点";message_remaining=.7
	if hits>=2: transition("success");return
	if misses>=3: transition("failure");return
	randomize_safe_zone()
	# Reset each round so rapid key repeats cannot count as two catches.
	marker_phase=0;bar.marker=0;round_clock=0;input_cooldown=.28

func randomize_safe_zone() -> void:
	var previous := bar.safe_center
	var next := rng.randf_range(.16,.84)
	# Uniformly choose a new legal position outside a small neighbourhood.
	for attempt in 16:
		if absf(next-previous)>=.12: break
		next=rng.randf_range(.16,.84)
	if absf(next-previous)<.12: next=.16 if previous>.5 else .84
	bar.safe_center=next

func catch_for_roll(value: float) -> String:
	if value<CHEST_CHANCE: return CHEST_ID
	if value<CHEST_CHANCE+COIN_CHANCE: return COIN_ID
	return FISH_ID

func commit_reward() -> void:
	if reward_committed or state!="success" or not valid_session(): return
	reward_committed=true
	var before: Array[Dictionary]=service.inventory.slots.duplicate(true)
	var previous_dirty: bool=service.dirty
	var population_before: Dictionary=service.fishing_population.serialize()
	if service.inventory.add(catch_id,1)==0:
		if catch_id==FISH_ID: service.fishing_population.consume(selected)
		service.dirty=true
		if service.save_state():
			reward_count+=1
			service.item_obtained.emit(catch_id,1)
			message="钓到了一条湖鱼！" if catch_id==FISH_ID else "钓到了"+str(service.database.item(catch_id).name)+"！"
		else:
			service.fishing_population.restore(population_before)
			service.inventory.slots=before;service.dirty=previous_dirty
			service.inventory.changed.emit()
			service.dirty=previous_dirty
			message="保存失败，本次收获未领取"
	else: message="背包已满，收获放回湖里了"
	message_remaining=2.4

func finish(text: String) -> void:
	if state=="idle": return
	if not text.is_empty(): message=text;message_remaining=2.2
	state="idle";clock=0;phase_history.append("idle")
	line_points.clear();blocker.hide();game.hide();bite_mark.hide()
	player.held_tool.release_pose()
	player.input_blocked=false;player.set_physics_process(true)
	player.character.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	player.update_animation();player.reset_physics_interpolation()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_processing() and is_instance_valid(player) and state!="idle": finish("钓鱼已取消")

func _exit_tree() -> void:
	if is_instance_valid(player) and state!="idle": finish("")

func _input(event: InputEvent) -> void:
	if not is_instance_valid(player): return
	if state!="idle":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode==KEY_ESCAPE: finish("钓鱼已取消")
			elif event.physical_keycode==KEY_SPACE: judge()
		if event is InputEventMouseButton: player.zoom_from_wheel(event)
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode==KEY_E and try_start(): get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if not is_instance_valid(world): return
	advance(delta)
	if state!="idle":
		player.input_blocked=true;pose();update_line()
	update_ui();queue_redraw()

func pose() -> void:
	# Reset to the approved side rig before each sample: joint offsets never accumulate.
	player.update_animation()
	var key := "wait" if state in ["wait","bite","game"] else state
	var keys: Array=poses.get(key,poses.wait)
	var values: Array=keys.back().duplicate()
	for i in range(keys.size()-1):
		if clock<=float(keys[i+1][0]):
			var a: Array=keys[i];var b: Array=keys[i+1]
			var t := smoothstep(float(a[0]),float(b[0]),clock)
			values=[]
			for k in 5: values.append(lerpf(float(a[k]),float(b[k]),t))
			break
	var pelvis: Node2D=player.character.get_node("Visual/Pelvis")
	var arm: Node2D=pelvis.get_node("ArmR")
	player.held_tool.release_pose()
	pelvis.rotation=deg_to_rad(values[1]);arm.rotation=deg_to_rad(values[2])
	pelvis.get_node("ArmL").rotation=deg_to_rad(values[3])
	rod=arm.get_node("HeldTool")
	var grip := Vector2(registration.grip_px[0],registration.grip_px[1])
	var tip := Vector2(registration.tip_px[0],registration.tip_px[1])
	rod.rotation=deg_to_rad(values[4])-(tip-grip).angle()-arm.rotation-pelvis.rotation
	rod.show()

func rod_tip() -> Vector2:
	return rod.to_global(rod.offset+Vector2(registration.tip_px[0],registration.tip_px[1]))

func update_line() -> void:
	line_points.clear()
	if state=="cast" or selected<0: return
	var at: Vector2=spots[selected].water
	bobber_position=at+Vector2(0,sin(ambient_clock*2.5)*.9)
	var endpoint := bobber_position+Vector2(0,-9)
	if state in ["bite","game"]: endpoint=at+Vector2(0,2)
	if state=="success":
		endpoint=jumping_fish_position()
		if clock>1.15: return
	if state=="failure": return
	var tip := rod_tip()
	# Stable shallow sag; exact end points follow the native rod and float every frame.
	for i in 13:
		var t := float(i)/12
		line_points.append(tip.lerp(endpoint,t)+Vector2(0,sin(t*PI)*6))

func jumping_fish_position() -> Vector2:
	var t := clampf((clock-.16)/.95,0,1)
	var destination := player.position+Vector2(24 if player.facing=="right" else -24,-36)
	return Vector2(spots[selected].water).lerp(destination,t)+Vector2(0,-sin(t*PI)*88)

func update_ui() -> void:
	var area := get_viewport_rect().size
	game.visible=state=="game"
	game.position=Vector2((area.x-356)*.5,area.y-250)
	game_title.text="圆点进入绿色区域时按 Space"
	game_score.text="命中 %d / 2    ·    失误 %d / 3"%[hits,misses]
	bar.queue_redraw()
	var captions := {"cast":"抛竿…","wait":"静候咬钩…","bite":"咬钩了！准备按 Space","game":"Esc 取消","success":"提竿！","failure":"鱼游走了"}
	status_panel.visible=state!="idle" or message_remaining>0
	status_text.text=captions.get(state,"")
	if message_remaining>0 and state in ["idle","game"]: status_text.text=message
	status_panel.reset_size()
	status_panel.position=Vector2((area.x-status_panel.size.x)*.5,88)
	var nearest := nearest_spot() if state=="idle" and not ui_open() and service.inventory.has_capability("fishing_ready") else -1
	target_panel.visible=nearest>=0
	if nearest>=0:
		target_panel.reset_size()
		target_panel.position=get_viewport().get_canvas_transform()*Vector2(spots[nearest].water)+Vector2(-40,27)
	bite_mark.visible=state=="bite" or (state=="game" and clock<.55)
	if bite_mark.visible: bite_mark.position=get_viewport().get_canvas_transform()*Vector2(spots[selected].water)+Vector2(-7,-65)

func splash(at: Vector2, strength: float) -> void:
	splashes.append({"at":at,"age":0.0,"strength":strength})

func ellipse(at: Vector2, radius: float, alpha: float) -> void:
	for points in water_ring_segments(at,radius):
		draw_polyline(points,Color(.77,.9,.85,alpha),1.2,true)

func water_ring_segments(at: Vector2, radius: float) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array]=[]
	var points := PackedVector2Array()
	var count := maxi(40,ceili(TAU*radius/2.0))
	for i in count+1:
		var angle := float(i)/count*TAU
		var point := at+Vector2(cos(angle)*radius,sin(angle)*radius*.30)
		# A final water mask also protects arbitrary concave shores, independent of
		# the footprint placement check. Never bridge across a rejected section.
		if world.generator.sample(point).z>=.8: points.append(point)
		else:
			if points.size()>1: segments.append(points)
			points=PackedVector2Array()
	if points.size()>1: segments.append(points)
	return segments

func draw_fish(at: Vector2, width: float, tilt: float, color: Color=Color.WHITE) -> void:
	draw_set_transform(at,tilt)
	var height := width*float(fish_texture.get_height())/fish_texture.get_width()
	draw_texture_rect(fish_texture,Rect2(-width*.5,-height*.5,width,height),false,color)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if not is_instance_valid(world): return
	for i in spots.size():
		if int(spots[i].get("remaining",6))<=0: continue
		var at: Vector2=spots[i].water
		var screen: Vector2=get_viewport().get_canvas_transform()*at
		if not get_viewport_rect().grow(120).has_point(screen): continue
		var phase := fposmod(ambient_clock*.32+i*.7,1.0)
		ellipse(at,26+phase*26,(1-phase)*.40)
		ellipse(at+Vector2(-14,6),13+phase*16,(1-phase)*.22)
		# Low-contrast underwater shadows, never readable as a school of full fish sprites.
		for j in 3:
			var angle := ambient_clock*.28+i*1.7+j*2.1
			var shadow := at+Vector2(cos(angle)*23,sin(angle)*8)
			for blur in 3:
				draw_set_transform(shadow+Vector2(blur-1,0),sin(angle)*.12,Vector2(1,.36))
				draw_circle(Vector2.ZERO,7-j,Color(.08,.20,.23,.080),true,-1,true)
			draw_set_transform(Vector2.ZERO)
		var leap := fposmod(ambient_clock+i*4.3,14.0)
		if leap<.55 and not (selected==i and state!="idle"):
			var t := leap/.55
			draw_fish(at+Vector2(lerpf(-13,13,t),-sin(t*PI)*19),15,lerpf(-.5,.5,t),Color(1,1,1,.76))
			ellipse(at,12+t*16,(1-t)*.35)
	if line_points.size()>1: draw_polyline(line_points,Color(.88,.88,.72,.83),1.05,true)
	if state=="wait":
		var height := 17.0
		var width := height*float(float_texture.get_width())/float_texture.get_height()
		draw_texture_rect(float_texture,Rect2(bobber_position-Vector2(width*.5,14),Vector2(width,height)),false)
		ellipse(bobber_position+Vector2(0,2),9,.36)
	if state=="success" and clock>=.16 and clock<1.15:
		if catch_id==FISH_ID: draw_fish(jumping_fish_position(),35,sin(clock*6)*.35)
		else:
			var texture: Texture2D=catch_textures[catch_id]
			var width := 26.0 if catch_id==COIN_ID else 38.0
			var height := width*float(texture.get_height())/texture.get_width()
			draw_set_transform(jumping_fish_position(),sin(clock*6)*.12)
			draw_texture_rect(texture,Rect2(-width*.5,-height*.5,width,height),false)
			draw_set_transform(Vector2.ZERO)
	for drop in splashes:
		var t := float(drop.age)/.65
		var at: Vector2=drop.at
		var force := float(drop.strength)
		ellipse(at,8+t*32*force,(1-t)*.65)
		for j in 6:
			var angle := float(j)/6*TAU
			var point := at+Vector2(cos(angle)*t*24*force,sin(angle)*t*8-sin(t*PI)*19*force)
			draw_circle(point,(1-t)*2.2,Color(.79,.93,.90,(1-t)*.75),true,-1,true)
