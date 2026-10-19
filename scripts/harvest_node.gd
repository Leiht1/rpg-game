extends Node2D
## Resource art remains anchored. Progress changes a registered stage, never rock transform.
var service: Node
var resource_id := ""
var kind := ""
var definition: Dictionary
var sprite := Sprite2D.new()
var hit_material := ShaderMaterial.new()
var textures: Array[Texture2D]=[]
var collision: StaticBody2D
var soil: Sprite2D
var soil_material: ShaderMaterial
static func configuration() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/harvest_resources.json"))
func _ready() -> void:
	definition=configuration().resources[kind]
	set_meta("ore_id",resource_id)
	set_meta("resource_kind",kind)
	set_meta("prop_id",resource_id)
	set_meta("display_name",definition.name)
	set_meta("interaction_action",definition.action)
	set_meta("interaction_range",definition.range)
	add_to_group("world_interactables")
	add_to_group("harvest_visuals")
	for path in definition.textures: textures.append(load(path))
	# All stages share a canvas and source registration, thus one scale/offset.
	sprite.centered=false
	sprite.scale=Vector2.ONE*float(definition.width)/256.0
	sprite.position=Vector2(-float(definition.width)*.5,8-float(definition.width))
	hit_material.shader=preload("res://scripts/harvest_hit.gdshader")
	sprite.material=hit_material
	# Fixed subject texture: mineral intact silhouette, buried item fully exposed master.
	var buried: bool=definition.action=="dig" and not definition.get("surface_plant",false)
	sprite.texture=textures[2] if buried else textures[0]
	hit_material.set_shader_parameter("buried",buried)
	hit_material.set_shader_parameter("mineral_contact",definition.action=="mine")
	hit_material.set_shader_parameter("crack_overlay",definition.has("crack_textures"))
	add_child(sprite)
	if definition.get("surface_plant",false):
		var contact := ShaderMaterial.new()
		contact.shader=preload("res://scripts/grass_contact.gdshader")
		sprite.material=contact
	if buried:
		soil=Sprite2D.new();soil.name="PaintedForegroundSoil"
		soil.texture=textures[0];soil.centered=false
		soil.transform=sprite.transform
		soil_material=ShaderMaterial.new();soil_material.shader=preload("res://scripts/buried_soil.gdshader")
		soil.material=soil_material
		add_child(soil)
	if float(definition.collision[0])>0:
		collision=StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var polygon := ConvexPolygonShape2D.new()
		var points := PackedVector2Array()
		for i in 12: points.append(Vector2(cos(TAU*i/12)*float(definition.collision[0]),sin(TAU*i/12)*float(definition.collision[1])))
		polygon.points=points
		shape.shape=polygon
		collision.add_child(shape);add_child(collision)
	refresh_stage()
func refresh_stage() -> void:
	var hits := int(service.resource_hits.get(resource_id,0))
	var required := int(definition.hits)
	var stage := mini(2,ceili(float(hits)*2/maxi(1,required)))
	if definition.has("crack_textures"):
		hit_material.set_shader_parameter("damage_texture",load(definition.crack_textures[0 if hits*2<required else 1]))
	else: hit_material.set_shader_parameter("damage_texture",textures[stage])
	hit_material.set_shader_parameter("damage_amount",0.0 if hits==0 else 1.0)
	hit_material.set_shader_parameter("exposure",lerpf(.35,1.0,clampf(float(hits)/maxi(1,required),0,1)))
	if soil:
		soil.visible=hits<required
		soil_material.set_shader_parameter("progress",clampf(float(hits)/maxi(1,required),0,1))
	set_meta("progress",str(hits)+"/"+str(required))
func contact_feedback(from: Vector2) -> void:
	emit_burst(from)

func emit_burst(from: Vector2) -> void:
	var soil: bool=definition.action=="dig"
	var burst := preload("res://scripts/harvest_burst.gd").new()
	burst.soil=soil
	burst.texture=load("res://assets/harvest/v05/frame-%02d.png"%(20 if soil else 16))
	burst.direction=(position-from).normalized()
	burst.position=Vector2(0,-4 if soil else -14)
	add_child(burst)

func feedback(from: Vector2, completed: bool) -> void:
	refresh_stage()
	emit_burst(from)
	var soil: bool=definition.action=="dig"
	if not soil:
		var uv := Vector2(.3 if from.x<position.x else .7,.59)
		hit_material.set_shader_parameter("impact_uv",uv)
		hit_material.set_shader_parameter("strength",1.0)
		var flash := create_tween()
		flash.tween_method(func(v:float):hit_material.set_shader_parameter("strength",v),1.0,0.0,.16)
	if completed:
		set_meta("spent",true)
		remove_from_group("world_interactables")
		if collision: collision.queue_free()
		hit_material.set_shader_parameter("exposure",1.0)
		var finish := create_tween()
		finish.tween_interval(.16 if soil else .07)
		finish.tween_property(sprite,"modulate:a",0.0,.27)
		finish.tween_interval(.18)
		finish.tween_callback(queue_free)
func perform_interaction(action: String, _player: Node2D) -> bool:
	return service.harvest_hit(self,action)
