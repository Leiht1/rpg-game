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
var preview := false
var gate_parts: Array[Node2D]=[]
var ground_neighbors: Dictionary={}

func _ready() -> void:
	if preview:
		body.free();shape.free();leaf.free();damage.free()
		return
	add_child(body);body.add_child(shape);body.add_child(leaf);leaf.disabled=true;add_child(damage);damage.hide()
	if not manager.states.has(building_id): queue_free();return
	var row: Dictionary=manager.states[building_id]
	var d: Dictionary=manager.definitions[row.kind]
	set_meta("building_id",building_id);set_meta("prop_id",building_id);set_meta("camp_layer",row.layer)
	set_meta("display_name",d.name);set_meta("interaction_action","open" if d.get("door",false) or row.kind in ["wood_chest","workbench"] else "sleep" if d.get("sleep",false) else "inspect")
	set_meta("interaction_range",100.0);add_to_group("world_interactables")
	if row.layer=="ground": z_index=-1
	if row.layer=="edge":
		y_sort_enabled=true
		for endpoint in preload("res://scripts/camp_grid.gd").ends(row):
			if not needs_joint(endpoint): continue
			var post := Node2D.new()
			post.position=Vector2(endpoint)*preload("res://scripts/camp_grid.gd").STEP-position
			add_child(post)
			post.draw.connect(draw_joint.bind(post,preload("res://scripts/camp_grid.gd").junction(manager.states,endpoint).stone))
	if row.layer!="ground":
		var rect := RectangleShape2D.new()
		rect.size=(Vector2(8,64) if row.vertical else Vector2(96,8)) if row.layer=="edge" else manager.footprint(row)
		shape.shape=rect
		if d.get("sleep",false): shape.position=manager.footprint_rect(row).get_center()
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
	update_damage()
	queue_redraw()

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
		if other.layer=="ground" and is_equal_approx(float(other.x),float(row.x)) and is_equal_approx(float(other.y),float(row.y)+64): return true
	return false

func _draw() -> void:
	if not manager.states.has(building_id): return
	var r: Dictionary=manager.states[building_id];var d: Dictionary=manager.definitions[r.kind]
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
	if r.layer=="free":
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
	if d.get("door",false):
		var reason: String=manager.toggle(building_id)
		if not reason.is_empty(): manager.service.notice.emit(reason)
		return reason.is_empty()
	if d.get("sleep",false): manager.service.sleep_ui.open(building_id);return true
	if r.kind=="workbench": manager.service.world.item_ui.toggle_craft(building_id);return true
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

func update_damage() -> void:
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
	position_damage();damage.show()

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
	elif r.layer=="free":
		var image := texture(int(manager.definitions[r.kind].frame))
		top=8-image.get_height()*minf(80.0/image.get_width(),92.0/image.get_height())
	damage.position=Vector2(-18,top-7)
