extends RefCounted
const ID := "solar_flashlight"
const DIRECTIONS := {"front":Vector2.DOWN,"back":Vector2.UP,"left":Vector2.LEFT,"right":Vector2.RIGHT}
var merchant: Node
var beams: Array[Dictionary]=[]
var player_mask: SubViewport
var mask_painter: Node2D

static func fresh() -> Dictionary:return {"energy":100.0,"on":false,"facing":"front"}
static func valid(value: Variant) -> bool:
	if not value is Dictionary:return false
	var energy=value.get("energy")
	return (energy is int or energy is float) and is_finite(float(energy)) and energy>=0 and energy<=100 and value.get("on") is bool and value.get("facing") in DIRECTIONS

func rows() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var service=merchant.service
	for slot in service.inventory.slots+service.inventory.equipment.values():
		if slot.get("item_id")==ID:result.append({"instance":slot,"ground":false})
	for entry in service.loose.values():
		if entry.get("item_id")==ID:result.append({"instance":entry.instance,"ground":true,"entry":entry})
	return result

func toggle(index: int) -> bool:
	var service=merchant.service
	if not merchant.enabled or not service.writable or service.body.sleep_active():return false
	var slot: Dictionary=service.inventory.get_slot(index)
	if slot.get("item_id")!=ID:return false
	var before: Dictionary=slot.state.duplicate(true)
	if float(slot.state.energy)<=0:service.notice.emit("手电筒没有能量了");return false
	slot.state.on=not slot.state.on;service.dirty=true
	if not service.save_state():slot.state=before;service.notice.emit("保存失败，开关已回滚");return false
	service.inventory.changed.emit();return true

func evolve(state: Dictionary, minutes: float, ground: bool, daylight: bool, clear: bool, dawn: bool) -> void:
	if dawn:state.on=false
	if state.on:state.energy=maxf(0,float(state.energy)-minutes*100.0/float(merchant.rules.discharge_minutes))
	if ground and daylight and clear:state.energy=minf(100,float(state.energy)+minutes*100.0/float(merchant.rules.charge_minutes))
	if state.energy<=0:state.energy=0.0;state.on=false

func advance(minutes: float, personal_only: bool=false) -> void:
	var sim=merchant.service.world.environment_view.simulation
	var now: float=(sim.day-1)*1440.0+sim.minute
	var last: float=merchant.state.get("last_time",now)
	var dawn: bool= floor((now-float(merchant.rules.sunrise))/1440.0)>floor((last-float(merchant.rules.sunrise))/1440.0)
	merchant.state.last_time=now
	var daylight: bool=sim.minute>=merchant.rules.sunrise and sim.minute<merchant.rules.sunset
	var clear: bool=sim.target_weather==0 and sim.current_weather==0 and sim.blend.y+sim.blend.z<.001
	for row in rows():
		if not personal_only or not row.ground:evolve(row.instance.state,minutes,row.ground,daylight,clear,dawn)

func ground_texture(facing: String) -> Texture2D:
	var view := "side" if facing in ["left","right"] else facing
	return load("res://assets/merchant/v1/flashlight_"+view+".png")

func render() -> void:
	var service=merchant.service
	var held: Dictionary=service.inventory.equipment.get("main_hand",{})
	beams.clear()
	if held.get("item_id")==ID:
		if held.state.facing!=service.world.player.facing:held.state.facing=service.world.player.facing;service.dirty=true
		var direction: Vector2=DIRECTIONS[held.state.facing]
		# The native grip follows the arm; the beam starts at the registered lens pixel.
		var arm: Node=service.world.player.character.get_node("Visual/Pelvis/ArmR")
		var tool: Sprite2D=arm.get_node_or_null("HeldTool")
		var point: Vector2=service.world.player.position+Vector2(0,-20)+direction*15
		if is_instance_valid(tool) and tool.texture:
			var lens := Vector2(128,35) if held.state.facing in ["back","left","right"] else Vector2(128,200)
			point=tool.to_global(lens+tool.offset)
		if held.state.on and held.state.energy>0:beams.append({"at":point,"direction":direction})
	for entry in service.loose.values():
		if entry.get("item_id")!=ID:continue
		var facing: String=entry.instance.state.facing
		if entry.instance.state.on and entry.instance.state.energy>0:beams.append({"at":Vector2(entry.x,entry.y)-Vector2(0,8)+DIRECTIONS[facing]*12,"direction":DIRECTIONS[facing]})
	for drop in service.world.stream.drops:
		if not is_instance_valid(drop) or drop.get_meta("item_id","")!=ID:continue
		if drop.get_meta("airborne",false):continue
		var entry: Dictionary=service.loose.get(drop.get_meta("drop_id"),{})
		if entry.is_empty():continue
		var facing: String=entry.instance.state.facing
		if drop.get("visual") is Sprite2D:
			var visual: Sprite2D=drop.visual
			visual.texture=ground_texture(facing);visual.scale=Vector2.ONE*30.0/256.0
			visual.offset=Vector2(0,-128)
			visual.rotation=-PI*.5 if facing=="left" else PI*.5 if facing=="right" else 0.0
			visual.position=Vector2(0,-8)

func shader_parameters(material: ShaderMaterial) -> void:
	var service=merchant.service
	var viewport: Viewport=service.world.get_viewport()
	if not is_instance_valid(player_mask):
		player_mask=SubViewport.new();player_mask.transparent_bg=true;player_mask.disable_3d=true
		player_mask.render_target_update_mode=SubViewport.UPDATE_ALWAYS;merchant.add_child(player_mask)
		mask_painter=preload("res://scripts/torch_player_mask.gd").new();mask_painter.player=service.world.player;player_mask.add_child(mask_painter)
	player_mask.size=Vector2i(viewport.get_visible_rect().size);mask_painter.queue_redraw()
	material.set_shader_parameter("torch_player_mask",player_mask.get_texture())
	var transform := viewport.get_canvas_transform()
	material.set_shader_parameter("merchant_glow_scale",0.0)
	if is_instance_valid(merchant.actor):
		material.set_shader_parameter("merchant_ground",(transform*merchant.actor.global_position)/viewport.get_visible_rect().size)
		material.set_shader_parameter("merchant_center",(transform*(merchant.actor.global_position+Vector2(0,-60)))/viewport.get_visible_rect().size)
		material.set_shader_parameter("merchant_glow_scale",transform.get_scale().x)
	var centers := PackedVector2Array();var directions := PackedVector2Array()
	var length_px: float=merchant.rules.beam_length*transform.get_scale().x
	for beam in beams:
		var point: Vector2=transform*beam.at
		if not viewport.get_visible_rect().grow(length_px).has_point(point):continue
		if centers.size()>=32:break
		centers.append(point/viewport.get_visible_rect().size);directions.append(beam.direction)
	material.set_shader_parameter("torch_count",centers.size())
	material.set_shader_parameter("torch_centers",centers)
	material.set_shader_parameter("torch_directions",directions)
	material.set_shader_parameter("torch_length",length_px)
	material.set_shader_parameter("torch_angle",float(merchant.rules.beam_half_angle))


