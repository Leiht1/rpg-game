extends "res://scripts/nature_prop.gd"
## Selected three trees/six stones. Painted contact stays fixed during crown sway.
const Catalog=preload("res://scripts/scenery_catalog.gd")
const ContactShader=preload("res://scripts/scenery_contact.gdshader")
signal shadow_changed
var variant_id:=""
var surface:="grass"
var upper:MeshInstance2D
var contact:Sprite2D
var collision:CollisionPolygon2D
var mat:ShaderMaterial
var active:Tween
var state:="idle"
var foot:=Vector2(0,7)
static var occlusion_images:Dictionary={}
var required_hits:int:
	get:return 12 if variant_id=="tree_03" else 6

func prepare()->void:
	var ratio:=display_size/texture.get_size()
	var base_height:=40.*ratio.y if kind<2 else 12.*ratio.y
	var top:=-display_size.y+8.
	var end:=8.
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
	var rows:Array[float]=[]
	for row in 25:rows.append(lerpf(top,end,row/24.))
	rows.append(8.-base_height);rows.sort()
	for y in rows:
		for col in 9:
			var x:=lerpf(-display_size.x*.5,display_size.x*.5,col/8.)
			vertices.append(Vector3(x,y,0));uv.append(Vector2(col/8.,(y-top)/display_size.y))
	for row in range(rows.size()-1):
		for col in 8:
			var i:=row*9+col
			indices.append_array(PackedInt32Array([i,i+1,i+9,i+1,i+10,i+9]))
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mat=ShaderMaterial.new();mat.shader=ContactShader
	mat.set_shader_parameter("tree",kind<2);mat.set_shader_parameter("height",display_size.y)
	mat.set_shader_parameter("fixed_y",8.-base_height);mat.set_shader_parameter("color_fit",1.)
	mat.set_shader_parameter("image_size",texture.get_size());mat.set_shader_parameter("contact_extent",40. if kind<2 else 45.)
	mat.set_shader_parameter("surface_kind",{"grass":0,"forest":1,"dirt":2}[surface])
	var lips:Dictionary={"tree_01":[Vector2(-27,-8),Vector2(8,25)],"tree_03":[Vector2(-43,-12),Vector2(12,43)],"tree_04":[Vector2(-32,-10),Vector2(9,34)]}
	if lips.has(variant_id):
		mat.set_shader_parameter("left_lip",lips[variant_id][0]);mat.set_shader_parameter("right_lip",lips[variant_id][1])
	upper=MeshInstance2D.new();upper.name="SwayingUpper";upper.mesh=mesh;upper.texture=texture;upper.material=mat;add_child(upper)
	contact=Sprite2D.new();contact.name="FixedRootAndSurfaceContact";contact.texture=texture;contact.centered=false
	contact.region_enabled=true;contact.region_rect=Rect2(0,texture.get_height()-base_height/ratio.y,texture.get_width(),base_height/ratio.y)
	contact.scale=ratio;contact.position=Vector2(-display_size.x*.5,8.-base_height);contact.material=mat;add_child(contact)
	# One continuous mesh paints upper and fixed root exactly once. This sprite is
	# retained as an anchor only; overlapping translucent draws caused the dark seam.
	contact.visible=false
	var body:=StaticBody2D.new();body.name="FootprintBody";add_child(body)
	collision=CollisionPolygon2D.new();collision.name="Footprint"
	var points:=Catalog.footprint(variant_id)
	for i in points.size():points[i]*=ratio
	collision.polygon=points;body.add_child(collision)

func hit()->void:
	if kind>=2 or state in ["fading","removed"]:return
	if active:active.kill()
	state="hit";active=create_tween()
	var amount:=display_size.x/texture.get_width()
	active.tween_method(set_bend,0.,5.*amount,.065)
	active.tween_method(set_bend,5.*amount,-2.4*amount,.12)
	active.tween_method(set_bend,-2.4*amount,.9*amount,.13)
	active.tween_method(set_bend,.9*amount,0.,.18)
	active.tween_callback(func():state="idle")

func set_bend(value:float)->void:mat.set_shader_parameter("bend",value)

func fade_out()->void:
	if kind>=2 or state in ["fading","removed"]:return
	if active:active.kill()
	set_bend(0.);state="fading";collision.set_deferred("disabled",true)
	active=create_tween();active.tween_property(self,"modulate:a",0.,.3)
	active.parallel().tween_method(func(_v):shadow_changed.emit(),0.,1.,.3)
	active.tween_callback(func():hide();state="removed";shadow_changed.emit())

func update_occlusion(actor_position:Vector2)->void:
	if kind>=2 or state in ["fading","removed"]:return
	var delta:=actor_position-global_position
	# Only a tree sorted in front of the actor can hide it. Test painted pixels
	# against the actor's central body, not the transparent rectangular canvas.
	var next:=delta.y<0. and painted_overlap(delta)
	if next!=faded:
		faded=next;modulate.a=.48 if faded else 1.

func painted_overlap(actor_delta:Vector2)->bool:
	var rect:=Rect2(Vector2(-display_size.x*.5,-display_size.y+8.),display_size)
	var body:=Rect2(actor_delta+Vector2(-10,-64),Vector2(20,56))
	var area:=rect.intersection(body)
	if not area.has_area():return false
	var key:=texture.resource_path
	if not occlusion_images.has(key):occlusion_images[key]=texture.get_image()
	var image:Image=occlusion_images[key]
	var ratio:=texture.get_size()/display_size
	var covered:=0
	for y in range(ceili(area.position.y),floori(area.end.y),2):
		for x in range(ceili(area.position.x),floori(area.end.x),2):
			var pixel:=Vector2i((Vector2(x,y)-rect.position)*ratio)
			if image.get_pixelv(pixel).a>.5:
				covered+=1
				if covered>=6:return true
	return false

func _draw()->void:
	if kind>=4:
		super._draw();return
	var ratio:=display_size.x/texture.get_width()
	for i in range(4,0,-1):
		draw_set_transform(Vector2(1,3),0,Vector2(1,.2))
		draw_circle(Vector2.ZERO,((14. if kind<2 else 24.)+i)*ratio,Color(.18,.22,.15,.025))
	draw_set_transform(Vector2.ZERO)
