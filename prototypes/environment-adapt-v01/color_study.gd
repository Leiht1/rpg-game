extends 'res://prototypes/environment-adapt-v01/study.gd'
const CONTACT_COLOR=preload('res://prototypes/environment-adapt-v01/contact_color.gdshader')
var color_fit:=1.
func _ready()->void:
	super._ready()
	# Same-z copy follows terrain, before all z=-1 shadows and z=0 objects/UI.
	var copy:=BackBufferCopy.new();copy.name='ContactPureGroundCopy';copy.z_index=-2
	copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT;add_child(copy)
func reset_props()->void:
	super.reset_props()
	for p in samples:
		p.mat.shader=CONTACT_COLOR
		p.mat.set_shader_parameter('tree',p.kind==0)
		p.mat.set_shader_parameter('height',p.display_size.y)
		p.mat.set_shader_parameter('fixed_y',8.-(p.root_height if p.kind==0 else 12.))
		p.mat.set_shader_parameter('image_size',p.texture.get_size())
		p.mat.set_shader_parameter('surface_kind',{'grass':0,'forest':1,'dirt':2}[surface])
		p.mat.set_shader_parameter('color_fit',color_fit)
		var lips:Dictionary={'tree_01':[Vector2(-24,-11),Vector2(11,25)],'tree_03':[Vector2(-40,-23),Vector2(23,40)],'tree_04':[Vector2(-29,-14),Vector2(15,31)]}
		if lips.has(p.variant_id):
			p.mat.set_shader_parameter('left_lip',lips[p.variant_id][0]);p.mat.set_shader_parameter('right_lip',lips[p.variant_id][1])
		p.contact.material=p.mat
func set_color_fit(value:float)->void:
	color_fit=value
	for p in samples:p.mat.set_shader_parameter('color_fit',value)
func update_caption()->void:
	super.update_caption()
	title.text+=' · 接触色跟随实际地面'
	label.text+='\nV 切换原色/适配；仅已有草叶/落叶/土唇局部调色，树干与石体保持。'
func _unhandled_key_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_V:
		set_color_fit(0. if color_fit>.5 else 1.);return
	super._unhandled_key_input(event)
