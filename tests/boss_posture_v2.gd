extends SceneTree
var checks := 0
var failures: Array=[]
var measurements: Array=[]
func check(ok: bool, what: String) -> void:
	checks+=1
	if not ok:failures.append(what)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var rig=load("res://scripts/ancient_lord_posture.gd").new();root.add_child(rig)
	check(rig.joints.size()==32,"32 articulated joints")
	check(rig.pieces.size()==17,"17 independent sprite instances")
	for view in ["front","back","right"]:
		rig.set_view(view)
		for pose in ["neutral","contact","down","passing"]:
			rig.set_posture(pose)
			var tag: String=view+"/"+pose
			var left: Vector2=rig.to_local(rig.joints.LeftFoot.global_position)
			var right: Vector2=rig.to_local(rig.joints.RightFoot.global_position)
			check(absf(left.y+15.5)<.01,tag+" loaded sole on ground")
			check(right.y+15.5<.01,tag+" free sole not below ground")
			check(absf(rig.joints.LeftFoot.global_rotation)<.001 and absf(rig.joints.RightFoot.global_rotation)<.001,tag+" level soles")
			check(rig.joints.Head.position.x==0,tag+" centered neck/head")
			check(absf(rig.joints.Head.global_rotation)<.001,tag+" level head")
			check(rig.joints.Head.get_global_transform().origin.y<rig.joints.RightShoulder.global_position.y-40,tag+" head above arm")
			if pose in ["down","passing"]:
				var torso_at: Vector2=rig.to_local(rig.joints.Torso.global_position)
				check(absf(torso_at.x-left.x)<=28,tag+" center over loaded sole")
			if pose=="passing":
				check(left.y-right.y>8,tag+" visible foot clearance")
				check(absf(rig.joints.RightShin.rotation)>.25,tag+" swing knee bends")
			if view!="right":
				check(right.x-left.x>70,tag+" wide non-crossing stance")
				for side in ["Left","Right"]:
					var outward := -1.0 if side=="Left" else 1.0
					var hip: Vector2=rig.to_local(rig.joints[side+"Hip"].global_position)
					var knee: Vector2=rig.to_local(rig.joints[side+"Knee"].global_position)
					var foot: Vector2=rig.to_local(rig.joints[side+"Foot"].global_position)
					check((knee.x-hip.x)*outward>=0 and (foot.x-knee.x)*outward>=0,tag+side+" outward knee/ankle")
			measurements.append({"view":view,"pose":pose,"loaded_sole_y":left.y+15.5,"free_sole_y":right.y+15.5,"foot_separation":right.x-left.x})
		# Re-enter stance after each phase and view: no stale pose/anchor state.
		rig.set_posture("neutral")
		var expected: Transform2D=rig.joints.Head.global_transform
		for pose in ["passing","down","contact","neutral"]:rig.set_posture(pose)
		check(rig.joints.Head.global_transform.is_equal_approx(expected),view+" neutral reset")
	var result={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"poses":measurements,"scope":"local isolated posture/anchor tests; aesthetic approval remains pending"}
	var file:=FileAccess.open("res://reports/boss-posture-v2/metrics.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("POSTURE V2: ",checks," checks; failures=",failures)
	rig.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
