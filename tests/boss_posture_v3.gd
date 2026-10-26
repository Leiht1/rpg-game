extends SceneTree
var results: Array=[]
var metrics: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	results.append({"pass":ok,"test":label})
	if not ok:push_error(label)
func point(rig: Node2D,id: String) -> Vector2:return rig.to_local(rig.joints[id].global_position)
func bounds(rig: Node2D) -> Rect2:
	var box := Rect2();var first:=true
	for entry in rig.pieces.values():
		var sprite: Sprite2D=entry.sprite
		if not sprite.is_visible_in_tree():continue
		var rect:=sprite.get_rect()
		for corner in [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]:
			var p: Vector2=rig.to_local(sprite.to_global(corner))
			if first:box=Rect2(p,Vector2.ZERO);first=false
			else:box=box.expand(p)
	return box
func run() -> void:
	var rig=load("res://scripts/ancient_lord_posture_v3.gd").new();root.add_child(rig)
	for view in ["front","back","right","left"]:
		rig.set_view(view);metrics[view]={}
		for pose in ["neutral","contact","down","passing"]:
			rig.set_posture(pose)
			var left: Vector2=rig.sole("Left");var right: Vector2=rig.sole("Right")
			var box:=bounds(rig)
			var data: Dictionary={"left_sole":[left.x,left.y],"right_sole":[right.x,right.y],"support":"Left","pelvis":[point(rig,"Pelvis").x,point(rig,"Pelvis").y],"torso":[point(rig,"Torso").x,point(rig,"Torso").y],"height":box.size.y,"torso_degrees":rad_to_deg(rig.joints.Torso.rotation),"depth":rig.ground_depth.duplicate(),"physical_sagittal_radians":rig.sagittal.duplicate(),"knees_degrees":[rad_to_deg(rig.joints.LeftShin.rotation),rad_to_deg(rig.joints.RightShin.rotation)],"elbows_degrees":[rad_to_deg(rig.joints.LeftElbow.rotation),rad_to_deg(rig.joints.RightElbow.rotation)]}
			data.clearance=rig.ground_depth.Right-right.y
			data.screen_step_x=absf(right.x-left.x);data.screen_step_y=right.y-left.y
			metrics[view][pose]=data
			check(absf(left.y)<.01,view+" "+pose+" actual textured support sole on baseline")
			for entry in rig.pieces.values():check(absf(entry.sprite.scale.x-entry.sprite.scale.y)<.0001,view+" "+pose+" uniform scale "+entry.sprite.name)
			check(absf(rig.joints.Head.global_transform.x.normalized().y)<.001,view+" "+pose+" head level")
			check(absf(rig.joints.RightShin.rotation)<deg_to_rad(100),view+" "+pose+" knee within 100 degrees")
			if pose=="passing":check(data.clearance>10,view+" passing visibly airborne at 0.8 display scale")
		var neutral: Dictionary=metrics[view].neutral;var down: Dictionary=metrics[view].down
		check(down.pelvis[1]-neutral.pelvis[1]>4,view+" down pelvis drop >4 world units")
		if view in ["right","left"]:check(metrics[view].contact.screen_step_x>32,view+" contact stride >half 64-unit leg")
		else:check(absf(metrics[view].contact.screen_step_y)>7,view+" contact projected depth visible")
		rig.set_posture("neutral");check(absf(point(rig,"Pelvis").y-neutral.pelvis[1])<.01,view+" pose reset stable")
	# The left rendering is an exact geometric mirror with the same semantic phases.
	for pose in ["neutral","contact","down","passing"]:
		rig.set_view("right");rig.set_posture(pose);var r: Vector2=rig.joints.RightFoot.global_position
		rig.set_view("left");rig.set_posture(pose);var l: Vector2=rig.joints.RightFoot.global_position
		check(absf(r.x+l.x)<.01 and absf(r.y-l.y)<.01,"mirror foot trajectory "+pose)
	FileAccess.open("res://reports/boss-posture-v3/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
	FileAccess.open("res://reports/boss-posture-v3/checks.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	var failed: int=results.filter(func(c):return not c.pass).size()
	print("POSTURE REWORK ",results.size()," checks, ",failed," failures")
	rig.queue_free();await process_frame;quit(1 if failed else 0)
