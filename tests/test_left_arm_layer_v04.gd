extends SceneTree
const OUT := "res://reports/left-arm-layer-v04/"
var checks: Array=[]
var before: Node2D
var after: Node2D
var view: SubViewport
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func pose(actor: Node2D,clip: String,t: float,mirror: bool=false) -> void:
	var visual: Node2D=actor.get_node("Visual")
	visual.scale.x=-1 if mirror else 1
	visual.position.x=128 if mirror else 0
	var animation: AnimationPlayer=actor.get_node("AnimationPlayer")
	animation.play(clip);animation.seek(t,true);animation.pause()
	if actor.has_node("Visual/Pelvis/ArmL/RearVisualDrive"):
		actor.get_node("Visual/Pelvis/ArmL/RearVisualDrive").force_update_cache()
	actor.get_node("Visual/Pelvis/ArmR/Grip/Axe").hide()
func image(actor: Node2D,clip: String,t: float,mirror: bool=false) -> Image:
	before.hide();after.hide();actor.show()
	pose(actor,clip,t,mirror)
	await frame()
	return view.get_texture().get_image()
func probe(actor: Node2D,arm: Sprite2D) -> Color:
	before.hide();after.hide();actor.show()
	actor.get_node("AnimationPlayer").free()
	if actor.has_node("Visual/Pelvis/ArmL/RearVisualDrive"): actor.get_node("Visual/Pelvis/ArmL/RearVisualDrive").free()
	await frame()
	for node in actor.find_children("*","Sprite2D",true,false): node.hide()
	var red := Image.create(8,8,false,Image.FORMAT_RGBA8);red.fill(Color.RED)
	var blue := Image.create(8,8,false,Image.FORMAT_RGBA8);blue.fill(Color.BLUE)
	arm.texture=ImageTexture.create_from_image(red);arm.show()
	var leg: Sprite2D=actor.get_node("Visual/LegL/Sprite")
	leg.texture=ImageTexture.create_from_image(blue);leg.show()
	arm.global_transform=Transform2D(0,Vector2(128,128))
	leg.global_transform=arm.global_transform
	actor.reset_physics_interpolation()
	await frame()
	var sample := view.get_texture().get_image()
	sample.save_png(OUT+("probe-before.png" if actor==before else "probe-after.png"))
	return sample.get_pixel(128,128)
func run() -> void:
	Engine.max_fps=60
	view=SubViewport.new();view.size=Vector2i(256,256);view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	before=load(OUT+"character-before.tscn").instantiate()
	after=load("res://assets/hero/cartoon/character.tscn").instantiate()
	for actor in [before,after]:
		actor.position=Vector2(0,0);actor.scale=Vector2.ONE*2
		actor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
		view.add_child(actor)
	check(after.get_node("Visual/ArmLBehind").get_index()<after.get_node("Visual/LegL").get_index(),"rear arm draws before left leg sibling")
	check(after.get_node("Visual/ArmLBehind").show_behind_parent,"rear arm shares behind-parent pass with legs")
	check(after.get_node("Visual/ArmLBehind").z_index==0,"rear arm keeps world Y sort depth without global negative z")
	var clips: PackedStringArray=after.get_node("AnimationPlayer").get_animation_list()
	check(clips.size()==18,"all eighteen approved clips retained")
	for clip in clips:
		var duration: float=after.get_node("AnimationPlayer").get_animation(clip).length
		for phase in [.0,.35,.72]:
			for mirror in [false,true]:
				pose(before,clip,duration*phase,mirror)
				pose(after,clip,duration*phase,mirror)
				await frame()
				var old: Sprite2D=before.get_node("Visual/Pelvis/ArmL/Sprite")
				var revised: Sprite2D=after.get_node("Visual/ArmLBehind")
				check(old.global_transform.is_equal_approx(revised.global_transform),"same arm pose "+clip+" "+str(phase)+" mirrored="+str(mirror))
				check(old.texture==revised.texture and old.flip_h==revised.flip_h,"same texture and flip "+clip+" "+str(phase)+" mirrored="+str(mirror))
	# Four views, before/after idle and one meaningful walk phase.
	var board := Image.create(1024,1024,false,Image.FORMAT_RGBA8)
	board.fill(Color("f3ead4"))
	for row in 4:
		var facing: String=["front","side","side","back"][row]
		for col in 4:
			var actor: Node2D=before if col%2==0 else after
			var clip := facing+("_breathe" if col<2 else "_walk")
			var capture: Image=await image(actor,clip,.24,row==2)
			board.blend_rect(capture,Rect2i(0,0,256,256),Vector2i(col*256,row*256))
	board.save_png(OUT+"before-after-four-directions.png")
	var old_pixel: Color=await probe(before,before.get_node("Visual/Pelvis/ArmL/Sprite"))
	var new_pixel: Color=await probe(after,after.get_node("Visual/ArmLBehind"))
	check(old_pixel.r>.9 and old_pixel.b<.1,"old draw order paints arm over leg at identical overlap")
	check(new_pixel.b>.9 and new_pixel.r<.1,"new draw order paints leg over rear arm at identical overlap")
	var failed := 0
	for row in checks:
		if not row.pass: failed+=1
	var file := FileAccess.open(OUT+"tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"count":checks.size(),"failures":failed,"checks":checks},"  "));file.close()
	print("LEFT_ARM ",checks.size()," checks; ",failed," failures")
	view.queue_free()
	for i in 4: await process_frame
	quit(0 if failed==0 else 1)
