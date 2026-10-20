extends SceneTree
var failures:Array=[]
var checks:=0
var foot_error:=0.0
var grab_error:=0.0
var axe_contact_error:=0.0
var hip_alpha_min:=1.0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
func _initialize()->void:call_deferred("run")
func run()->void:
	var preview=load("res://preview.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	preview.stopped=true
	preview.sync_speed()
	var rig:Node2D=preview.rigs[0]
	var ap:AnimationPlayer=rig.get_node("AnimationPlayer")
	check(ap.get_animation_list().size()==18,"18 editable direction/action clips")
	var axe:Sprite2D=rig.get_node("Visual/Pelvis/ArmR/Grip/Axe")
	var fruit:Sprite2D=rig.get_node("Visual/Fruit")
	var tree:Sprite2D=rig.get_node("Visual/Tree")
	for d in ["front","side","back"]:
		for action in ["chop","pickup"]:
			var name_:String=d+"_"+action
			ap.play(name_,0)
			ap.pause()
			var anim:=ap.get_animation(name_)
			for k in 97:
				var t:=float(k)/96
				ap.seek(t*anim.length,true)
				for s in ["L","R"]:
					var leg:Node2D=rig.get_node("Visual/Leg"+s)
					foot_error=maxf(foot_error,absf((leg.transform*Vector2(0,18)).y-112))
					var shirt:Sprite2D=rig.get_node("Visual/Pelvis/Torso")
					var tex:=shirt.texture.get_image()
					var pixel:=shirt.to_local(leg.global_position)+Vector2(tex.get_size())*.5
					var alpha:float=tex.get_pixelv(Vector2i(pixel)).a if Rect2(Vector2.ZERO,Vector2(tex.get_size())).has_point(pixel) else 0.0
					hip_alpha_min=minf(hip_alpha_min,alpha)
				if action=="pickup" and t>=.44 and t<.9:
					var hand:Node2D=rig.get_node("Visual/Pelvis/ArmR/Grip")
					grab_error=maxf(grab_error,hand.global_position.distance_to(fruit.global_position)/rig.scale.x)
				if action=="chop" and t>=.48 and t<=.53:
					var blade:Vector2=rig.get_node("Visual").to_local(axe.to_global(Vector2(7,-9)*4))
					axe_contact_error=maxf(axe_contact_error,absf(blade.x-tree.position.x))
			check(axe.visible==(action=="chop") and tree.visible==(action=="chop") and fruit.visible==(action=="pickup"),name_+" correct props")
		if d=="back":
			check(rig.get_node("Visual/Pelvis/Head/Sprite").texture==load("res://art/back_head.png"),"Rear action uses actual rear head")
			check(rig.get_node("Visual/Pelvis/ArmR").z_index<rig.get_node("Visual/Pelvis/Head").z_index,"Rear arm remains behind head")
		check(axe.get_parent().name=="Grip","Axe uses same hand pivot throughout")
		for action in ["breathe","walk","run","wave"]:
			ap.play(d+"_"+action,0)
			ap.pause()
			ap.seek(0,true)
			check(not axe.visible and not tree.visible and not fruit.visible,d+action+" clears action props")
	check(hip_alpha_min>.95,"Both hip roots stay inside the shirt alpha silhouette throughout both actions")
	check(foot_error<.002,"Both new actions keep nominal sole height")
	check(grab_error<.05,"Item meets hand and stays with hand through lift")
	check(axe_contact_error<5,"Cutting edge overlaps trunk horizontal band during impact hold")
	for d in ["front","side","left","back"]:
		preview.set_direction(d)
		for action in ["chop","pickup"]:
			preview.set_action(action)
			check(ap.current_animation==(d if d in ["front","back"] else "side")+"_"+action,"Preview controls "+d+action)
	var report={"checks":checks,"failures":failures,"minimum_shirt_alpha_at_hip_roots":hip_alpha_min,"nominal_sole_height_error_px":foot_error,"item_hand_distance_px":grab_error,"blade_trunk_horizontal_error_px":axe_contact_error,"engine":Engine.get_version_info().string,"limits":"Contact estimates use art anchors; actual outline, staging and naturalness also reviewed in GPU captures. No gameplay, inventory, tree damage or world movement tested."}
	FileAccess.open("res://evidence/action_verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

