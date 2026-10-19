from pathlib import Path
p=Path('scripts/terrain.gdshader');s=p.read_text();s=s.replace('varying vec2 world_point;', '''uniform int candidate_mode = 0;
uniform vec2 preview_center = vec2(0.0);
varying vec2 world_point;''');s=s.replace('float bank =', '''float area = 1.0-smoothstep(1350.0,1500.0,distance(world_point,preview_center));
	if(candidate_mode>0){
		// Quantized broad field removes fine pigment while preserving terrain/water coordinates.
		vec3 blocks=floor(field.rgb*18.0+0.5)/18.0;
		land=mix(land,blocks,area);
	}
	float bank =''');p.write_text(s)
p=Path('scripts/chunk_stream.gd');s=p.read_text();s=s.replace('var generator: WildGenerator','var candidate_mode := 0\nvar preview_enabled := false\nvar generator: WildGenerator',1);s=s.replace('loaded[coord]={"terrain":terrain,"ground":ground,"body":body,"props":props}', '''loaded[coord]={"terrain":terrain,"ground":ground,"body":body,"props":props}
	if preview_enabled:
		var layer=load("res://scripts/ground_candidate.gd").new()
		layer.z_index=-1
		layer.configure(generator,coord,packet.props)
		add_child(layer)
		loaded[coord]["candidate"]=layer
		apply_candidate(coord)''');s=s.replace('entry.terrain.queue_free()','if entry.has("candidate"): entry.candidate.queue_free()\n\tentry.terrain.queue_free()');s+='''
func set_candidate(mode:int)->void:
	candidate_mode=mode
	shared_material.set_shader_parameter("candidate_mode",mode)
	shared_material.set_shader_parameter("preview_center",generator.spawn)
	for c in loaded: apply_candidate(c)

func apply_candidate(c:Vector2i)->void:
	var entry:Dictionary=loaded[c]
	if not entry.has("candidate"):return
	entry.candidate.mode=candidate_mode
	entry.candidate.queue_redraw()
	# Keep the legacy map elsewhere and all original art available with key 1.
	entry.ground.visible=candidate_mode==0 or (Vector2(c)*Gen.CHUNK_PX+Vector2.ONE*Gen.CHUNK_PX*.5).distance_to(generator.spawn)>2100
	for prop in entry.props:
		if prop.position.distance_to(generator.spawn)<1350:
			prop.candidate_mode=candidate_mode
			prop.visible=not (candidate_mode>0 and prop.kind>=4)
			prop.queue_redraw()
''';p.write_text(s)
p=Path('scripts/nature_prop.gd');s=p.read_text();s=s.replace('var texture:', 'var candidate_mode := 0\nvar texture:',1);s=s.replace('if kind<4:', 'if kind<4 and candidate_mode==0:');# preserve original branch then add compact contact shadow before texture
s=s.replace('\tdraw_texture_rect(texture,', '''	if kind<4 and candidate_mode>0:
		var contour:=PackedVector2Array()
		for i in 12:
			var a:=i*TAU/12.0
			var r:=1.0+.13*sin(i*2.3+detail_seed*19)
			contour.append(Vector2(cos(a)*w*r,sin(a)*w*(.24 if kind<2 else .35)*r)+Vector2(4,4))
		draw_colored_polygon(contour,Color(.22,.29,.16,.23))
	draw_texture_rect(texture,''');p.write_text(s)
Path('scripts/ground_candidate.gd').write_text('''extends Node2D
# One node/chunk, no grass physics bodies. Rendering transforms shear only the tips.
const VERSION="ground-preview-0.4.0"
var mode:=1
var gen:WildGenerator
var tufts:Array[Dictionary]=[]
var patches:Array[Dictionary]=[]
var contacts:Array[Dictionary]=[]
var textures:Array[Texture2D]=[]
var actor:Node2D
var last_actor:=Vector2.ZERO
var max_bend:=0.0
func configure(g:WildGenerator,c:Vector2i,props:Array)->void:
	gen=g
	position=Vector2(c)*WildGenerator.CHUNK_PX
	for i in 6:textures.append(load("res://assets/environment/ground_v04/%d.png"%i))
	for y in 18:
		for x in 18:
			var grid:=c*18+Vector2i(x,y)
			var p:Vector2=(Vector2(grid)+Vector2(.2+g.random_at(grid.x,grid.y,601)*.6,.2+g.random_at(grid.x,grid.y,602)*.6))*64
			if p.distance_to(g.spawn)>1300:continue
			var v:=g.sample(p)
			if v.z>.005 or v.y>.5:continue
			var r:=g.random_at(grid.x,grid.y,603)
			if r<.14:
				patches.append({"p":p-position,"kind":5 if v.x>.5 else 2,"w":100+r*130})
			elif r<.78:
				tufts.append({"p":p-position,"kind":0 if r<.5 else 1,"w":23+r*13,"bend":0.0,"rank":r})
	for prop in props:
		if prop.kind<4 and prop.position.distance_to(g.spawn)<1300 and g.sample(prop.position).z<.005:
			contacts.append({"p":prop.position-position+Vector2(7,7),"kind":3 if prop.kind<2 else 4,"w":(55 if prop.kind<2 else 65)*prop.scale})
func _process(delta:float)->void:
	if mode==0:return
	if actor==null:
		actor=get_parent().get_parent().get_node_or_null("YSortedNatureAndActor/Wanderer")
		if actor==null:return
	var half_view:=get_viewport_rect().size/(actor.camera.zoom*2)
	if not Rect2(actor.position-half_view-Vector2(80,80),half_view*2+Vector2(160,160)).intersects(Rect2(position,Vector2.ONE*WildGenerator.CHUNK_PX)):return
	var moving:bool=actor.last_displacement.length_squared()>.001 and not actor.input_blocked
	var dirty:=false
	for tuft in tufts:
		var p:Vector2=position+tuft.p
		if absf(p.x-actor.position.x)>half_view.x+60 or absf(p.y-actor.position.y)>half_view.y+60:continue
		var target:=0.0
		var offset:Vector2=p-actor.position
		if moving and offset.length()<43:
			var side:=signf(offset.x+actor.last_displacement.x*3)
			target=side*(1.0-offset.length()/43)*(.95 if actor.running else .55)
		var before:float=tuft.bend
		tuft.bend=lerpf(before,target,1-exp(-delta*(18 if moving else 5)))
		if absf(tuft.bend)<.001:tuft.bend=0.0
		max_bend=maxf(max_bend,absf(tuft.bend))
		dirty=dirty or absf(before-tuft.bend)>.0001
	if dirty:queue_redraw()
func stamp(kind:int,p:Vector2,w:float,bend:float=0.0,rooted:bool=false)->void:
	var t:Texture2D=textures[kind]
	var h:float=w*t.get_height()/t.get_width()
	draw_set_transform_matrix(Transform2D(Vector2(1,0),Vector2(bend,1-absf(bend)*.20),p))
	draw_texture_rect(t,Rect2(Vector2(-w*.5,-h if rooted else -h*.5),Vector2(w,h)),false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
func _draw()->void:
	if mode==0 or textures.is_empty():return
	for p in patches:stamp(p.kind,p.p,p.w)
	if mode==2:
		for p in contacts:stamp(p.kind,p.p,p.w)
	for t in tufts:
		if mode==1 and t.rank>.42:continue
		stamp(t.kind,t.p,t.w,t.bend,true)
''')
Path('scripts/ground_preview.gd').write_text('''extends "res://scripts/world.gd"
var comparison_label:=Label.new()
func _ready()->void:
	super._ready()
	stream.preview_enabled=true
	stream.set_candidate(1)
	make_label(comparison_label,"",Vector2(26,82),16)
	update_comparison()
func update_comparison()->void:
	comparison_label.text="候选测试区 · 1 旧版 / 2 A 简化 / 3 B 适度细节 · 当前：%s · 0 返回出生点"%["旧版","A（待选择）","B（待选择）"][stream.candidate_mode]
func _unhandled_input(event:InputEvent)->void:
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_1,KEY_2,KEY_3]:
			stream.set_candidate(event.physical_keycode-KEY_1)
			update_comparison()
		if event.physical_keycode==KEY_0:
			player.position=generator.spawn
			player.camera.reset_smoothing()
			stream.update_target(player.position)
''')
Path('scenes/ground_preview.tscn').write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/ground_preview.gd" id="1"]
[node name="GroundPreview" type="Node2D"]
script = ExtResource("1")
''')
Path('Start-Ground-Preview.cmd').write_text('''@echo off\nstart "" "D:\\Godot_v4.7.2-stable_win64.exe\\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." res://scenes/ground_preview.tscn\n''')
