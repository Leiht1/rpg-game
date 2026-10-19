extends SceneTree
func retime_point(t:float,old:Array,new:Array)->float:
	for i in range(1,old.size()):
		if t<=old[i]:return lerpf(new[i-1],new[i],inverse_lerp(old[i-1],old[i],t))
	return new.back()
func _initialize()->void:
	var rig=load("res://assets/hero/cartoon/character.tscn").instantiate()
	var ap:AnimationPlayer=rig.get_node("AnimationPlayer")
	var lib=ap.get_animation_library("")
	if lib.get_animation("side_chop").length<1.0:
		print("V03 timings already baked; no changes")
		rig.free();quit();return
	for view in ["front","back","side"]:
		for action in ["chop","pickup"]:
			var clip:Animation=lib.get_animation(view+"_"+action)
			var old=[0.0,.50,.775,.90,1.20,1.65] if action=="chop" else [0.0,.55,1.144,1.97,2.2]
			var times=[0.0,.25,.36,.42,.63,.82] if action=="chop" else [0.0,.17,.36,.63,.72]
			for track in clip.get_track_count():
				for key in clip.track_get_key_count(track):
					clip.track_set_key_time(track,key,retime_point(clip.track_get_key_time(track,key),old,times))
			clip.length=times.back()
		var source:Animation=lib.get_animation(view+"_chop")
		var link:=Animation.new()
		link.length=.80
		for track in source.get_track_count():
			var dest:=link.add_track(source.track_get_type(track))
			link.track_set_path(dest,source.track_get_path(track))
			link.track_set_interpolation_type(dest,source.track_get_interpolation_type(track))
			link.value_track_set_update_mode(dest,source.value_track_get_update_mode(track))
			link.track_insert_key(dest,0,source.value_track_interpolate(track,.64))
			link.track_insert_key(dest,.12,source.value_track_interpolate(track,.14))
			for k in source.track_get_key_count(track):
				var t:=source.track_get_key_time(track,k)
				if t>.14:link.track_insert_key(dest,t-.02,source.track_get_key_value(track,k))
		lib.add_animation(view+"_chop_link",link)
	var packed:=PackedScene.new();packed.pack(rig)
	print("V03 ANIMATION SAVE ",ResourceSaver.save(packed,"res://assets/hero/cartoon/character.tscn"))
	rig.free();quit()

