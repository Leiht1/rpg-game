extends Node2D
const Rules=preload("res://scripts/season_rules.gd")
var world: Node2D
var atmosphere: Node2D
var clock:=0.0
var update_clock:=0.0
var art: Array[Texture2D]=[]
var object_materials: Dictionary={}
var flakes: Array[Vector4]=[]
var snow_positions: Array[Vector2]=[]
var snow_active := false
var previous_bounds := Rect2()

func snow_bounds(transform: Transform2D, size: Vector2) -> Rect2:
	var inverse := transform.affine_inverse()
	var margin := float(Rules.data.features.snow_motion.screen_margin)
	return Rect2(inverse*Vector2(-margin,-margin),(inverse*(size+Vector2.ONE*margin))-(inverse*Vector2(-margin,-margin)))

func advance_snow(delta: float, transform: Transform2D, size: Vector2, paused: bool) -> void:
	var bounds := snow_bounds(transform,size)
	if not snow_active:
		snow_positions.clear()
		for flake in flakes:snow_positions.append(bounds.position+Vector2(flake.x,flake.y)*bounds.size)
		snow_active=true
	if previous_bounds.size!=Vector2.ZERO and not previous_bounds.size.is_equal_approx(bounds.size):
		# Refill newly exposed view after zoom instead of leaving an empty band.
		for i in flakes.size():
			snow_positions[i]=bounds.position+Vector2(flakes[i].x,flakes[i].y)*bounds.size
	previous_bounds=bounds
	var motion: Dictionary=Rules.data.features.snow_motion
	var elapsed := 0.0 if paused else delta
	for i in flakes.size():
		var flake: Vector4=flakes[i]
		var p: Vector2=snow_positions[i]
		p.x+=elapsed*float(motion.drift_speed)+(sin(clock*float(motion.sway_speed)+flake.w*TAU)-sin((clock-elapsed)*float(motion.sway_speed)+flake.w*TAU))*float(motion.sway_amplitude)
		p.y+=elapsed*lerpf(float(motion.fall_speed_min),float(motion.fall_speed_max),flake.z)
		# Only particles leaving the visible world area recycle; camera motion never
		# resets the fall phase or makes the live particles follow the screen.
		p=bounds.position+Vector2(fposmod(p.x-bounds.position.x,bounds.size.x),fposmod(p.y-bounds.position.y,bounds.size.y))
		snow_positions[i]=p
func _ready() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=world.world_seed^183965
	for i in int(Rules.data.features.snow_particles):
		# Jittered cells cover the whole view while avoiding a regular visible grid.
		flakes.append(Vector4((float(i%23)+rng.randf())/23.0,(float(i/23)+rng.randf())/5.0,rng.randf(),rng.randf()))
	if Engine.get_meta("season_features_preview",false):
		for i in 12:art.append(preload("res://scripts/candidate_art.gd").texture("res://prototypes/season-features-v1/frame-%02d.png"%i))
	var layer:=CanvasLayer.new();layer.layer=2;add_child(layer)
	atmosphere=Node2D.new();layer.add_child(atmosphere);atmosphere.draw.connect(draw_atmosphere)
func _process(delta: float) -> void:
	if not is_instance_valid(world) or not world.started:return
	var sim=world.environment_view.simulation
	if not sim.paused:clock+=delta
	if int(sim.season_date().index)==3:
		advance_snow(delta,get_viewport().get_canvas_transform(),get_viewport_rect().size,sim.paused)
	else:snow_active=false
	update_clock-=delta
	if update_clock<=0:
		update_clock=.15
		var heat: Array=[]
		if world.item_service.get("camps")!=null:heat=preload("res://scripts/season_surface.gd").heat_sources(world.item_service)
		var heat_data:=PackedVector3Array()
		# Keep the nearest sources when a very large camp exceeds shader capacity.
		var center: Vector2=get_viewport().get_canvas_transform().affine_inverse()*(get_viewport_rect().size*.5)
		heat.sort_custom(func(a,b):return Vector2(a.x,a.y).distance_squared_to(center)<Vector2(b.x,b.y).distance_squared_to(center))
		for i in 32:heat_data.append(heat[i] if i<heat.size() else Vector3.ZERO)
		for packet in world.stream.loaded.values():
			packet.terrain.material.set_shader_parameter("snow_heat_count",mini(32,heat.size()))
			packet.terrain.material.set_shader_parameter("snow_heat_sources",heat_data)
			packet.terrain.material.set_shader_parameter("season_snow",sim.snow)
			for key in ["patch_scale","threshold","growth","edge_width","opacity"]:
				var uniform_name: String={"patch_scale":"snow_patch_scale","threshold":"snow_patch_threshold","growth":"snow_patch_growth","edge_width":"snow_patch_edge","opacity":"snow_patch_opacity"}[key]
				packet.terrain.material.set_shader_parameter(uniform_name,float(Rules.data.features.ground_snow[key]))
			packet.terrain.material.set_shader_parameter("season_ice",1.0 if sim.lakes_frozen() else 0.0)
		for tree in get_tree().get_nodes_in_group("trees")+get_tree().get_nodes_in_group("rocks"):
			if tree.get("mat")!=null:tree.mat.set_shader_parameter("season_snow",sim.snow)
		for id in object_materials.keys():
			if not world.item_service.builds.states.has(id):object_materials.erase(id)
		for id in world.item_service.builds.visuals:
			var node=world.item_service.builds.visuals[id]
			var row: Dictionary=world.item_service.builds.states[id]
			var rule: Dictionary=Rules.data.features.buildings.get(row.kind,{})
			if not rule.get("allowed",false):
				if row.kind=="tilled_soil":
					node.material=null;node.queue_redraw()
					var soil: Sprite2D=node.get_node_or_null("WinterSoil")
					if soil!=null:
						var warmth: float=preload("res://scripts/season_surface.gd").heat(world.item_service,node.position)
						soil.material.set_shader_parameter("snow_amount",sim.snow*(1.0-smoothstep(0.0,.2,warmth)))
				continue
			if not object_materials.has(id) or object_materials[id].get_meta("owner_id",0)!=node.get_instance_id():
				var mat:=ShaderMaterial.new();mat.shader=preload("res://scripts/season_snow_object.gdshader")
				mat.set_meta("owner_id",node.get_instance_id())
				if not art.is_empty():mat.set_shader_parameter("snow_grain",art[9])
				mat.set_shader_parameter("snow_depth",float(rule.snow_depth))
				mat.set_shader_parameter("ground_surface",row.layer=="ground")
				mat.set_shader_parameter("ground_threshold",float(Rules.data.features.ground_snow.threshold))
				mat.set_shader_parameter("ground_growth",float(Rules.data.features.ground_snow.growth))
				if row.kind=="rain_shelter" and node.shelter_view!=null:node.shelter_view.roof.material=mat
				else:node.material=mat
				object_materials[id]=mat
			object_materials[id].set_shader_parameter("snow_amount",float(sim.building_snow.get(id,{}).get("amount",sim.snow)))
	atmosphere.queue_redraw()
func draw_atmosphere() -> void:
	var sim=world.environment_view.simulation
	var season: int=sim.season_date().index
	var size:=get_viewport_rect().size
	if season==3:
		var transform := get_viewport().get_canvas_transform()
		for i in snow_positions.size():
			var flake: Vector4=flakes[i]
			var p: Vector2=transform*snow_positions[i]
			atmosphere.draw_circle(p,1.1+flake.z*1.2,Color(.94,.97,.98,.35+flake.z*.35))
	elif season==0 and not art.is_empty():
		var cycle:=floori(clock/float(Rules.data.features.bird_interval_seconds))
		var local:=fposmod(clock,float(Rules.data.features.bird_interval_seconds))
		var duration:=9.0+fposmod(sin(float(cycle)*192.17)*12871.,5.0)
		if local>duration:return
		var sign_value:=1.0 if cycle%2==0 else -1.0
		var p:=Vector2(lerpf(-45,size.x+45,local/duration),175+posmod(hash(str(cycle)),190)+sin(local*.5)*25)
		if sign_value<0:p.x=size.x-p.x
		atmosphere.draw_set_transform(p,0,Vector2(sign_value,1))
		atmosphere.draw_texture_rect(art[int(clock*8)%4],Rect2(-18,-18,36,36),false,Color(1,1,1,.82))
		atmosphere.draw_set_transform(Vector2.ZERO)
	elif season==2 and not art.is_empty():
		var local:=fposmod(clock,float(Rules.data.features.leaf_interval_seconds))
		var reverse:=int(clock/float(Rules.data.features.leaf_interval_seconds))%2==1
		if local>14:return
		for i in 6:
			var t:=local-float(i)*.7
			if t<0:continue
			var p:=Vector2(-30+t*(size.x+80)/10.,190+i*61+sin(t*1.3+i)*32+t*7)
			if reverse:p.x=size.x-p.x
			atmosphere.draw_set_transform(p,sin(t+i)*.4,Vector2.ONE)
			atmosphere.draw_texture_rect(art[4+(int(t*5)+i)%4],Rect2(-9,-9,18,18),false,Color(1,1,1,.78))
		atmosphere.draw_set_transform(Vector2.ZERO)
