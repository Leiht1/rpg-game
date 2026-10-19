from pathlib import Path
p=Path('prototypes/view-v01')
s=Path('scripts/chunk_stream.gd').read_text(encoding='utf-8').replace('class_name WildStream\n','').replace('res://scripts/world_generator.gd','res://prototypes/view-v01/generator.gd').replace('res://scripts/terrain.gdshader','res://prototypes/view-v01/terrain.gdshader')
s=s.replace('var local_gen := Gen.new(generator.world_seed,generator.map_cells)','var local_gen := Gen.new(generator.world_seed,generator.map_cells)')
(p/'stream.gd').write_text(s,encoding='utf-8')
s=Path('scripts/world.gd').read_text(encoding='utf-8').replace('res://scripts/world_generator.gd','res://prototypes/view-v01/generator.gd').replace('res://scripts/chunk_stream.gd','res://prototypes/view-v01/stream.gd').replace('var stream: WildStream','var stream: Node2D')
# Player expects WildStream: retain stream class inheritance by using base class in candidate stream.
(p/'stream.gd').write_text((p/'stream.gd').read_text(encoding='utf-8').replace('extends Node2D','extends WildStream',1),encoding='utf-8')
# Inherited fields would conflict. Instead copy actual stream under unique class, and use original subclass with only overridden worker/install/configure.
original=Path('scripts/chunk_stream.gd').read_text(encoding='utf-8')
start=original.index('func _generate(');end=original.index('\nfunc install_chunk',start)
worker=original[start:end].replace('Gen.new(generator.world_seed,generator.map_cells)','load("res://prototypes/view-v01/generator.gd").new(generator.world_seed,generator.map_cells)')
(p/'stream.gd').write_text('''extends WildStream
func configure(gen: WildGenerator, sort_root: Node2D) -> void:
	super.configure(gen,sort_root)
	if not Engine.get_meta("view_before",false):
		shared_material.shader=load("res://prototypes/view-v01/terrain.gdshader")
		for i in 4:
			textures[i]=ImageTexture.create_from_image(Image.load_from_file("res://prototypes/view-v01/"+FILES[i]+".png"))
'''+worker,encoding='utf-8')
s=s.replace('var stream: Node2D','var stream: WildStream')
(p/'world_base.gd').write_text(s,encoding='utf-8')
(p/'generator.gd').write_text('''extends WildGenerator
# Candidate only. Coordinate-addressed thinning preserves every retained lake's geometry.
const CANDIDATE_VERSION="windrest-view-0.1.0"
var before:bool=false
var original_lake_count:int=0
func _init(seed_value:int=271828,size_cells:int=1024)->void:
	super._init(seed_value,size_cells)
	before=Engine.get_meta("view_before",false)
	original_lake_count=lakes.size()
	if before:return
	var kept:Array[Vector4]=[]
	lake_bins.clear()
	for lake in lakes:
		if random_at(roundi(lake.x),roundi(lake.y),934)>=.5:continue
		kept.append(lake)
		var point:=Vector2(lake.x,lake.y)
		var lo:=Vector2i((point-Vector2(lake.z,lake.w)*1.3)/2048)
		var hi:=Vector2i((point+Vector2(lake.z,lake.w)*1.3)/2048)
		for y in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1):
				var key:=Vector2i(x,y)
				if not lake_bins.has(key):lake_bins[key]=[]
				lake_bins[key].append(lake)
	lakes=kept
func sample(p:Vector2,spawn_clearance:bool=true)->Vector4:
	return super.sample(p,spawn_clearance if before else false)
func props_for_chunk(coord:Vector2i)->Array[Dictionary]:
	var old:=super.props_for_chunk(coord)
	if before:return old
	var result:Array[Dictionary]=[]
	for entry in old:
		if not str(entry.id).begins_with("clearing:"):result.append(entry)
	# Replace historical 480-radius exclusion/sample ring with the same ordinary grid,
	# except a small irregular safe footprint. No special ground or decoration layout.
	var first:=Vector2i(Vector2(coord)*CHUNK_PX/PROP_STEP)
	for y in range(first.y,first.y+CHUNK_PX/PROP_STEP):
		for x in range(first.x,first.x+CHUNK_PX/PROP_STEP):
			var point:=Vector2((x+.18+random_at(x,y,1)*.64)*PROP_STEP,(y+.18+random_at(x,y,2)*.64)*PROP_STEP)
			var distance:=point.distance_to(spawn)
			if distance>=480 or distance<105+random_at(x,y,910)*75:continue
			var v:=sample(point)
			if v.z>.03:continue
			var roll:=random_at(x,y,3)
			var cluster:=smoothstep(-.4,.35,detail.get_noise_2dv(point))
			var kind:=-1
			if roll<(.025+v.x*.65)*cluster:kind=0 if random_at(x,y,7)<.7 else 1
			elif roll>.72 and roll<.75+v.y*.22*cluster:kind=2 if random_at(x,y,7)<.7 else 3
			elif roll>.96:kind=4+mini(2,int(random_at(x,y,8)*3))
			if kind>=0:result.append({"position":point,"kind":kind,"scale":.8+random_at(x,y,5)*.35,"id":"%d:%d"%[x,y]})
	return result
''',encoding='utf-8')
s=Path('scripts/terrain.gdshader').read_text(encoding='utf-8');s=s.replace(' float safe=1.-smoothstep(200.,470.,distance(p,ground_origin));\n base=mix(base,sample_ground(spawn_tex,p),safe);','')
start=s.index(' base=mix(base,shore,');end=s.index(' COLOR=',start)
s=s[:start]+''' // Existing horizontal water mask and ground plates stay in world coordinates.
 float wet=smoothstep(.035,.30,w.a);
 vec3 sand=mix(shore,vec3(.62,.57,.40),.38);
 base=mix(base,sand,wet*.90);
 // Far (north) shore has a short inward slope; near shore reads as a lip.
 float south=texture(TEXTURE,UV+vec2(0.,TEXTURE_PIXEL_SIZE.y*.65)).a;
 float north=texture(TEXTURE,UV-vec2(0.,TEXTURE_PIXEL_SIZE.y*.65)).a;
 float far_bank=smoothstep(.002,.025,south-north);
 float bank_band=smoothstep(.12,.23,w.a)*(1.-smoothstep(.30,.43,w.a));
 base=mix(base,sand*vec3(.78,.80,.77),bank_band*far_bank*.62);
 vec3 shallow=mix(vec3(.43,.67,.62),sand,.22);
 vec3 deep=vec3(.22,.47,.54);
 vec3 water=mix(shallow,deep,smoothstep(.48,.95,w.a));
 // Quiet submerged marks use the approved shore painting, no new texture source.
 float bottom=(1.-smoothstep(.50,.76,w.a))*.12;
 water=mix(water,shore*vec3(.78,.95,.91),bottom);
 float line=pow(max(0.,sin(p.y*.105+sin(p.x*.008)*1.1)),22.);
 float broken=smoothstep(.78,.96,sin(p.x*.018+sin(p.y*.012))*.5+.5);
 water+=vec3(.055,.070,.061)*line*broken*smoothstep(.48,.65,w.a);
 base=mix(base,water,smoothstep(.34,.61,w.a));
'''+s[end:];(p/'terrain.gdshader').write_text(s,encoding='utf-8')
(p/'preview.tscn').write_text('''[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://prototypes/view-v01/preview.gd" id="1"]
[node name="ViewReview" type="Node2D"]
script = ExtResource("1")
''',encoding='utf-8')
(p/'preview.gd').write_text('''extends "res://prototypes/view-v01/world_base.gd"
var review_ready:=false
var review_label:=Label.new()
func load_world_identity(path:String=WORLD_ID_PATH)->void:
	world_seed=271828
	map_cells=1024
func save_world_identity(_path:String=WORLD_ID_PATH)->void:pass
func _ready()->void:
	super._ready()
	player.automated=true
	player.camera.position_smoothing_enabled=false
	while not started:await get_tree().process_frame
	for i in 8:await get_tree().process_frame
	ui.hide()
	var layer:=CanvasLayer.new();add_child(layer);layer.add_child(review_label)
	review_label.position=Vector2(18,14)
	review_label.add_theme_font_size_override("font_size",17)
	review_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	review_label.add_theme_constant_override("shadow_offset_x",1)
	review_label.add_theme_constant_override("shadow_offset_y",2)
	review_label.text=("旧版" if Engine.get_meta("view_before",false) else "候选 · 待确认")+"  1旧版 / 2候选 · 3出生 / 4湖岸 / 5森林 / 6山地 · WASD移动\n同Seed 271828 · 原相机/角色/尺度 · 湖泊 %d / 原%d"%[generator.lakes.size(),generator.original_lake_count]
	review_ready=true
	goto_view(int(Engine.get_meta("view_location",3)))
func goto_view(which:int)->void:
	Engine.set_meta("view_location",which)
	var point:=generator.spawn
	if which==4:
		var original:=WildGenerator.new(world_seed,map_cells)
		for lake in original.lakes:
			if original.random_at(roundi(lake.x),roundi(lake.y),934)>=.5:continue
			# Pick the same retained lake and land position in both modes.
			point=Vector2(lake.x,lake.y-lake.w*.95)
			while not generator.can_walk(point,30):point.y-=12
			break
	if which in [5,6]:
		for site in generator.region_sites.values():
			var pos:=Vector2(site.x,site.y)
			if int(site.z)==which-5 and pos.x>1500 and pos.y>1500 and pos.x<generator.extent-1500 and pos.y<generator.extent-1500 and generator.can_walk(pos,30):point=pos;break
	player.position=point
	player.camera.reset_smoothing()
	stream.update_target(point)
func _unhandled_input(event:InputEvent)->void:
	if not review_ready:return
	if event is InputEventKey and event.pressed:
		if event.physical_keycode in [KEY_1,KEY_2]:
			Engine.set_meta("view_before",event.physical_keycode==KEY_1)
			get_tree().reload_current_scene()
		elif event.physical_keycode in [KEY_3,KEY_4,KEY_5,KEY_6]:goto_view(event.physical_keycode-KEY_0)
''',encoding='utf-8')
Path('Start-View-Preview.cmd').write_text('@echo off\nstart "" "D:\\Godot_v4.7.2-stable_win64.exe\\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." res://prototypes/view-v01/preview.tscn -- --seed=271828\n',encoding='utf-8')
print('isolated preview prepared')
