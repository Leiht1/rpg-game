extends Node2D
var manager: RefCounted
var building_id := ""
var body := StaticBody2D.new()
var shape := CollisionShape2D.new()
var gate_angle := 0.0
var gate_tween: Tween
var rendered_hinge_end := 0
var leaf := CollisionPolygon2D.new()
var damage := ProgressBar.new()
var damage_seconds := 0.0
var preview := false
var gate_parts: Array[Node2D]=[]
var ground_neighbors: Dictionary={}
var torch_flame: Sprite2D
var torch_phase := 0.0

func _ready() -> void:
	if manager.states.has(building_id) and manager.states[building_id].kind in ["wood_floor","wood_chest"]:texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if manager.states.has(building_id) and manager.states[building_id].kind=="camp_torch": setup_torch()
	else: set_process(false)
	if preview:
		body.free();shape.free();leaf.free();damage.free()
		return
	add_child(body);body.add_child(shape);body.add_child(leaf);leaf.disabled=true;add_child(damage);damage.hide()
	if not manager.states.has(building_id): queue_free();return
	var row: Dictionary=manager.states[building_id]
	var d: Dictionary=manager.definitions[row.kind]
	set_meta("planting_soil",row.kind=="tilled_soil");set_meta("building_id",building_id);set_meta("prop_id",building_id);set_meta("camp_layer",row.layer)
	set_meta("display_name",str(row.text) if row.kind=="signpost" else d.name);set_meta("interaction_action","open" if d.get("door",false) or row.kind in ["wood_chest","workbench"] or d.get("industry",false) or d.get("expansion_v2",false) else "sleep" if d.get("sleep",false) else "inspect")
	set_meta("interaction_range",100.0);add_to_group("world_interactables")
	if row.layer=="ground": z_index=-2
	if row.layer=="overlay":z_index=-1
	if row.layer=="edge":
		y_sort_enabled=true
		for endpoint in preload("res://scripts/camp_grid.gd").ends(row):
			if not needs_joint(endpoint): continue
			var post := Node2D.new()
			post.position=Vector2(endpoint)*preload("res://scripts/camp_grid.gd").STEP-position
			add_child(post)
			post.draw.connect(draw_joint.bind(post,preload("res://scripts/camp_grid.gd").junction(manager.states,endpoint).stone))
	if row.layer not in ["ground","overlay"]:
		var rect := RectangleShape2D.new()
		rect.size=(Vector2(8,64) if row.vertical else Vector2(96,8)) if row.layer=="edge" else manager.footprint(row)
		shape.shape=rect
		if row.layer=="free": shape.position=manager.footprint_rect(row).get_center()
	else: body.collision_layer=0
	rendered_hinge_end=int(row.get("hinge_end",0))
	gate_angle=preload("res://scripts/camp_grid.gd").gate_base(row)+(PI*.5*int(row.get("swing",1 if row.inward else -1)) if row.open else 0.0)
	if d.get("door",false):
		y_sort_enabled=true
		shape.disabled=true;leaf.disabled=false;gate_collision()
		for i in 24:
			var part := Node2D.new()
			add_child(part);gate_parts.append(part)
			part.draw.connect(draw_leaf_strip.bind(part,i))
		update_leaf_parts()
	update_damage(false)
	if row.kind in ["stone_furnace","copper_oven"]:
		var effects := preload("res://scripts/industry_effects.gd").new();effects.name="IndustryEffects";effects.building=self;add_child(effects)
	queue_redraw()

func contact_feedback(_at: Vector2) -> void:
	pass

func texture(frame: int) -> Texture2D:
	if not manager.textures.has(frame):
		var adopted := {4:"wood_fence_vertical",10:"fence_gate_vertical",13:"wood_chest",14:"workbench"}
		var path: String="res://assets/buildings/v2/"+str(adopted[frame])+".png" if adopted.has(frame) else "res://assets/buildings/v1/frame-%02d.png"%frame
		manager.textures[frame]=load(path) if ResourceLoader.exists(path) else null
	return manager.textures[frame]

func stamp(frame: int, rect: Rect2) -> void:
	var image := texture(frame)
	if image: draw_texture_rect(image,rect,false)

func floor_texture(material: String, part: String) -> Texture2D:
	var path := "res://assets/buildings/v3/"+material+"-"+part+".png"
	if not manager.textures.has(path): manager.textures[path]=load(path)
	return manager.textures[path]

func floor_has_south() -> bool:
	var row: Dictionary=manager.states[building_id]
	var neighbors: Dictionary=ground_neighbors if preview and not ground_neighbors.is_empty() else manager.states
	for other in neighbors.values():
		if other.layer=="ground" and other.kind!="tilled_soil" and is_equal_approx(float(other.x),float(row.x)) and is_equal_approx(float(other.y),float(row.y)+64): return true
	return false

func planting_texture(asset: String) -> Texture2D:
	var path := preload("res://scripts/planting.gd").art(asset)
	if path.is_empty() or not ResourceLoader.exists(path): return null
	if not manager.textures.has(path):
		var source: Texture2D=load(path)
		if asset=="soil":
			# The requested inset applies to the painted footprint, not transparent canvas padding.
			var trimmed := AtlasTexture.new()
			trimmed.atlas=source;trimmed.region=Rect2(source.get_image().get_used_rect());trimmed.filter_clip=true
			manager.textures[path]=trimmed
		else: manager.textures[path]=source
	return manager.textures[path]

func industry_rect(image: Texture2D) -> Rect2:
	var profile: Dictionary=manager.volume_profile(str(manager.states[building_id].kind))
	if not profile.is_empty():return volume_rect(image,profile)
	var extent: Vector2=image.get_size()*minf(88.0/image.get_width(),96.0/image.get_height())
	if manager.states[building_id].kind=="metal_workbench":
		var painted: Rect2i=image.get_image().get_used_rect()
		extent=Vector2(80,80.0*painted.size.y/painted.size.x)
	return Rect2(Vector2(-extent.x*.5,8-extent.y),extent)

func volume_rect(image: Texture2D, profile: Dictionary) -> Rect2:
	var painted: Vector2=Vector2(image.get_image().get_used_rect().size)
	var extent := painted*minf(float(profile.width)/painted.x,float(profile.max_height)/painted.y)
	return Rect2(Vector2(-extent.x*.5,8-extent.y),extent)

func draw_volume(row: Dictionary, definition: Dictionary) -> bool:
	var profile: Dictionary=manager.volume_profile(str(row.kind))
	if profile.is_empty():return false
	var image: Texture2D
	var path := ""
	if profile.has("art"):
		path=profile.art
	elif definition.has("art"):
		path=definition.art
	elif row.kind=="wood_chest" and row.open:path="res://assets/buildings/chest-open-v1/wood_chest_open.png"
	elif row.kind=="signpost":path="res://assets/buildings/signpost_v1/signpost.png"
	else:image=texture(int(definition.frame))
	if not path.is_empty():
		# Draw commands need the resource alive after _draw returns, as in texture().
		if not manager.textures.has(path):
			manager.textures[path]=preload("res://scripts/candidate_art.gd").texture(path) if path.begins_with("res://prototypes/") else load(path)
		image=manager.textures[path]
	if image==null:return true
	var region := Rect2(image.get_image().get_used_rect())
	var rect := volume_rect(image,profile)
	if row.kind=="wool_carpet":rect=Rect2(-Vector2(profile.width,profile.max_height)*.5,Vector2(profile.width,profile.max_height))
	draw_texture_rect_region(image,rect,region)
	return true

func _draw() -> void:
	if not manager.states.has(building_id): return
	var r: Dictionary=manager.states[building_id];var d: Dictionary=manager.definitions[r.kind]
	if draw_volume(r,d):return
	if d.get("industry",false):
		var path: String=d.art
		if ResourceLoader.exists(path):
			var image: Texture2D=load(path)
			if r.kind=="wool_carpet":
				draw_texture_rect(image,Rect2(Vector2(-48,-32),Vector2(96,64)),false)
				return
			if r.kind=="metal_workbench":draw_texture_rect_region(image,industry_rect(image),Rect2(image.get_image().get_used_rect()))
			else:draw_texture_rect(image,industry_rect(image),false)
		return
	if r.kind=="signpost":
		var path := "res://assets/buildings/signpost_v1/signpost.png"
		if not manager.textures.has(path):manager.textures[path]=load(path)
		var image: Texture2D=manager.textures[path]
		var extent := Vector2(image.get_size())*minf(74.0/image.get_width(),86.0/image.get_height())
		draw_texture_rect(image,Rect2(Vector2(-extent.x*.5,8-extent.y),extent),false)
		return
	if r.kind=="tilled_soil":
		var soil := planting_texture("soil")
		if soil: draw_texture_rect(soil,preload("res://scripts/planting.gd").soil_rect(),false)
		var crop_name: String="roots" if r.get("roots",false) else ""
		if not str(r.get("crop","")).is_empty():
			var stage_value := preload("res://scripts/planting.gd").stage_for(r)
			crop_name=str(r.crop)+"_"+str(stage_value)
		if not crop_name.is_empty():
			var crop_image := planting_texture(crop_name)
			if crop_image: draw_texture_rect(crop_image,Rect2(-34,-32,68,56) if r.get("roots",false) else Rect2(-27,-42,54,54),false)
		return
	if r.layer=="ground":
		var material := "wood" if r.kind=="wood_floor" else "stone"
		draw_texture_rect(floor_texture(material,"top"),Rect2(-48,-32,96,64),false)
		# Approved thin material face only at an exposed south edge, including mixed floors.
		if not floor_has_south(): draw_texture_rect(floor_texture(material,"front"),Rect2(-48,32,96,21.0*96/636),false)
		return
	if d.get("sleep",false):
		var path := preload("res://scripts/sleep_controller.gd").art_path(r.kind+("-vertical" if r.vertical else ""))
		if not path.is_empty() and ResourceLoader.exists(path):
			if not manager.textures.has(path): manager.textures[path]=load(path)
			var image: Texture2D=manager.textures[path]
			var rect := Rect2(-32,-80 if r.kind=="straw_mat" else -100,64,104 if r.kind=="straw_mat" else 128) if r.vertical else Rect2(-64,-40 if r.kind!="wood_bed" else -56,128,64)
			var scale_value: float=float(preload("res://scripts/sleep_rules.gd").facility(r.kind).get("visual_scale",.25))/.25
			rect=Rect2(rect.position*scale_value,rect.size*scale_value)
			draw_texture_rect(image,rect,false)
		return
	if r.kind=="camp_torch": return
	if r.layer=="free":
		if r.kind=="wood_chest" and r.open:
			var path := "res://assets/buildings/chest-open-v1/wood_chest_open.png"
			if not manager.textures.has(path): manager.textures[path]=load(path)
			var opened: Texture2D=manager.textures[path]
			var height := 80.0*opened.get_height()/opened.get_width()
			draw_texture_rect(opened,Rect2(-40,8-height,80,height),false)
			return
		var image := texture(int(d.frame))
		if image:
			var extent := Vector2(image.get_size())*minf(80.0/image.get_width(),92.0/image.get_height())
			stamp(int(d.frame),Rect2(Vector2(-extent.x*.5,8-extent.y),Vector2(extent.x,extent.y)))
		return
	var stone: bool=r.kind.begins_with("stone")
	if d.get("door",false):
		if preview:
			for i in 24: draw_leaf_strip(self,i)
	elif stone and not r.vertical:
		var endpoints := preload("res://scripts/camp_grid.gd").ends(r)
		var left := 0.0 if needs_joint(endpoints[0]) else 9.0
		var right := 217.0 if needs_joint(endpoints[1]) else 208.0
		draw_texture_rect_region(texture(1),Rect2(-48,-44,96,52),Rect2(left,0,right-left,86))
	else:
		stamp((2 if r.vertical else 1) if stone else (4 if r.vertical else 3),Rect2(-14,-68,28,100) if r.vertical else Rect2(-48,-44,96,52))
	if preview:
		for endpoint in preload("res://scripts/camp_grid.gd").ends(r):
			if needs_joint(endpoint):
				var local := Vector2(endpoint)*preload("res://scripts/camp_grid.gd").STEP-position
				stamp(5 if stone else 6,Rect2(local+Vector2(-10,-46),Vector2(20,52)))

func needs_joint(endpoint: Vector2i) -> bool:
	var grid = preload("res://scripts/camp_grid.gd")
	var joint: Dictionary=grid.junction(manager.states,endpoint)
	if joint.owner!=building_id: return false
	if joint.stone and grid.connections(manager.states,endpoint)==10:
		for row in manager.states.values():
			if row.layer=="edge" and manager.definitions[row.kind].get("door",false) and grid.ends(row).has(endpoint): return true
		return false
	return true

func draw_joint(part: Node2D, stone: bool) -> void:
	part.draw_texture_rect(texture(5 if stone else 6),Rect2(-10,-46,20,52),false)

func update_gate() -> void:
	var r: Dictionary=manager.states[building_id]
	if gate_tween: gate_tween.kill()
	if rendered_hinge_end!=int(r.get("hinge_end",0)):
		rendered_hinge_end=int(r.get("hinge_end",0))
		gate_angle=preload("res://scripts/camp_grid.gd").gate_base(r)
	var angle := preload("res://scripts/camp_grid.gd").gate_base(r)+(PI*.5*int(r.get("swing",1 if r.inward else -1)) if r.open else 0.0)
	gate_tween=create_tween();gate_tween.tween_method(func(v: float): gate_angle=v;gate_collision();update_leaf_parts();queue_redraw(),gate_angle,angle,.25)

func gate_collision() -> void:
	if not manager.states.has(building_id): return
	var row: Dictionary=manager.states[building_id]
	var hinge := preload("res://scripts/camp_grid.gd").gate_hinge(row)
	var tip := hinge+Vector2(cos(gate_angle)*96,sin(gate_angle)*64)
	var normal := (tip-hinge).normalized().orthogonal()*4
	leaf.polygon=PackedVector2Array([hinge-normal,tip-normal,tip+normal,hinge+normal])
	if damage.visible: position_damage()

func perform_interaction(_action: String, _player: Node2D) -> bool:
	var r: Dictionary=manager.states[building_id];var d: Dictionary=manager.definitions[r.kind]
	if r.get("abandoned",false): return false
	if d.get("door",false):
		var reason: String=manager.toggle(building_id)
		if not reason.is_empty(): manager.service.notice.emit(reason)
		return reason.is_empty()
	if d.get("sleep",false): manager.service.sleep_ui.open(building_id);return true
	if r.kind=="signpost":manager.service.notice.emit(str(r.text));return true
	if manager.storage_kind(r.kind):manager.service.storage_ui.open(building_id);return true
	if r.kind=="copper_lamp":
		var reason: String=manager.service.industry.act(building_id,"toggle")
		if not reason.is_empty():manager.service.notice.emit(reason)
		return reason.is_empty()
	if r.kind in manager.service.expansion.KINDS:return manager.service.expansion_ui.open(building_id)
	if r.kind in ["workbench","metal_workbench"]: manager.service.world.item_ui.toggle_craft(building_id);return true
	if manager.service.industry.machine(r.kind):manager.service.industry_ui.open(building_id);return true
	if r.kind=="wood_chest": manager.service.storage_ui.open(building_id);return true
	manager.service.notice.emit("装备石锤后按E拆除" if r.kind!="camp_torch" else "营地火把在夜晚提供照明；装备石锤可拆除")
	return true

# Each strip sorts at its own ground contact. The fixed hinge/post never rotates.
func leaf_points(angle: float) -> PackedVector2Array:
	var r: Dictionary=manager.states[building_id]
	var hinge := preload("res://scripts/camp_grid.gd").gate_hinge(r)
	return PackedVector2Array([hinge,hinge+Vector2(cos(angle)*96,sin(angle)*64)])

func update_leaf_parts() -> void:
	if not manager.states.has(building_id): return
	var points := leaf_points(gate_angle)
	for i in gate_parts.size():
		gate_parts[i].position=points[0].lerp(points[1],(i+.5)/24.0)
		gate_parts[i].queue_redraw()

func draw_leaf_strip(part: Node2D, index: int) -> void:
	if not manager.states.has(building_id): return
	var points := leaf_points(gate_angle)
	var a := points[0].lerp(points[1],index/24.0)
	var b := points[0].lerp(points[1],(index+1)/24.0)
	var offset := Vector2.ZERO if part==self else part.position
	var r: Dictionary=manager.states[building_id]
	var t0 := index/24.0
	var t1 := (index+1)/24.0
	var span: float=points[1].x-points[0].x
	var side_on := absf(span)<8.0
	# Side-on: partition one full-thickness side image into non-overlapping Y bands.
	# Mapping a vertical 40-high slice at every foot sample repeats/overlaps the art;
	# shearing a tiny front plane instead makes its ends taper to a line.
	if side_on:
		var top := minf(points[0].y,points[1].y)-40
		var height := absf(points[1].y-points[0].y)+40
		var down := points[1].y>=points[0].y
		var v0 := t0 if down else 1-t1
		var v1 := t1 if down else 1-t0
		var left := (points[0].x+points[1].x)*.5-4
		var q0 := Vector2(left,top+height*v0)-offset
		var q1 := Vector2(left+8,top+height*v1)-offset
		part.draw_polygon(PackedVector2Array([q0,Vector2(q1.x,q0.y),q1,Vector2(q0.x,q1.y)]),PackedColorArray([gate_tint(),gate_tint(),gate_tint(),gate_tint()]),PackedVector2Array([Vector2(.30,lerpf(.12,.92,v0)),Vector2(.72,lerpf(.12,.92,v0)),Vector2(.72,lerpf(.12,.92,v1)),Vector2(.30,lerpf(.12,.92,v1))]),texture(10))
		return
	var image := texture(10 if side_on else (7 if r.kind=="stone_gate" else 9))
	var u0 := lerpf(.30 if side_on else .16,.72 if side_on else .89,t0)
	var u1 := lerpf(.30 if side_on else .16,.72 if side_on else .89,t1)
	part.draw_polygon(PackedVector2Array([a-offset-Vector2(0,40),b-offset-Vector2(0,40),b-offset,a-offset]),PackedColorArray([gate_tint(),gate_tint(),gate_tint(),gate_tint()]),PackedVector2Array([Vector2(u0,.12),Vector2(u1,.12),Vector2(u1,.92 if side_on else .94),Vector2(u0,.92 if side_on else .94)]),image)

func gate_tint() -> Color:
	# Slightly cooler/darker timber distinguishes the leaf when folded along a fence.
	return Color(.80,.88,.96)

func update_damage(show_hit: bool=true) -> void:
	if preview or not manager.states.has(building_id): return
	var r: Dictionary=manager.states[building_id]
	var d: Dictionary=manager.definitions[r.kind]
	if int(r.hits)<=0: damage.hide();return
	var background := StyleBoxFlat.new();background.bg_color=Color(.20,.15,.10,.50)
	var fill := StyleBoxFlat.new();fill.bg_color=Color(.85,.64,.28)
	for style in [background,fill]:
		style.content_margin_left=0;style.content_margin_right=0;style.content_margin_top=0;style.content_margin_bottom=0
	damage.add_theme_stylebox_override("background",background)
	damage.add_theme_stylebox_override("fill",fill)
	damage.show_percentage=false;damage.mouse_filter=Control.MOUSE_FILTER_IGNORE
	damage.custom_minimum_size=Vector2(36,3);damage.size=Vector2(36,3)
	damage.max_value=d.hits;damage.value=d.hits-r.hits
	position_damage()
	damage.visible=show_hit
	damage_seconds=2.0 if show_hit else 0.0
	if show_hit: set_process(true)

func position_damage() -> void:
	var r: Dictionary=manager.states[building_id]
	var top := -32.0
	if r.layer=="edge":
		top=-78.0 if r.vertical else -46.0
		if manager.definitions[r.kind].get("door",false):
			var points := leaf_points(gate_angle)
			top=minf(top,minf(points[0].y,points[1].y)-40)
	elif manager.definitions[r.kind].get("sleep",false):
		top=-56 if r.kind=="wood_bed" else -40
	elif r.kind=="signpost":
		top=-78.0
	elif r.layer=="free":
		var definition: Dictionary=manager.definitions[r.kind]
		var profile: Dictionary=manager.volume_profile(str(r.kind))
		if not profile.is_empty():
			var image: Texture2D=preload("res://scripts/candidate_art.gd").texture(definition.art) if str(definition.get("art","")).begins_with("res://prototypes/") else load(definition.art) if definition.has("art") else texture(int(definition.frame))
			top=volume_rect(image,profile).position.y
		else:
			var image := texture(int(definition.frame))
			top=8-image.get_height()*minf(80.0/image.get_width(),92.0/image.get_height())
	damage.position=Vector2(-18,top-7)

func setup_torch() -> void:
	var image := texture(15)
	if image==null: return
	torch_flame=Sprite2D.new()
	torch_flame.texture=image
	var extent := Vector2(image.get_size())*minf(80.0/image.get_width(),92.0/image.get_height())
	torch_flame.scale=extent/Vector2(image.get_size())
	torch_flame.position=Vector2(0,8-extent.y*.5)
	var effect := ShaderMaterial.new()
	effect.shader=preload("res://scripts/camp_torch_flame.gdshader")
	torch_flame.material=effect
	add_child(torch_flame)

func _process(delta: float) -> void:
	if damage_seconds>0:
		damage_seconds=maxf(0,damage_seconds-delta)
		if damage_seconds==0: damage.hide()
	if not is_instance_valid(torch_flame):
		if damage_seconds==0: set_process(false)
		return
	torch_phase+=delta
	torch_flame.material.set_shader_parameter("phase",torch_phase)
