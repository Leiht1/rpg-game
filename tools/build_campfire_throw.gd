extends SceneTree
func key(clip: Animation, path: String, times: Array, values: Array) -> void:
	var track := clip.find_track(NodePath(path),Animation.TYPE_VALUE)
	if track>=0: clip.remove_track(track)
	track=clip.add_track(Animation.TYPE_VALUE);clip.track_set_path(track,NodePath(path))
	for i in times.size(): clip.track_insert_key(track,times[i],values[i])
func _initialize() -> void:
	var rig: Node2D=load("res://assets/hero/cartoon/character.tscn").instantiate();root.add_child(rig)
	var player: AnimationPlayer=rig.get_node("AnimationPlayer")
	var library := AnimationLibrary.new()
	for view in ["front","back","side"]:
		for hand in ["left","right"]:
			var clip: Animation=player.get_animation(view+"_breathe").duplicate(true)
			clip.loop_mode=Animation.LOOP_NONE;clip.length=.95
			for i in clip.get_track_count():
				var value = clip.track_get_key_value(i,0)
				for j in range(clip.track_get_key_count(i)-1,-1,-1): clip.track_remove_key(i,j)
				clip.track_insert_key(i,0,value)
			var arm := "Visual/Pelvis/ArmL" if hand=="left" else "Visual/Pelvis/ArmR"
			var angles: Array=[0,-.5,-2.6,-1.25,-1.0,0]
			if view=="front": angles=[0,.4,2.5,-.5,-.3,0] if hand=="left" else [0,-.4,-2.5,.5,.3,0]
			if view=="back": angles=[0,.4,1.1,2.9,2.7,0] if hand=="left" else [0,-.4,-1.1,-2.9,-2.7,0]
			key(clip,arm+":rotation",[0,.15,.34,.42,.60,.95],angles)
			# Feet stay planted; the shoulder supplies wind-up, release and recovery.
			library.add_animation(view+"_throw_"+hand,clip)
	var error := ResourceSaver.save(library,"res://assets/hero/cartoon/campfire_throw.tres")
	print("CAMPFIRE_THROW_BUILD ",error);rig.free();quit(error)
