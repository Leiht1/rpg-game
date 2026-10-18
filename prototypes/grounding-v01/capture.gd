extends SceneTree
const Study=preload("res://prototypes/grounding-v01/prop.gd")
var w:Node2D
var selected:Array=[]
var shadow:Node2D
var checks:Array=[]
var records:Array=[]
var before_shapes:={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func settle()->void:
	w.stream.update_target(w.player.position)
	var timeout:=Time.get_ticks_msec()+30000
	while not w.stream.viewport_ready(w.player.position,Vector2(780,520)) and Time.get_ticks_msec()<timeout:await process_frame
	while not w.started:await process_frame
	for i in 8:await process_frame
func toggle(on:bool)->void:
	for prop in selected:prop.enabled=on;prop.queue_redraw()
	shadow.enabled=on;shadow.queue_redraw()
	for packet in w.stream.loaded.values():packet.terrain.material.set_shader_parameter("study_on",1.0 if on else 0.0)
func shot(label:String)->void:
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/grounding-v01/"+label+".png")
func run()->void:
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	w.player.automated=true;w.player.camera.position_smoothing_enabled=false
	await settle()
	var path:PackedVector2Array=w.generator.connections[0]
	w.player.position=path[0]+(path[1]-path[0]).normalized()*2050.
	w.player.reset_physics_interpolation();w.player.camera.reset_smoothing()
	await settle()
	# Select a real nearby mixed pair, without relocating or spawning scenery.
	var best:=INF
	var focus:Vector2=w.player.position
	for t in get_nodes_in_group("trees"):
		for r in get_nodes_in_group("rocks"):
			var gap:float=t.position.distance_to(r.position)
			if gap<420.:
				var score:float=(t.position+r.position).distance_to(w.player.position*2.)+gap
				if score<best:best=score;focus=(t.position+r.position)*.5
	w.player.position=focus+Vector2(230,220)
	w.player.reset_physics_interpolation();w.player.camera.reset_smoothing()
	await settle()
	var candidates:Array=[]
	for group in ["trees","rocks"]:
		for p in get_nodes_in_group(group):
			if absf(p.position.x-w.player.position.x)<610 and absf(p.position.y-w.player.position.y)<380:candidates.append(p)
	candidates.sort_custom(func(a,b):return a.position.distance_squared_to(w.player.position)<b.position.distance_squared_to(w.player.position))
	for p in candidates.slice(0,12):
		var vals:={"texture":p.texture,"display_size":p.display_size,"kind":p.kind,"detail_seed":p.detail_seed,"candidate_mode":p.candidate_mode,"faded":p.faded}
		before_shapes[p.name]={"position":p.position,"polygon":p.get_node("FootprintBody/Footprint").polygon}
		p.set_script(Study)
		for key in vals:p.set(key,vals[key])
		var weights:Vector4=w.generator.sample(p.position)
		p.environment=Color(.40,.49,.28)*weights.x+Color(.52,.54,.37)*weights.y+Color(.52,.63,.30)*weights.w
		p.environment.a=1.
		p.prepare();selected.append(p)
		records.append({"id":p.get_meta("prop_id"),"kind":p.kind,"position":[p.position.x,p.position.y],"foot":[p.foot.x,p.foot.y],"width":p.footprint,"detail_seed":p.detail_seed})
	shadow=load("res://prototypes/grounding-v01/shadows.gd").new();shadow.z_index=-1;shadow.props=selected;w.stream.add_child(shadow)
	# Candidate shader: only selected objects' local ground, same world coordinates in every chunk.
	var code:=FileAccess.get_file_as_string("res://scripts/terrain.gdshader")
	code=code.replace("varying vec2 world_p;","uniform float study_on=0.;\nuniform vec2 study_points[12];\nuniform int study_count=0;\nvarying vec2 world_p;")
	var addition:="\n float quiet=0.;\n for(int i=0;i<12;i++){if(i>=study_count)break;quiet=max(quiet,1.-smoothstep(22.,100.,distance(p,study_points[i])));}\n vec3 calm=(sample_ground(meadow_tex,p+vec2(18.,0.))+sample_ground(meadow_tex,p-vec2(18.,0.))+sample_ground(meadow_tex,p+vec2(0.,18.))+sample_ground(meadow_tex,p-vec2(0.,18.)))*w.b;\n calm+=(sample_ground(forest_tex,p+vec2(18.,0.))+sample_ground(forest_tex,p-vec2(18.,0.))+sample_ground(forest_tex,p+vec2(0.,18.))+sample_ground(forest_tex,p-vec2(0.,18.)))*w.r;\n calm+=(sample_ground(rock_tex,p+vec2(18.,0.))+sample_ground(rock_tex,p-vec2(18.,0.))+sample_ground(rock_tex,p+vec2(0.,18.))+sample_ground(rock_tex,p-vec2(0.,18.)))*w.g;\n base=mix(base,calm/(4.*max(.001,w.r+w.g+w.b)),quiet*study_on*.42*(1.-smoothstep(.05,.3,w.a)));\n"
	code=code.replace("// A horizontal water plane",addition+"\n // A horizontal water plane")
	# Skip additional texture sampling outside the few study footprints and in baseline mode.
	code=code.replace("vec3 calm=","if(quiet*study_on>.001){\n vec3 calm=")
	code=code.replace("\n // A horizontal water plane","\n }\n // A horizontal water plane")
	var shader:=Shader.new();shader.code=code
	var centers:=PackedVector2Array()
	for p in selected:centers.append(p.position)
	while centers.size()<12:centers.append(Vector2.ZERO)
	for packet in w.stream.loaded.values():
		packet.terrain.material.shader=shader
		packet.terrain.material.set_shader_parameter("study_points",centers)
		packet.terrain.material.set_shader_parameter("study_count",selected.size())
	var tree:Node2D;var rock:Node2D
	for p in selected:
		if p.kind<2 and tree==null:tree=p
		if p.kind>=2 and rock==null:rock=p
	check(tree!=null and rock!=null,"natural mixed scene contains both types")
	if tree==null or rock==null:quit(1);return
	# Render terrain alone once with the same shader/world coordinates. No shadows,
	# sprites or UI can contaminate the per-vertex foreground ground colors.
	var bounds:=Rect2(selected[0].position,Vector2.ONE)
	for p in selected:bounds=bounds.expand(p.position)
	bounds=bounds.grow(128.)
	var origin:=bounds.position.floor()
	var ground_view:=SubViewport.new()
	ground_view.size=Vector2i(bounds.size.ceil()+Vector2.ONE*2.)
	ground_view.disable_3d=true
	ground_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	ground_view.world_2d=World2D.new()
	root.add_child(ground_view)
	ground_view.canvas_transform=Transform2D(0.,-origin)
	for packet in w.stream.loaded.values():
		var ground=packet.terrain.duplicate()
		ground.material=packet.terrain.material.duplicate()
		ground.material.set_shader_parameter("study_on",1.)
		ground_view.add_child(ground)
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	var ground_image:Image=ground_view.get_texture().get_image()
	ground_image.save_png("res://reports/grounding-v01/ground-sample.png")
	for i in selected.size():
		var p=selected[i];p.ground_image=ground_image;p.ground_origin=origin
		var c:Color=p.ground_color(p.foot)
		records[i]["sampled_ground_rgb"]=[c.r,c.g,c.b]
		check(c.g>.05 and c.r>.05,"terrain-only sample available "+p.name)
	ground_view.queue_free()
	for mode in [false,true]:
		toggle(mode)
		w.player.camera.zoom=Vector2.ONE;w.player.camera.offset=Vector2.ZERO;w.player.camera.reset_smoothing()
		await shot("normal-after" if mode else "normal-before")
		w.player.camera.zoom=Vector2.ONE*1.65
		w.player.camera.offset=(tree.position+rock.position)*.5-w.player.position+Vector2(0,-50)
		await shot("mixed-after" if mode else "mixed-before")
		for pair in [["tree",tree],["rock",rock]]:
			w.player.camera.zoom=Vector2.ONE*2.5
			w.player.camera.offset=pair[1].position-w.player.position+Vector2(0,-pair[1].display_size.y*.42)
			await shot(pair[0]+("-after" if mode else "-before"))
	for p in selected:
		check(p.position==before_shapes[p.name].position and p.get_node("FootprintBody/Footprint").polygon==before_shapes[p.name].polygon,"unchanged origin and collision "+p.name)
		var edge_copy:PackedVector2Array=p.edge.duplicate();p.prepare()
		check(edge_copy==p.edge,"stable cached alpha footprint "+p.name)
	check(w.generator.VERSION=="windrest-continent-0.6.0","generator unchanged")
	check(selected.size()<=12,"at most 12 study objects")
	# Actual unload/reinstall of one selected object's chunk using a fresh worker packet.
	var probe=selected[0]
	var probe_id:String=probe.get_meta("prop_id")
	var probe_position:Vector2=probe.position
	var probe_edge:PackedVector2Array=probe.edge.duplicate()
	var probe_seed:float=probe.detail_seed
	var probe_foot:Vector2=probe.foot
	var coord:Vector2i=w.stream.chunk_at(probe_position)
	w.stream.unload_chunk(coord)
	await process_frame
	var worker=load("res://scripts/world_generator.gd").new(w.world_seed,1024,w.generator.plan_snapshot())
	var packet:Dictionary=worker.build_chunk(coord)
	var empty:Array[Dictionary]=[];packet["ground_stamps"]=empty
	w.stream.install_chunk(packet)
	var found:=false
	for p in w.stream.loaded[coord].props:
		if p.get_meta("prop_id")==probe_id:
			var tex:Texture2D=p.texture;var size:Vector2=p.display_size;var k:int=p.kind;var ds:float=p.detail_seed
			p.set_script(Study);p.texture=tex;p.display_size=size;p.kind=k;p.detail_seed=ds;p.prepare()
			found=p.position==probe_position and p.edge==probe_edge and p.foot==probe_foot and p.detail_seed==probe_seed
	check(found,"actual chunk unload reinstall preserves position, alpha footprint and coordinate seed")
	FileAccess.open("res://reports/grounding-v01/runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"seed":w.world_seed,"center":[w.player.position.x,w.player.position.y],"checks":checks,"objects":records,"status":"pending_user","art_source":"existing approved view_v01; procedural Godot drawing; no image generation","scope":"Stage A only; no formal scripts or assets changed","max_install_ms":w.stream.max_install_ms},"  "))
	w.queue_free();await process_frame
	quit()
