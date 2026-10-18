extends SceneTree
const OUT := "res://reports/camp-build-v4/"
var results: Array=[]
func _initialize(): call_deferred("run")
func surface_view(renderer: Node2D, reference: bool) -> SubViewport:
	var view := SubViewport.new();view.size=Vector2i(256,256);view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var bg := ColorRect.new();bg.size=Vector2(256,256);bg.color=Color(.25,.5,.25);view.add_child(bg)
	var origin := Node2D.new();origin.position=Vector2(128,144);view.add_child(origin)
	if reference:
		var face := Node2D.new();origin.add_child(face)
		face.draw.connect(func():
			var r: Dictionary=renderer.manager.states.gate
			var points: PackedVector2Array=renderer.leaf_points(renderer.gate_angle)
			var a: Vector2=points[0];var b: Vector2=points[1]
			var span: float=b.x-a.x;var side := absf(span)<8
			if side:
				var left := (a.x+b.x)*.5-4
				var top := minf(a.y,b.y)-40
				var height := absf(b.y-a.y)+40
				var image: Texture2D=renderer.texture(10)
				face.draw_polygon(PackedVector2Array([Vector2(left,top),Vector2(left+8,top),Vector2(left+8,top+height),Vector2(left,top+height)]),PackedColorArray([renderer.gate_tint(),renderer.gate_tint(),renderer.gate_tint(),renderer.gate_tint()]),PackedVector2Array([Vector2(.30,.12),Vector2(.72,.12),Vector2(.72,.92),Vector2(.30,.92)]),image)
				return
			var uv_left := .30 if side else .16;var uv_right := .72 if side else .89
			var uv_bottom := .92 if side else .94
			var image: Texture2D=renderer.texture(10 if side else 7 if r.kind=="stone_gate" else 9)
			face.draw_polygon(PackedVector2Array([a-Vector2(0,40),b-Vector2(0,40),b,a]),PackedColorArray([renderer.gate_tint(),renderer.gate_tint(),renderer.gate_tint(),renderer.gate_tint()]),PackedVector2Array([Vector2(uv_left,.12),Vector2(uv_right,.12),Vector2(uv_right,uv_bottom),Vector2(uv_left,uv_bottom)]),image))
	else:
		for i in 24:
			var part := Node2D.new();origin.add_child(part);part.draw.connect(renderer.draw_leaf_strip.bind(part,i))
	return view
func run():
	for kind in ["stone_gate","fence_gate"]:
		for vertical in [false,true]:
			for hinge in [0,1]:
				for swing in [-1,1]:
					for phase in [0.0,.15,.5,.85,1.0]:
						var manager=preload("res://scripts/camp_buildings.gd").new()
						var row: Dictionary=manager.candidate(kind,Vector2.ZERO,vertical,true,0);row.hinge_end=hinge;row.swing=swing
						manager.states.gate=row
						var renderer=preload("res://scripts/camp_building.gd").new();renderer.manager=manager;renderer.building_id="gate";renderer.gate_angle=preload("res://scripts/camp_grid.gd").gate_base(row)+PI*.5*swing*phase
						var actual := surface_view(renderer,false);var expected := surface_view(renderer,true)
						for i in 3: await process_frame
						await RenderingServer.frame_post_draw
						var a := actual.get_texture().get_image();var b := expected.get_texture().get_image()
						var bad := 0;var maximum := 0.0
						for y in 256:
							for x in 256:
								var c := a.get_pixel(x,y);var d := b.get_pixel(x,y);var delta := maxf(absf(c.r-d.r),maxf(absf(c.g-d.g),absf(c.b-d.b)))
								maximum=maxf(maximum,delta)
								if delta>3.1/255: bad+=1
						var name_value := "%s-%s-h%d-s%d-p%s"%[kind,vertical,hinge,swing,str(phase)]
						results.append({"case":name_value,"pixels_over_tolerance":bad,"max_channel_difference":maximum,"pass":bad==0})
						if phase in [.5,1.0]: a.save_png(OUT+"surface-"+name_value+".png")
						actual.free();expected.free();renderer.body.free();renderer.shape.free();renderer.leaf.free();renderer.damage.free();renderer.free();await process_frame
	var failed: Array=results.filter(func(v): return not v.pass)
	FileAccess.open(OUT+"surface-pixels.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":results,"failed":failed.size()},"  "))
	print("SURFACE PIXELS: ",results.size()," cases, ",failed.size()," failed; reference is one continuous textured face")
	quit(0 if failed.is_empty() else 1)
