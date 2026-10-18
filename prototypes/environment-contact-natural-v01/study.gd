extends 'res://prototypes/environment-adapt-v01/color_study.gd'
const OLD_FOLDER='res://prototypes/environment-adapt-v01/runtime/'
const NEW_FOLDER='res://prototypes/environment-contact-natural-v01/runtime/'
const NATURAL_COLOR=preload('res://prototypes/environment-contact-natural-v01/contact_color.gdshader')
var natural_layout:=true
func _ready()->void:
	runtime_folder=NEW_FOLDER
	super._ready()
func reset_props()->void:
	super.reset_props()
	if natural_layout:
		for p in samples:
			var uniforms:={}
			for key in ['bend','height','fixed_y','tree','color_fit','surface_kind','image_size','left_lip','right_lip']:uniforms[key]=p.mat.get_shader_parameter(key)
			p.mat.shader=NATURAL_COLOR
			for key in uniforms:p.mat.set_shader_parameter(key,uniforms[key])
			p.mat.set_shader_parameter('contact_extent',40. if p.kind==0 else 45.)
		# Keep the accepted color formula; move its brown-detail windows to the new drawings.
		var regions:Dictionary={'tree_01':[Vector2(-27,-8),Vector2(8,25)],'tree_03':[Vector2(-43,-12),Vector2(12,43)],'tree_04':[Vector2(-32,-10),Vector2(9,34)]}
		for p in samples:
			if p.kind!=0:continue
			p.mat.set_shader_parameter('left_lip',regions[p.variant_id][0])
			p.mat.set_shader_parameter('right_lip',regions[p.variant_id][1])
func set_layout(on:bool)->void:
	natural_layout=on;runtime_folder=NEW_FOLDER if on else OLD_FOLDER
	reset_props()
func update_caption()->void:
	super.update_caption()
	title.text='已接入景物素材预览 · '+{'grass':'草地','forest':'林下','dirt':'裸土'}[surface]+' · '+('当前版本' if natural_layout else '上一版成对布局对照')
	label.text+='\nB 切换旧/新接触布局；沿用已认可的实际地表配色。'
func _unhandled_key_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_B:
		set_layout(not natural_layout);return
	super._unhandled_key_input(event)
