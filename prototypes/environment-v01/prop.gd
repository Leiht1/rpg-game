extends Node2D
signal shadow_changed
## Isolated study only. Root node and ground adapter NEVER animate.
var kind:=0
var surface:="grass"
var legacy:=false
var texture:Texture2D
var display_size:=Vector2(177,190)
var upper:MeshInstance2D
var contact:Sprite2D
var effect:Node2D
var collision:CollisionPolygon2D
var mat:ShaderMaterial
var active:Tween
var state:="idle"
var root_height:=24.

func configure(k:int,s:String,old:bool=false)->void:
	kind=k;surface=s;legacy=old
	texture=load("res://assets/environment/view_v01/%s_0.png"%('tree' if kind==0 else 'rock')) if old else load("res://prototypes/environment-v01/runtime/%s_%s.png"%['tree' if kind==0 else 'rock',s])
	display_size=Vector2(177,190) if kind==0 else Vector2(77,65)
	if old:display_size=texture.get_size()
	if not is_inside_tree():return
	build()

func _ready()->void:build()

func build()->void:
	for c in get_children():c.free()
	upper=MeshInstance2D.new();upper.name='TreeUpper' if kind==0 else 'RockMain'
	# Root/base remains a separately rendered, texture-derived painted structure.
	contact=Sprite2D.new();contact.name='FixedRootAndSurfaceContact'
	contact.texture=texture;contact.centered=false;contact.region_enabled=true
	var scale_factor:=display_size/texture.get_size()
	var base_height:=root_height if kind==0 else 12.
	contact.region_rect=Rect2(0,texture.get_height()-base_height/scale_factor.y,texture.get_width(),base_height/scale_factor.y)
	contact.scale=scale_factor;contact.position=Vector2(-display_size.x*.5,8.-base_height)
	# Shared pixels at the join; root/grass cannot slide away from the trunk.
	var top:= -display_size.y+8.
	var end:=8. if legacy else 8.-base_height+1.
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
	for row in 25:
		var y:=lerpf(top,end,row/24.)
		for col in 9:
			var x:=lerpf(-display_size.x*.5,display_size.x*.5,col/8.)
			vertices.append(Vector3(x,y,0));uv.append(Vector2(col/8.,(y-top)/display_size.y))
	for row in 24:
		for col in 8:
			var i:=row*9+col
			indices.append_array(PackedInt32Array([i,i+1,i+9,i+1,i+10,i+9]))
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	upper.mesh=mesh;upper.texture=texture
	mat=ShaderMaterial.new();mat.shader=load('res://prototypes/environment-v01/prop.gdshader')
	mat.set_shader_parameter('tree',kind==0 and not legacy);mat.set_shader_parameter('height',display_size.y)
	mat.set_shader_parameter('fixed_y',8.-base_height)
	upper.material=mat;add_child(upper)
	contact.visible=not legacy;add_child(contact)
	effect=Node2D.new();effect.name='Effects';add_child(effect)
	var body:=StaticBody2D.new();body.name='FootprintBody';add_child(body)
	collision=CollisionPolygon2D.new()
	# Exactly the original formal footprint at scale 1.
	if kind==0:collision.polygon=PackedVector2Array([Vector2(-18,-3),Vector2(-14,-14),Vector2(13,-14),Vector2(19,-4),Vector2(14,5),Vector2(-12,6)])
	else:
		var w:=display_size.x*.46;var h:=display_size.y*.27
		collision.polygon=PackedVector2Array([Vector2(-w*.95,-h*.3),Vector2(-w*.7,-h),Vector2(w*.55,-h*1.1),Vector2(w,-h*.25),Vector2(w*.75,4),Vector2(-w*.55,7)])
	body.add_child(collision);state='idle';queue_redraw()

func hit()->void:
	if state in ['fading','removed']:return
	if active:active.kill()
	state='hit';active=create_tween()
	if kind==0:
		active.tween_method(set_bend,0.,5.,.065)
		active.tween_method(set_bend,5.,-2.4,.12)
		active.tween_method(set_bend,-2.4,.9,.13)
		active.tween_method(set_bend,.9,0.,.18)
	active.tween_callback(func():state='idle')

func set_bend(v:float)->void:mat.set_shader_parameter('bend',v)

func fade_out()->void:
	if kind!=0 or state in ['fading','removed']:return
	if active:active.kill()
	set_bend(0);state='fading';collision.disabled=true
	# Match formal removal: fade the complete object in place over 0.3 seconds.
	active=create_tween();active.tween_property(self,'modulate:a',0.,.3)
	active.parallel().tween_method(func(_v):shadow_changed.emit(),0.,1.,.3)
	active.tween_callback(func():hide();state='removed';shadow_changed.emit())

func remove_rock()->void:
	if kind!=1:return
	if active:active.kill()
	state='removed';collision.disabled=true
	queue_redraw()
	active=create_tween();active.tween_property(upper,'modulate:a',0.,.24)
	active.parallel().tween_property(contact,'modulate:a',0.,.24)

func _draw()->void:
	# Only a tiny soft contact, no halo or soil/green disk.
	if kind==1 and state=='removed':return
	for i in range(4,0,-1):
		draw_set_transform(Vector2(1,3),0,Vector2(1,.2))
		draw_circle(Vector2.ZERO,(14. if kind==0 else 24.)+i,Color(.18,.22,.15,.025))
	draw_set_transform(Vector2.ZERO)
