extends SceneTree
var lab:Node2D
var checks:Array=[]
const OUT='res://reports/environment-contact-natural-v01/'
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
	lab=load('res://prototypes/environment-contact-natural-v01/study.tscn').instantiate();root.add_child(lab)
	for i in 5:await process_frame
	lab.hero.get_node('AnimationPlayer').pause();lab.hero.get_node('AnimationPlayer').seek(0.,true)
	for surface in ['grass','forest','dirt']:
		lab.set_surface(surface);lab.set_layout(false);await shot(surface+'-before')
		lab.set_layout(true);await shot(surface+'-after')
		for p in lab.samples:
			check(p.texture.resource_path.begins_with(lab.NEW_FOLDER),'natural contact asset '+surface+' '+p.variant_id)
			check(p.collision.polygon==lab.Catalog.footprint(p.variant_id),'unchanged footprint '+surface+' '+p.variant_id)
			check(p.mat==p.contact.material and p.mat.get_shader_parameter('color_fit')==1.,'approved live-ground color active '+surface+' '+p.variant_id)
			if p.kind==1:
				check(lab.stream.interaction_target(p.position+Vector2(0,34))==null,'stone remains collision-only '+surface+' '+p.variant_id)
		lab.show_collisions=true;lab.collision_view.queue_redraw();await shot(surface+'-collision')
		lab.show_collisions=false;lab.collision_view.queue_redraw()
	lab.set_surface('forest')
	for n in 3:
		var p:Node2D=lab.samples[n];var t:=p.global_transform;var c:Transform2D=p.contact.global_transform
		p.hit();var tw:Tween=p.active;tw.pause()
		for f in 14:
			tw.custom_step(.04);await process_frame
			check(p.global_transform==t and p.contact.global_transform==c,'all new grass/litter stays rooted '+str(n)+' '+str(f))
			check(p.modulate==Color.WHITE and p.upper.modulate==Color.WHITE,'no white flash '+str(n)+' '+str(f))
			if n==0:await shot('hit-%02d'%f)
		check(p.state=='idle' and absf(float(p.mat.get_shader_parameter('bend')))<.001,'sway settles '+str(n))
	var tree:Node2D=lab.samples[0];tree.fade_out();var tw:Tween=tree.active;tw.pause();tw.custom_step(.35)
	await shot('tree-removed');check(not tree.visible,'new contact disappears with tree')
	FileAccess.open(OUT+'runtime.json',FileAccess.WRITE).store_string(JSON.stringify({'engine':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name(),'checks':checks,'failures':checks.filter(func(c):return not c['pass']).size(),'status':'selected_art_integrated','scope':'isolated asset gallery; formal world evidence in reports/environment-game-v01'},'  '))
	lab.queue_free();await process_frame;quit()
