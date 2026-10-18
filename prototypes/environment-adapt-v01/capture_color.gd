extends SceneTree
var lab:Node2D
var checks:Array=[]
const OUT='res://reports/environment-contact-color-v01/'
func _initialize()->void:call_deferred('run')
func check(ok:bool,name:String)->void:
	checks.append({'name':name,'pass':ok})
	if not ok:push_error(name)
func shot(name:String)->void:
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+'.png')
func run()->void:
	root.size=Vector2i(1280,720)
	lab=load('res://prototypes/environment-adapt-v01/color_study.tscn').instantiate();root.add_child(lab)
	for i in 5:await process_frame
	lab.hero.get_node('AnimationPlayer').pause();lab.hero.get_node('AnimationPlayer').seek(0.,true)
	for surface in ['grass','forest','dirt']:
		lab.set_surface(surface)
		lab.set_color_fit(0.);await shot(surface+'-before')
		lab.set_color_fit(1.);await shot(surface+'-after')
		lab.objects.hide();lab.title.hide();lab.label.hide()
		for s in lab.shadows:s.hide()
		await shot(surface+'-pure-ground')
		lab.objects.show();lab.title.show();lab.label.show()
		for s in lab.shadows:s.show()
		for p in lab.samples:
			check(p.mat==p.contact.material,'one consistent upper/root material '+surface+' '+p.variant_id)
			check(p.collision.polygon==lab.Catalog.footprint(p.variant_id),'unchanged collision '+surface+' '+p.variant_id)
			if p.kind==1:
				check(lab.stream.interaction_target(p.position+Vector2(0,34))==null,'stone remains collision-only '+surface+' '+p.variant_id)
	# Camera filtering must keep using the currently drawn ground, no old screenshot colors.
	lab.set_surface('forest')
	for zoom in [.65,1.65]:
		lab.camera.zoom=Vector2.ONE*zoom
		await shot('forest-zoom-'+str(zoom))
	lab.camera.zoom=Vector2.ONE
	var p:Node2D=lab.samples[0];var before:=p.global_transform;var contact:Transform2D=p.contact.global_transform
	p.hit();var tw:Tween=p.active;tw.pause()
	for f in 14:
		tw.custom_step(.04);await process_frame
		check(p.global_transform==before and p.contact.global_transform==contact,'colored contact remains fixed '+str(f))
		check(p.modulate==Color.WHITE and p.upper.modulate==Color.WHITE,'no hit color/white flash '+str(f))
		await shot('hit-%02d'%f)
	check(p.state=='idle' and absf(float(p.mat.get_shader_parameter('bend')))<.001,'colored tree returns to rest')
	p.fade_out();tw=p.active;tw.pause();tw.custom_step(.35)
	await shot('tree-removed')
	check(not p.visible and p.modulate.a<.001,'all colored contact disappears with tree')
	check(lab.get_node('ContactPureGroundCopy').z_index==-2,'pure ground copy before shadows and objects')
	FileAccess.open(OUT+'runtime.json',FileAccess.WRITE).store_string(JSON.stringify({'engine':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name(),'checks':checks,'failures':checks.filter(func(c):return not c['pass']).size(),'status':'pending_user','approach':'one live pure terrain screen copy; fragment-local hue/value adaptation of existing contact art; no new raster art'},'  '))
	lab.queue_free();await process_frame;quit()
