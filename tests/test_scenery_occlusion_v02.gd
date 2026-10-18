extends SceneTree
const Prop=preload("res://scripts/scenery_prop.gd")
var checks:Array=[]
const OUT="res://reports/scenery-occlusion-v02/"
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func shot(name:String)->Image:
	await RenderingServer.frame_post_draw
	var im:=root.get_texture().get_image();im.save_png(OUT+name+".png");return im
func run()->void:
	root.size=Vector2i(640,480)
	var bg:=ColorRect.new();bg.color=Color(.4,.6,.3);bg.size=Vector2(640,480);root.add_child(bg)
	var ids=["tree_01","tree_03","tree_04"]
	var largest_error:=0;var seam_failures:=0
	for id in ids:
		for surface in ["grass","forest","dirt"]:
			for ratio in [.8,1.,1.15]:
				var p:=Prop.new();p.variant_id=id;p.kind=0;p.surface=surface
				p.texture=load("res://assets/environment/contact_v01/"+id+"_"+surface+".png")
				p.display_size=p.texture.get_size()*ratio;p.position=Vector2(320.35,360.5)
				root.add_child(p);p.prepare();p.mat.set_shader_parameter("color_fit",0.)
				p.update_occlusion(p.position+Vector2(0,25));check(not p.faded,"front opaque "+id)
				p.update_occlusion(p.position+Vector2(150,0));check(not p.faded,"side opaque "+id)
				p.update_occlusion(p.position+Vector2(0,-400));check(not p.faded,"above visible crown opaque "+id)
				p.update_occlusion(p.position+Vector2(0,-45)*ratio);check(p.faded,"actual trunk overlap fades "+id)
				check(is_equal_approx(p.modulate.a,.48) and not p.contact.visible,"single whole-tree opacity "+id)
				if id=="tree_01":
					p.update_occlusion(p.position+Vector2(70,-150)*ratio);check(not p.faded,"screenshot diagonal gap stays opaque")
				# Compare GPU output against one unsplit sprite at identical position,
				# size, UV and opacity. Any doubled horizontal strip breaks this oracle.
				p.modulate.a=.48
				p.mat.set_shader_parameter("tree",false)
				var stem:String=id+"-"+surface+"-"+str(ratio)
				var actual:Image=await shot(stem+"-mesh")
				p.upper.visible=false
				var reference:=Sprite2D.new();reference.texture=p.texture;reference.centered=false
				reference.position=Vector2(-p.display_size.x*.5,-p.display_size.y+8.)
				reference.scale=Vector2.ONE*ratio;reference.material=p.mat;p.add_child(reference)
				var expected:Image=await shot(stem+"-single-sprite")
				var a:=actual.get_data();var b:=expected.get_data();var max_error:=0;var bad:=0
				for i in a.size():
					var error:=absi(int(a[i])-int(b[i]));max_error=maxi(error,max_error)
					if error>2:bad+=1
				largest_error=maxi(largest_error,max_error)
				check(bad==0,"no seam vs unsplit GPU sprite "+stem)
				if bad:seam_failures+=1
				reference.free();p.upper.visible=true;p.mat.set_shader_parameter("tree",true)
				p.fade_out();p.active.pause();p.active.custom_step(.15)
				var alpha:=p.modulate.a;p.update_occlusion(p.position+Vector2(500,500))
				check(alpha>0 and alpha<.48 and p.modulate.a==alpha,"harvest fade not reset")
				p.active.custom_step(.2);check(not p.visible and p.modulate.a==0.,"no stump after fade")
				p.free()
	var failures:=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"max_gpu_channel_error":largest_error,"seam_failures":seam_failures,"engine":Engine.get_version_info().string},"  "))
	print("OCCLUSION_V02 ",checks.size()," FAILURES ",failures," GPU_MAX_ERROR ",largest_error)
	quit(1 if failures else 0)

