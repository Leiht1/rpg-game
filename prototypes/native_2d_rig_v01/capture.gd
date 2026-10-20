extends SceneTree
## Actual GPU renders of the saved native rig, not a reimplementation.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var preview = load("res://preview.tscn").instantiate()
	root.add_child(preview)
	preview.paused = true
	preview.update_pose()
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/comparison.png")
	# Transparent offscreen 128x128 render of exactly the same scene instance.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128,128)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var character = load("res://hero_rig.tscn").instantiate()
	viewport.add_child(character)
	var player: AnimationPlayer = character.animation_player()
	var joint_data := {}
	for action in ["walk", "breathe", "wave", "RESET"]:
		var count := 64 if action != "RESET" else 1
		for outfit in 2:
			character.outfit = outfit
			player.play(action)
			player.pause()
			DirAccess.make_dir_recursive_absolute("res://evidence/renders/%s_%d" % [action,outfit])
			var samples: Array = []
			for frame in count:
				player.seek(frame * player.get_animation(action).length / float(count), true)
				await process_frame
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png("res://evidence/renders/%s_%d/%03d.png" % [action,outfit,frame])
				if outfit == 0:
					var joints := {}
					for bone in character.get_node("Skeleton2D").find_children("*", "Bone2D", true, false):
						var p: Vector2 = bone.global_position
						joints[str(bone.name)] = [p.x, p.y]
					samples.append(joints)
			if outfit == 0:
				joint_data[action] = samples
	var json_file := FileAccess.open("res://evidence/joints.json", FileAccess.WRITE)
	json_file.store_string(JSON.stringify(joint_data))
	json_file.close()
	preview.set_action("wave")
	preview.set_outfit(1)
	preview.clock = .9
	preview.rig.show_bones = true
	preview.update_pose()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/wave_bones.png")
	print("CAPTURE_COMPLETE native Godot rendered 386 RGBA frames and 2 comparison screens")
	quit()
