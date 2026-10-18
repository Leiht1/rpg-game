extends 'res://prototypes/environment-v01/study.gd'
const Catalog=preload('res://prototypes/environment-adapt-v01/catalog.gd')
const AdaptedProp=preload('res://prototypes/environment-adapt-v01/prop.gd')
var samples:Array=[]
var shadows:Array=[]
var selected:=0
var stream:WildStream
var collision_view:=Node2D.new()
var show_collisions:=false
var runtime_folder:='res://prototypes/environment-adapt-v01/runtime/'
func _ready()->void:
	stream=load('res://prototypes/environment-adapt-v01/stream.gd').new()
	stream.object_root=objects;add_child(stream)
	super._ready()
	collision_view.set_script(load('res://prototypes/environment-adapt-v01/collision_view.gd'));collision_view.z_index=1;collision_view.lab=self;add_child(collision_view)
func reset_props()->void:
	for p in samples:
		if is_instance_valid(p):p.free()
	for s in shadows:
		if is_instance_valid(s):s.free()
	samples.clear();shadows.clear()
	for drop in stream.drops:
		if is_instance_valid(drop):drop.queue_free()
	stream.drops.clear();stream.tree_hits.clear();stream.harvested.clear()
	for i in Catalog.IDS.size():
		var id:String=Catalog.IDS[i];var p=AdaptedProp.new()
		p.variant_id=id;p.kind=0 if i<3 else 1;p.surface=surface
		p.texture=load(runtime_folder+id+'_'+surface+'.png')
		p.display_size=p.texture.get_size()
		p.position=Vector2(-360+i*360,-5) if i<3 else Vector2(-440+(i-3)*176,180)
		p.set_meta('prop_id',id);p.set_meta('required_hits',4 if id=='tree_03' else 2)
		objects.add_child(p);samples.append(p)
		p.add_to_group('trees' if i<3 else 'rocks')
		var name_label:=Label.new();name_label.text=Catalog.NAMES[i];name_label.position=Vector2(-60,16);name_label.add_theme_font_size_override('font_size',15);p.add_child(name_label)
		if i<3:
			var s=load('res://prototypes/environment-v01/shadow.gd').new();s.prop=p;s.z_index=-1;add_child(s);shadows.append(s);p.shadow_changed.connect(s.queue_redraw)
	tree=samples[0];rock=samples[3];shadow.hide();update_caption();collision_view.queue_redraw()
func update_caption()->void:
	title.text='已选3种树 / 6种普通石头 · '+{'grass':'草地','forest':'林下','dirt':'裸土（岸土材质对照）'}[surface]+' · 新接触层待确认'
	label.text='1 草地   2 林下   3 裸土   ← →选择   E 砍树 / 拾取   H 受击演示   F 渐隐演示   C 碰撞轮廓   Space 重置\n当前：'+Catalog.NAMES[selected]+'；普通石头只碰撞，不受击、不采集。矮胖阔冠树已排除。'
func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.keycode:
		KEY_1:set_surface('grass')
		KEY_2:set_surface('forest')
		KEY_3:set_surface('dirt')
		KEY_LEFT:selected=(selected+8)%9;update_caption()
		KEY_RIGHT:selected=(selected+1)%9;update_caption()
		KEY_H:samples[selected].hit()
		KEY_F:samples[selected].fade_out()
		KEY_E:
			var at:Vector2=samples[selected].position+Vector2(0,34)
			var target:=stream.interaction_target(at)
			if target!=null:
				if target.is_in_group('drops'):stream.pickup_drop(target)
				elif target.is_in_group('trees'):stream.chop_tree(target)
		KEY_C:show_collisions=not show_collisions;collision_view.queue_redraw()
		KEY_SPACE:reset_props()
