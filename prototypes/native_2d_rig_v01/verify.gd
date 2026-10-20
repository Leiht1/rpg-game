extends SceneTree
## Only this prototype: resource integrity, contact, reuse and preview controls.
var failures: Array[String] = []
var checks := 0
var measurements := {}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func sample(player: AnimationPlayer, action: String, time: float) -> void:
	player.play(action)
	player.pause()
	player.seek(time, true)

func snapshot(skeleton: Skeleton2D) -> Array:
	var result: Array = []
	for bone in skeleton.find_children("*", "Bone2D", true, false):
		result.append(bone.transform)
	return result

func run() -> void:
	var rig = load("res://hero_rig.tscn").instantiate()
	root.add_child(rig)
	await process_frame
	var skeleton: Skeleton2D = rig.get_node("Skeleton2D")
	var player: AnimationPlayer = rig.animation_player()
	var bones := skeleton.find_children("*", "Bone2D", true, false)
	check(bones.size() == 18, "18 persistent native Bone2D nodes")
	check(rig.get_node("Meshes").get_child_count() == 16, "16 saved skinned meshes")
	check(rig.get_node("Meshes/NearArm").z_index > rig.get_node("Meshes/Head").z_index,"near waving hand can pass in front of face")
	check(rig.get_node("Meshes/FarArm").z_index < rig.get_node("Meshes/OliveTorso").z_index,"far arm stays behind torso")
	var blended_vertices := 0
	var triangle_count := 0
	for mesh: Polygon2D in rig.get_node("Meshes").get_children():
		check(mesh.get_node(mesh.skeleton) == skeleton, str(mesh.name)+" skeleton resolves")
		check(mesh.get_bone_count() > 0, str(mesh.name)+" has real skin weights")
		triangle_count += mesh.polygons.size()
		var sums := PackedFloat32Array()
		sums.resize(mesh.polygon.size())
		var influences := PackedInt32Array()
		influences.resize(mesh.polygon.size())
		for bi in mesh.get_bone_count():
			check(skeleton.get_node_or_null(mesh.get_bone_path(bi)) is Bone2D, str(mesh.name)+" bone path resolves")
			var weights := mesh.get_bone_weights(bi)
			check(weights.size() == mesh.polygon.size(), str(mesh.name)+" weight/vertex count")
			for i in weights.size():
				sums[i] += weights[i]
				if weights[i] > .001:
					influences[i] += 1
		for i in sums.size():
			check(absf(sums[i]-1.0) < .00001, str(mesh.name)+" normalized weights")
			if influences[i] > 1:
				blended_vertices += 1
	check(blended_vertices > 100, "joint mesh really blends multiple bones")
	for action in ["walk", "breathe", "wave"]:
		var animation := player.get_animation(action)
		check(animation != null and animation.loop_mode == Animation.LOOP_LINEAR, action+" loop resource")
		for track in animation.get_track_count():
			check(str(animation.track_get_path(track)).begins_with("Skeleton2D/"), action+" edits bones only")
			if str(animation.track_get_path(track)).ends_with(":rotation"):
				check(typeof(animation.track_get_key_value(track,0)) == TYPE_FLOAT, action+" floating point rotation keys")
		sample(player, action, 0)
		var first := snapshot(skeleton)
		sample(player, action, animation.length)
		var last := snapshot(skeleton)
		for i in first.size():
			check(first[i].is_equal_approx(last[i]), action+" continuous loop transform")
	check(absf(player.get_animation("walk").length-8.0/13.8) < .000001, "walk .579710 seconds")
	check(absf(player.get_animation("breathe").length-1.8) < .000001, "breathe 1.8 seconds")
	var max_stance_error := 0.0
	var max_foot_ground_error := 0.0
	var knee_min := 999.0
	var knee_max := -999.0
	var wave_hand_min_y := 999.0
	for action in ["walk", "breathe", "wave"]:
		for i in 128:
			var phase := i/128.0
			sample(player, action, phase*player.get_animation(action).length)
			var before_outfit := snapshot(skeleton)
			var time_before := player.current_animation_position
			rig.outfit = i % 2
			check(is_equal_approx(player.current_animation_position, time_before), "outfit preserves playback phase")
			var after_outfit := snapshot(skeleton)
			for b in before_outfit.size():
				check(before_outfit[b].is_equal_approx(after_outfit[b]), "outfit reuses exact bone transforms")
			for side in ["Near", "Far"]:
				var foot: Bone2D = skeleton.find_child(side+"Foot",true,false)
				var shin: Bone2D = skeleton.find_child(side+"Shin",true,false)
				var thigh: Bone2D = skeleton.find_child(side+"Thigh",true,false)
				check(absf(shin.position.length()-10) < .0001 and absf(foot.position.length()-10) < .0001, "leg lengths fixed")
				if action == "walk":
					knee_min = minf(knee_min, shin.rotation_degrees)
					knee_max = maxf(knee_max, shin.rotation_degrees)
					check(shin.rotation > 0 and shin.rotation < deg_to_rad(100), "knee never reverses")
					var leg_phase := fposmod(phase+(0.5 if side=="Far" else 0.0),1.0)
					if leg_phase < .5:
						var hip_x := 62.0 if side=="Near" else 65.0
						var target := Vector2(hip_x+8.0-32.0*leg_phase,104)
						max_stance_error = maxf(max_stance_error,foot.global_position.distance_to(target))
						max_foot_ground_error = maxf(max_foot_ground_error,absf(foot.global_position.y-104))
						check(absf(foot.global_rotation) < .00002, "stance sole remains flat")
				else:
					var x := 62.0 if side=="Near" else 65.0
					check(foot.global_position.distance_to(Vector2(x,104)) < .00001, action+" foot stays fixed")
			if action == "wave":
				var hand: Bone2D = skeleton.find_child("NearHand",true,false)
				wave_hand_min_y = minf(wave_hand_min_y,hand.global_position.y)
	check(max_stance_error < .02, "baked key interpolation preserves contact path within .02 px")
	check(wave_hand_min_y < 58, "wave lifts hand above shoulder using same rig")
	for action in ["walk", "wave", "walk", "breathe"]:
		sample(player, action, 0)
	check(absf(skeleton.find_child("NearThigh",true,false).rotation)<.00001, "switching to idle restores walk leg")
	check(absf(skeleton.find_child("NearUpperArm",true,false).rotation)<.00001, "switching to idle restores wave arm")
	var preview = load("res://preview.tscn").instantiate()
	root.add_child(preview)
	preview.paused = true
	preview.set_action("walk")
	preview.bone_check.button_pressed = true
	check(preview.rig.show_bones and preview.rig.get_node("BoneOverlay").visible, "bone toggle")
	preview.set_outfit(1)
	check(preview.rig.outfit == 1 and preview.small_rig.outfit == 1, "both preview scales change outfit")
	preview.set_mirror(true)
	check(preview.rig.scale.x == -3 and preview.reference.flip_h, "left mirror")
	var origin: Vector2 = preview.rig.to_global(Vector2(64,112))
	check(origin.distance_to(Vector2(900,470)) < .00001, "mirror preserves shared foot origin")
	preview.speed_picker.item_selected.emit(1)
	preview.paused = false
	preview._process(.1)
	check(absf(preview.clock-.025)<.000001,"slow speed .25x")
	preview.toggle_pause()
	var paused_clock: float = preview.clock
	preview._process(.1)
	check(is_equal_approx(preview.clock, paused_clock), "pause freezes both")
	preview.step_phase(1.0/64)
	check(absf(preview.clock-paused_clock-float(preview.DURATIONS.walk)/64)<.000001,"step 1/64")
	var phase_before_cycle: float = preview.clock/preview.current_duration()
	preview.cycle_control.value = .72
	check(absf(preview.current_duration()-.72)<.000001,"walk cycle independently adjustable")
	check(absf(preview.clock/preview.current_duration()-phase_before_cycle)<.000001,"cycle change preserves comparison phase")
	measurements = {"bones":bones.size(),"meshes":16,"triangles":triangle_count,
		"blended_vertices":blended_vertices,"max_stance_path_error_px":max_stance_error,
		"max_stance_ankle_y_error_px":max_foot_ground_error,"knee_degrees_min":knee_min,
		"knee_degrees_max":knee_max,"wave_wrist_min_y":wave_hand_min_y,
		"walk_cycle_seconds":player.get_animation("walk").length,
		"breathe_cycle_seconds":player.get_animation("breathe").length}
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,
		"status":"pass" if failures.is_empty() else "fail","measurements":measurements,
		"scope":"prototype only; numerical results do not approve visual quality"}
	var file := FileAccess.open("res://evidence/native_tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
