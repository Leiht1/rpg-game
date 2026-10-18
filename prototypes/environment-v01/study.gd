extends Node2D
const Prop=preload('res://prototypes/environment-v01/prop.gd')
var surface:='grass'
var legacy:=false
var tree:Node2D
var rock:Node2D
var hero:Node2D
var objects:=Node2D.new()
var ground:=Sprite2D.new()
var camera:=Camera2D.new()
var label:=Label.new()
var title:=Label.new()
var shadow:=Node2D.new()
var ground_material:=ShaderMaterial.new()

func _ready()->void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	ground.centered=false;ground.position=Vector2(-1280,-720);ground.scale=Vector2(2560,1440)
	ground.z_index=-2;add_child(ground)
	ground_material.shader=load('res://scripts/terrain.gdshader')
	for pair in [['forest_tex','forest'],['rock_tex','highland'],['meadow_tex','open_field'],['shore_tex','shore']]:ground_material.set_shader_parameter(pair[0],load('res://assets/environment/biome_v02/'+pair[1]+'.png'))
	var env:=Image.create(26,26,false,Image.FORMAT_RG8);env.fill(Color(.6,.3,0))
	ground_material.set_shader_parameter('environment_tex',ImageTexture.create_from_image(env))
	var blank:=Image.create(4,4,false,Image.FORMAT_R8);blank.fill(Color.BLACK)
	ground_material.set_shader_parameter('grounding_mask',ImageTexture.create_from_image(blank));ground.material=ground_material
	objects.y_sort_enabled=true;add_child(objects)
	shadow.set_script(load('res://prototypes/environment-v01/shadow.gd'));shadow.z_index=-1;add_child(shadow)
	hero=load('res://assets/hero/cartoon/character.tscn').instantiate()
	hero.position=Vector2(-64,112-112);objects.add_child(hero)
	hero.get_node('AnimationPlayer').play('front_breathe')
	add_child(camera);camera.position_smoothing_enabled=false;camera.zoom=Vector2.ONE
	var ui:=CanvasLayer.new();add_child(ui)
	title.position=Vector2(24,18);title.add_theme_font_size_override('font_size',24);ui.add_child(title)
	label.position=Vector2(24,58);label.add_theme_font_size_override('font_size',16);ui.add_child(label)
	set_surface('grass')

func set_surface(s:String)->void:
	surface=s
	var weights:=Image.create(4,4,false,Image.FORMAT_RGBA8)
	weights.fill(Color(1,0,0,0) if s=='forest' else Color(0,0,1,0))
	ground.texture=ImageTexture.create_from_image(weights)
	# Bare earth is a controlled dry shore plate study, not a new formal terrain class.
	ground_material.set_shader_parameter('meadow_tex',load('res://assets/environment/biome_v02/'+('shore' if s=='dirt' else 'open_field')+'.png'))
	reset_props()

func reset_props()->void:
	if is_instance_valid(tree):tree.free()
	if is_instance_valid(rock):rock.free()
	tree=Prop.new();tree.configure(0,surface,legacy);tree.position=Vector2(-155,20);objects.add_child(tree)
	rock=Prop.new();rock.configure(1,surface,legacy);rock.position=Vector2(155,30);objects.add_child(rock)
	shadow.prop=tree;tree.shadow_changed.connect(shadow.queue_redraw);shadow.queue_redraw()
	title.text='景物系统独立样板 · '+{'grass':'草地','forest':'森林地','dirt':'裸土地（岸土材质试验）'}[surface]+' · '+('旧画稿对照（非正式融合）' if legacy else '新画稿候选 / 待确认')
	label.text='1 草地   2 森林地   3 泥地   Tab 新旧切换   H 树受击   F 砍完渐隐   Space 重置\n原角色 / 原逻辑尺寸 / 1280×720 / Camera2D 1×；本场为固定布置样板，不读写世界存档'

func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.keycode:
		KEY_1:set_surface('grass')
		KEY_2:set_surface('forest')
		KEY_3:set_surface('dirt')
		KEY_TAB:legacy=not legacy;reset_props()
		KEY_H:tree.hit()
		KEY_F:tree.fade_out()
		KEY_SPACE:reset_props()
