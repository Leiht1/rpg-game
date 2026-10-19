extends Node2D
var manager: RefCounted
var camp_id := ""
var base := Sprite2D.new()
var flame := Sprite2D.new()
var age := 0.0
var damage := ProgressBar.new()
var damage_seconds := 0.0
var fuel_bar := ProgressBar.new()
var flame_material := ShaderMaterial.new()

func _ready() -> void:
	add_child(damage);damage.hide()
	set_meta("display_name","简易篝火");set_meta("interaction_action","cook")
	set_meta("interaction_range",manager.rules.interaction_range);set_meta("prop_id",camp_id)
	add_to_group("world_interactables")
	base.texture=load("res://assets/campfire/v1/base.png")
	base.position=Vector2(0,-24);base.scale=Vector2.ONE*float(manager.rules.display_width)/256.0;add_child(base)
	flame.texture=load("res://assets/campfire/v1/flame.png")
	flame_material.shader=preload("res://scripts/campfire_flame.gdshader");flame.material=flame_material
	flame.position=Vector2(0,-44);flame.scale=Vector2.ONE*.20;add_child(flame)
	var body := StaticBody2D.new();var shape := CollisionShape2D.new();var circle := CircleShape2D.new()
	circle.radius=float(manager.rules.collision_radius);shape.shape=circle;body.add_child(shape);add_child(body)
	fuel_bar.position=Vector2(-36,6);fuel_bar.size=Vector2(72,7)
	fuel_bar.scale=Vector2(1.0,1.0/6.0)
	fuel_bar.max_value=float(manager.rules.max_fuel);fuel_bar.show_percentage=false
	fuel_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(fuel_bar)
	preload("res://scripts/item_ui_style.gd").progress_style(fuel_bar,true,false)

func _process(delta: float) -> void:
	if damage_seconds>0:
		damage_seconds=maxf(0,damage_seconds-delta)
		if damage_seconds==0: damage.hide()
	flame.visible=manager.states.has(camp_id) and manager.states[camp_id].lit
	preload("res://scripts/item_ui_style.gd").progress_style(fuel_bar,true,flame.visible)
	fuel_bar.value=float(manager.states[camp_id].fuel) if manager.states.has(camp_id) else 0.0
	if not flame.visible: return
	age+=delta
	flame_material.set_shader_parameter("phase",age)

func perform_interaction(_action: String, _player: Node2D) -> bool:
	manager.service.world.camp_ui.open(camp_id)
	return true

func update_damage() -> void:
	damage_seconds=2.0;damage.position=Vector2(-18,-62);damage.size=Vector2(36,3)
	damage.show_percentage=false;damage.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new();track.bg_color=Color(.20,.15,.10,.50)
	var fill := StyleBoxFlat.new();fill.bg_color=Color(.85,.64,.28)
	damage.add_theme_stylebox_override("background",track);damage.add_theme_stylebox_override("fill",fill)
	damage.max_value=3;damage.value=3-int(manager.states[camp_id].get("hits",0));damage.show()
