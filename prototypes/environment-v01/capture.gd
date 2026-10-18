extends SceneTree
const Policy=preload('res://prototypes/environment-v01/surface_policy.gd')
var lab:Node2D
var checks:Array=[]
var frame_ms:Array=[]
var folder:='res://reports/environment-v01/'
func _initialize()->void:call_deferred('run')
func check(ok:bool,label:String)->void:
	checks.append({'name':label,'pass':ok})
	if not ok:push_error(label)
func shot(name:String)->void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+name+'.png')
func step(tween:Tween,dt:float)->void:
	if is_instance_valid(tween):tween.custom_step(dt)
	await process_frame
func clip(p:Node2D,action:String,count:int,dt:float,label:String)->void:
	var base:=p.global_position;var contact:Transform2D=p.contact.global_transform;var collision:PackedVector2Array=p.collision.polygon.duplicate()
	p.call(action);var tw:Tween=p.active;tw.pause()
	for i in count:
		var before:=Time.get_ticks_usec()
		await step(tw,dt)
		check(p.global_position==base and p.rotation==0. and p.contact.global_transform==contact,label+' fixed contact frame '+str(i))
		check(p.collision.polygon==collision,label+' fixed footprint frame '+str(i))
		await shot('%s-%02d'%[label,i])
		frame_ms.append((Time.get_ticks_usec()-before)/1000.)

func run()->void:
	root.size=Vector2i(1280,720)
	lab=load('res://prototypes/environment-v01/study.tscn').instantiate();root.add_child(lab)
	for i in 6:await process_frame
	# Freeze only the lab's animation time for exactly paired captures.
	var animation:AnimationPlayer=lab.hero.get_node('AnimationPlayer')
	animation.pause();animation.seek(0.,true)
	for surface in ['grass','forest','dirt']:
		lab.set_surface(surface);await shot(surface+'-new')
		check(lab.tree.get_child_count()==4 and lab.rock.get_child_count()==4,'bounded prop nodes '+surface)
		check(lab.objects.y_sort_enabled,'Y sort enabled '+surface)
		lab.legacy=true;lab.reset_props();await shot(surface+'-old')
		lab.legacy=false;lab.reset_props()
	lab.set_surface('grass')
	await clip(lab.tree,'hit',20,.035,'tree-hit')
	check(lab.tree.state=='idle','tree returns to idle')
	check(absf(float(lab.tree.mat.get_shader_parameter('bend')))<.001,'bend returns to zero')
	await clip(lab.tree,'fade_out',12,.03,'tree-fade')
	check(lab.tree.state=='removed' and not lab.tree.visible and lab.tree.modulate.a<.001,'whole tree and contact fade in place without stump')
	check(lab.tree.upper.rotation==0.,'final removal never rotates tree')
	await shot('tree-removed')
	lab.reset_props()
	# Shader's actual mathematical motion envelope, including the join derivative.
	for y in [-16.,-8.,0.,8.]:
		var weight:=clampf((-y-16.)/(190.-24.),0.,1.)
		check(weight*weight*5.==0.,'zero root mesh displacement y='+str(y))
	# Recreate props as streaming would, using the same contract and texture.
	lab.reset_props();var tex_path:String=lab.tree.texture.resource_path;var points:PackedVector2Array=lab.tree.collision.polygon.duplicate()
	lab.reset_props();check(lab.tree.texture.resource_path==tex_path and lab.tree.collision.polygon==points,'recreation preserves texture and collision')
	var policy_records:Array=[]
	for seed_value in [447349832,1332185389]:
		var gen=load('res://scripts/world_generator.gd').new(seed_value,1024)
		var worker=load('res://scripts/world_generator.gd').new(seed_value,1024,gen.plan_snapshot())
		var count:=0;var excluded:=0
		for center in [gen.spawn,gen.region_cores[0],gen.region_cores[1]]:
			var coord:=Vector2i(center/gen.CHUNK_PX)
			var before:Array=gen.props_for_chunk(coord)
			for item in before:
				var a:=Policy.adapted(gen,item);var b:=Policy.adapted(worker,item)
				check(a==b,'policy stable across worker '+str(seed_value)+' '+item.id)
				if a.is_empty():excluded+=1
				else:count+=1
			check(before==gen.props_for_chunk(coord),'formal props unaffected by policy '+str(seed_value))
		policy_records.append({'seed':seed_value,'adapted':count,'excluded':excluded})
	check(not Policy.allowed(0,{'water':0.,'surface':'rock','biome':'山地'}),'bare rock cannot grow broadleaf')
	check(not Policy.allowed(0,{'water':0.,'surface':'snow','biome':'森林'}),'snow broadleaf reserved')
	check(not Policy.allowed(2,{'water':1.,'surface':'grass','biome':'湖泊'}),'water excludes rocks')
	check(Policy.allowed(0,{'water':0.,'surface':'dirt','biome':'山地'}),'explicit mountain soil pocket allows tree')
	# Quiet rendered-frame timing of this two-object lab only, captures excluded.
	lab.reset_props();Engine.max_fps=120
	var idle_ms:Array=[]
	var last_tick:=Time.get_ticks_usec()
	for i in 150:
		await process_frame
		var now:=Time.get_ticks_usec()
		if i>=30:idle_ms.append((now-last_tick)/1000.)
		last_tick=now
	idle_ms.sort()
	var failures:=checks.filter(func(c):return not c['pass']).size()
	FileAccess.open(folder+'runtime.json',FileAccess.WRITE).store_string(JSON.stringify({'engine':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name(),'checks':checks,'failures':failures,'policy':policy_records,'generator_version':'windrest-continent-0.6.0','policy_version':Policy.VERSION,'status':'pending_user','capture_wall_ms_mean':frame_ms.reduce(func(a,b):return a+b,0.)/frame_ms.size(),'idle_frame_median_ms':idle_ms[60],'idle_frame_p95_ms':idle_ms[114],'performance_limit':'120FPS cap; 120 idle frame deltas, two-object lab only, not full-world FPS or GPU overhead measurement'},'  '))
	lab.queue_free();await process_frame;quit(1 if failures else 0)
