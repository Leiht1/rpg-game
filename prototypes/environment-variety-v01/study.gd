extends 'res://prototypes/environment-v01/study.gd'
var samples:Array=[]
var extra_shadows:Array=[]
var selected:=0
var manifest:Array=[]

func reset_props()->void:
	for p in samples:
		if is_instance_valid(p):p.free()
	for s in extra_shadows:
		if is_instance_valid(s):s.free()
	samples.clear();extra_shadows.clear()
	manifest=JSON.parse_string(FileAccess.get_file_as_string('res://prototypes/environment-variety-v01/runtime/manifest.json'))
	for i in manifest.size():
		var entry:Dictionary=manifest[i]
		var p=Prop.new();p.kind=0 if entry.kind=='tree' else 1
		p.texture=load('res://prototypes/environment-variety-v01/runtime/'+entry.file)
		p.display_size=Vector2(entry.canvas[0],entry.canvas[1])
		p.position=Vector2(-420+i*280,-5) if i<4 else Vector2(-440+(i-4)*176,180)
		p.set_meta('variant_id',entry.id);objects.add_child(p);samples.append(p)
		var name_label:=Label.new();name_label.text=entry.name;name_label.position=Vector2(-60,16);name_label.add_theme_font_size_override('font_size',15);p.add_child(name_label)
		if i<4:
			var s=load('res://prototypes/environment-v01/shadow.gd').new()
			s.prop=p;s.z_index=-1;add_child(s);extra_shadows.append(s)
			p.shadow_changed.connect(s.queue_redraw)
	tree=samples[selected];rock=samples[4];shadow.visible=false
	update_caption()

func update_caption()->void:
	title.text='景物形态候选 · 4种树 / 6种普通石头 · 待确认'
	label.text='← → 选择树   H 只晃动受击   F 原地渐隐   Space 重置    当前：'+str(selected+1)+' '+str(manifest[selected].name)+'\n同一套原角色、地表与1×镜头；按树/石分别统一等比整理，轮廓和枝干为独立绘制；无闪白'

func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.keycode:
		KEY_LEFT:selected=(selected+3)%4;tree=samples[selected];update_caption()
		KEY_RIGHT:selected=(selected+1)%4;tree=samples[selected];update_caption()
		KEY_H:tree.hit()
		KEY_F:tree.fade_out()
		KEY_SPACE:reset_props()
