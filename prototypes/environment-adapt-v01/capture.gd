extends SceneTree
var lab:Node2D
var checks:Array=[]
const FOLDER='res://reports/environment-adapt-v01/'
func _initialize()->void:call_deferred('run')
func check(ok:bool,name:String,detail:Variant='')->void:
	checks.append({'name':name,'pass':ok,'detail':detail})
	if not ok:push_error(name+' '+str(detail))
func shot(name:String)->void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(FOLDER+name+'.png')
func run()->void:
	root.size=Vector2i(1280,720)
	lab=load('res://prototypes/environment-adapt-v01/study.tscn').instantiate();root.add_child(lab)
	for i in 5:await process_frame
	lab.hero.get_node('AnimationPlayer').pause();lab.hero.get_node('AnimationPlayer').seek(0.,true)
	var probe:=CharacterBody2D.new();var collider:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=10.;collider.shape=circle;probe.add_child(collider);root.add_child(probe)
	probe.position=Vector2(-2000,-2000)
	for surface in ['grass','forest','dirt']:
		lab.set_surface(surface)
		for i in 3:await physics_frame
		check(lab.samples.size()==9,'nine selected objects '+surface)
		check(lab.Catalog.IDS.find('tree_02')==-1,'rejected tree excluded '+surface)
		await shot(surface)
		lab.show_collisions=true;lab.collision_view.queue_redraw();await shot(surface+'-collision')
		lab.show_collisions=false;lab.collision_view.queue_redraw()
		for p in lab.samples:
			var id:String=p.variant_id
			for dir in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				probe.position=p.position+dir*120.
				await physics_frame
				var hit:=probe.move_and_collide(-dir*120.)
				check(hit!=null and hit.get_collider().get_parent()==p,'10px feet blocked '+surface+' '+id+' '+str(dir))
			probe.position=Vector2(-2000,-2000);await physics_frame
			if p.kind==1:
				var target:Node2D=lab.stream.interaction_target(p.position+Vector2(0,34))
				check(target==null,'ordinary rock not selected by E '+surface+' '+id)
				var t:Transform2D=p.global_transform;p.hit();p.remove_rock();p.fade_out()
				check(p.active==null and p.global_transform==t and p.visible and not p.collision.disabled,'ordinary rock has no hit removal or harvesting '+surface+' '+id)
			else:
				probe.position=p.position+Vector2(-100,-100);await physics_frame
				var hit:=probe.move_and_collide(Vector2(200,0))
				check(hit==null,'crown does not block feet '+surface+' '+id)
				probe.position=Vector2(-2000,-2000)
	# Render and check one full root-locked sway for each retained shape on forest.
	lab.set_surface('forest');await physics_frame
	for n in 3:
		var p:Node2D=lab.samples[n];var fixed:Transform2D=p.contact.global_transform;var before:=p.global_transform
		p.hit();var tw:Tween=p.active;tw.pause()
		for f in 14:
			tw.custom_step(.04);await process_frame
			check(p.global_transform==before and p.contact.global_transform==fixed,'fixed root '+str(n)+' '+str(f))
			check(p.modulate==Color.WHITE and p.upper.modulate==Color.WHITE,'no flash '+str(n)+' '+str(f))
			await shot('tree-%d-hit-%02d'%[n+1,f])
		check(p.state=='idle' and absf(float(p.mat.get_shader_parameter('bend')))<.001,'tree returns to rest '+str(n))
		var at:Vector2=p.position+Vector2(0,34)
		check(lab.stream.interaction_target(at)==p,'formal reach picker sees tree '+str(n))
		var required:=int(p.get_meta('required_hits'))
		var drops_before:int=lab.stream.drops.size()
		for i in required:lab.stream.chop_tree(p)
		check(int(lab.stream.tree_hits[p.variant_id])==required and lab.stream.drops.size()-drops_before==required/2,'existing 2-hit/4-hit wood cadence '+str(n))
		tw=p.active;tw.pause()
		for f in 10:
			tw.custom_step(.035);await process_frame
			check(p.modulate.r==1. and p.modulate.g==1. and p.modulate.b==1. and p.rotation==0.,'alpha-only removal '+str(n)+' '+str(f))
		check(not p.visible and not p.is_in_group('trees') and p.collision.disabled,'tree and collision removed '+str(n))
	var drop:Node2D=lab.stream.drops[0];var count:int=lab.stream.collected_wood
	lab.stream.pickup_drop(drop)
	check(lab.stream.collected_wood==count+1,'active wood pickup retained')
	probe.queue_free();lab.reset_props()
	await shot('final-selected-forest')
	var failures:=checks.filter(func(c):return not c['pass']).size()
	FileAccess.open(FOLDER+'runtime.json',FileAccess.WRITE).store_string(JSON.stringify({'engine':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name(),'checks':checks,'failures':failures,'status':'new_adapters_pending_user','scope':'selected shapes, three contact plates, real physics footprint tests, formal reach picker; formal world untouched','version':lab.Catalog.VERSION},'  '))
	lab.queue_free();await process_frame;quit(1 if failures else 0)
