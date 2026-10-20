extends SceneTree
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var preview=load("res://preview.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	var rig=preview.rigs[0]
	var ap:AnimationPlayer=rig.get_node("AnimationPlayer")
	check(ap.get_animation_list().size()==8,"Eight direction/action clips")
	var peak_idle:=0.0
	var stance_error:=0.0
	var max_scale:=0.0
	for d in ["front","side"]:
		for action in ["breathe","walk","run","wave"]:
			var n:String=d+"_"+action
			var anim:=ap.get_animation(n)
			check(anim.loop_mode==Animation.LOOP_LINEAR,n+" loops")
			for ti in anim.get_track_count():
				var count:=anim.track_get_key_count(ti)
				if count>1:
					var first=anim.track_get_key_value(ti,0)
					var last=anim.track_get_key_value(ti,count-1)
					check(is_equal_approx(first,last) if first is float else first.is_equal_approx(last),n+" seamless "+str(anim.track_get_path(ti)))
			ap.play(n)
			ap.pause()
			var leg:Node2D=rig.get_node("Visual/LegL")
			ap.seek(0,true)
			var base:=leg.transform*Vector2(0,20)
			for k in 128:
				var t:=float(k)/128.0
				ap.seek(t*anim.length,true)
				for j in 2:
					var l:Node2D=rig.get_node("Visual/Leg"+("L" if j==0 else "R"))
					var foot:=l.transform*Vector2(0,20)
					if action=="breathe":peak_idle=maxf(peak_idle,foot.distance_to(base) if j==0 else absf(foot.y-112))
					if action in ["walk","run"]:
						max_scale=maxf(max_scale,absf(l.scale.y-1.0))
						if fposmod(t+j*.5,1.0)<.58:stance_error=maxf(stance_error,absf(foot.y-112))
	check(peak_idle<0.001,"Idle feet fixed")
	check(stance_error<0.04,"Stance nominal contact height within .04 pixels")
	for d in ["front","side","left"]:
		preview.set_direction(d)
		check(preview.facing==d,"Direction "+d)
		for a in ["breathe","walk","run","wave"]:
			preview.set_action(a)
			check(ap.current_animation==("front" if d=="front" else "side")+"_"+a,"Control "+d+a)
	for b in preview.find_children("*","Button",true,false):
		b.pressed.emit()
		if b.text=="正面":check(preview.facing=="front","Front button binding")
		if b.text=="右侧":check(preview.facing=="side","Right button binding")
		if b.text=="左侧":check(preview.facing=="left","Left button binding")
		if b.text=="呼吸":check(preview.action=="breathe","Breathe button binding")
		if b.text=="行走":check(preview.action=="walk","Walk button binding")
		if b.text=="奔跑":check(preview.action=="run","Run button binding")
		if b.text=="挥手":check(preview.action=="wave","Wave button binding")
	preview.rate=.5
	preview.stopped=false
	preview.sync_speed()
	check(ap.speed_scale==.5,"Half speed")
	preview.stopped=true
	preview.sync_speed()
	check(ap.speed_scale==0,"Pause")
	preview.joints=true
	preview.queue_redraw()
	await process_frame
	var report={"checks":checks,"failures":failures,"idle_foot_displacement_px":peak_idle,"nominal_stance_height_error_px":stance_error,"max_leg_length_scale_deviation":max_scale,"engine":Engine.get_version_info().string,"note":"Nominal sole anchor only; rotated toe contour and perceived motion require visual review. No world displacement test in this isolated treadmill preview."}
	FileAccess.open("res://evidence/verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
