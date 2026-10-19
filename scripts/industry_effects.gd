extends Node2D
## Reuse approved flame art; chimney smoke is a short, transient completion effect.
var building: Node2D
var flame: Sprite2D
var glass: Sprite2D
var phase := 0.0
var puffs: Array[float]=[]
var chimney := Vector2.ZERO
func _ready() -> void:
	var row: Dictionary=building.manager.states[building.building_id]
	var image: Texture2D=load(building.manager.definitions[row.kind].art)
	var rect: Rect2=building.industry_rect(image)
	chimney=rect.position+rect.size*Vector2(.5,.10)
	if row.kind=="stone_furnace":
		flame=Sprite2D.new();flame.texture=load("res://assets/campfire/v1/flame.png")
		flame.scale=Vector2.ONE*rect.size.x*.28/flame.texture.get_width();flame.position=rect.position+rect.size*Vector2(.5,.66)
		var material_effect := ShaderMaterial.new();material_effect.shader=load("res://scripts/campfire_flame.gdshader");flame.material=material_effect;add_child(flame)
	else:
		glass=Sprite2D.new();glass.texture=image;glass.position=rect.get_center();glass.scale=rect.size/image.get_size()
		var material_effect := ShaderMaterial.new();material_effect.shader=load("res://scripts/oven_glass.gdshader");glass.material=material_effect;add_child(glass)
	building.manager.service.industry.product_finished.connect(on_finished)
	update_effect(0)
func on_finished(id: String) -> void:
	if id!=building.building_id or flame==null:return
	for i in 4:
		if puffs.size()<16:puffs.append(-float(i)*.14)
func update_effect(delta: float) -> void:
	phase+=delta
	var row: Dictionary=building.manager.states.get(building.building_id,{})
	var on: bool=not row.is_empty() and building.manager.service.industry.burning(row)
	if flame!=null:
		flame.visible=on;flame.material.set_shader_parameter("phase",phase)
	if glass!=null:
		glass.visible=on;glass.material.set_shader_parameter("phase",phase)
	for i in range(puffs.size()-1,-1,-1):
		puffs[i]+=delta
		if puffs[i]>=2.8:puffs.remove_at(i)
	queue_redraw()
func _process(delta: float) -> void:
	update_effect(delta)
func _draw() -> void:
	for age in puffs:
		if age<0:continue
		var opacity := .58*smoothstep(0,.12,age)*(1-smoothstep(1.2,2.8,age))
		var center := chimney+Vector2(sin(age*3.2)*2.5,-age*18)
		var radius := 3.2+age*2.6
		draw_circle(center,radius+1,Color(.30,.31,.29,opacity*.25))
		draw_circle(center,radius,Color(.78,.79,.75,opacity))
