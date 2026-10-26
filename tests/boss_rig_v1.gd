extends SceneTree
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks.append({"pass":ok,"test":caption});print("PASS " if ok else "FAIL ",caption)
func run() -> void:
	var rig=load("res://scripts/ancient_lord_rig.gd").new();root.add_child(rig)
	check(rig.joints.size()==33,"33 independent editable joints")
	for side in ["Left","Right"]:
		check(rig.joints[side+"Elbow"].get_parent()==rig.joints[side+"UpperArm"],side+" elbow inherits upper arm")
		check(rig.joints[side+"Shin"].get_parent()==rig.joints[side+"Knee"],side+" shin inherits knee")
		check(rig.joints[side+"Fist"].get_parent()==rig.joints[side+"Wrist"],side+" independent wrist and fist")
	var results: Dictionary={}
	for view in ["front","back","right","left"]:
		rig.position=Vector2.ZERO;rig.set_view(view);rig.advance(1.0/60,rig.position,"idle",view)
		var dir: Vector2={"front":Vector2.DOWN,"back":Vector2.UP,"right":Vector2.RIGHT,"left":Vector2.LEFT}[view]
		var error:=0.0;var slide:=0.0;var knee_min:=100.0;var knee_max:=-100.0;var previous: Dictionary={}
		for frame in 240:
			rig.position+=dir*66.0/60.0;rig.advance(1.0/60.0,rig.position,"chase",view)
			for i in 2:
				var f: Dictionary=rig.feet[i];var actual: Vector2=rig.joints[f.side+"Foot"].global_position
				if not f.swing:
					error=maxf(error,actual.distance_to(f.anchor))
					if previous.has(i):slide=maxf(slide,actual.distance_to(previous[i]))
					previous[i]=actual
				else:previous.erase(i)
			knee_min=minf(knee_min,rig.joints.LeftShin.rotation);knee_max=maxf(knee_max,rig.joints.LeftShin.rotation)
		check(error<.5,view+" planted foot reaches world target")
		check(slide<.5,view+" support foot remains stable in world space")
		check(knee_max-knee_min>.15,view+" knee actually articulates")
		var before: float=rig.phase
		for frame in 60:rig.advance(1.0/60,rig.position,"idle",view)
		check(is_equal_approx(before,rig.phase) and rig.weight<.001,view+" stop does not keep marching")
		results[view]={"max_contact_error":error,"max_support_slide":slide,"knee_rotation_range":knee_max-knee_min}
	var phase_before: float=rig.phase
	rig.set_view("right");check(is_equal_approx(phase_before,rig.phase),"turn retains gait phase")
	var stable: String=rig.facing
	for frame in 60:rig.select_heading(Vector2(65,66) if frame%2 else Vector2(66,65),1.0/60)
	check(rig.facing==stable,"diagonal boundary does not flicker")
	for frame in 30:rig.advance(1.0/60,rig.position,"windup")
	check(rig.weight==0,"attack entry settles locomotion")
	var right_elbow: Node2D=rig.joints.RightElbow
	var old: Vector2=right_elbow.global_position
	rig.joints.RightUpperArm.rotation=-2.4
	check(right_elbow.global_position.distance_to(old)>30,"raised arm moves actual elbow")
	rig.pose_override={"RightUpperArm":-2.4,"RightElbow":.8};rig.release_pose();check(rig.pose_override.is_empty(),"combat override can be released")
	FileAccess.open("res://reports/boss-rig-v1/rig-checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"metrics":results},"  "))
	var failed: int=checks.filter(func(c):return not c.pass).size();print("BOSS RIG ",checks.size()," checks ",failed," failures")
	rig.queue_free();await process_frame;quit(1 if failed else 0)
