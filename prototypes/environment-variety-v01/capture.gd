extends SceneTree
var lab:Node2D
var checks:Array=[]
const FOLDER='res://reports/environment-variety-v01/'
func _initialize()->void:call_deferred('run')
func check(ok:bool,label:String)->void:
	checks.append({'name':label,'pass':ok})
	if not ok:push_error(label)
func shot(label:String)->void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(FOLDER+label+'.png')
func run()->void:
	root.size=Vector2i(1280,720)
	lab=load('res://prototypes/environment-variety-v01/study.tscn').instantiate();root.add_child(lab)
	for i in 5:await process_frame
	lab.hero.get_node('AnimationPlayer').pause();lab.hero.get_node('AnimationPlayer').seek(0.,true)
	await shot('lineup')
	var shader_code:=FileAccess.get_file_as_string('res://prototypes/environment-v01/prop.gdshader')
	check(not shader_code.contains('flash') and not shader_code.contains('mix('),'no color/flash shader path')
	for n in 4:
		var p:Node2D=lab.samples[n]
		var root_transform:=p.global_transform
		var contact:Transform2D=p.contact.global_transform
		var polygon:PackedVector2Array=p.collision.polygon.duplicate()
		p.hit();var tw:Tween=p.active;tw.pause()
		for f in 16:
			tw.custom_step(.04);await process_frame
			check(p.global_transform==root_transform and p.contact.global_transform==contact,'fixed root '+str(n)+' frame '+str(f))
			check(p.collision.polygon==polygon,'fixed footprint '+str(n)+' frame '+str(f))
			check(p.modulate==Color.WHITE and p.upper.modulate==Color.WHITE and p.contact.modulate==Color.WHITE,'no color modulation '+str(n)+' frame '+str(f))
			await shot('tree-%d-hit-%02d'%[n+1,f])
		check(p.state=='idle' and absf(float(p.mat.get_shader_parameter('bend')))<.001,'returns to rest '+str(n))
		p.fade_out();tw=p.active;tw.pause()
		for f in 10:
			tw.custom_step(.035);await process_frame
			check(p.modulate.r==1. and p.modulate.g==1. and p.modulate.b==1. and p.rotation==0.,'fade alpha only '+str(n)+' frame '+str(f))
		check(not p.visible,'fully hidden '+str(n))
		await shot('tree-%d-removed'%[n+1])
		p.show();p.modulate=Color.WHITE;p.state='idle';p.collision.disabled=false;p.shadow_changed.emit()
	var failures:=checks.filter(func(c):return not c['pass']).size()
	FileAccess.open(FOLDER+'runtime.json',FileAccess.WRITE).store_string(JSON.stringify({'engine':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name(),'failures':failures,'checks':checks,'scope':'4 candidate trees/6 static ordinary rocks; no formal integration','status':'pending_user'},'  '))
	lab.queue_free();await process_frame;quit(1 if failures else 0)
