extends SceneTree
func key(clip: Animation, path: String, times: Array, values: Array) -> void:
	var track:=clip.find_track(NodePath(path),Animation.TYPE_VALUE)
	if track>=0:clip.remove_track(track)
	track=clip.add_track(Animation.TYPE_VALUE);clip.track_set_path(track,NodePath(path))
	for i in times.size():clip.track_insert_key(track,times[i],values[i])
func _initialize() -> void:
	var rig: Node2D=load("res://assets/hero/cartoon/character.tscn").instantiate();root.add_child(rig)
	var player: AnimationPlayer=rig.get_node("AnimationPlayer");var library:=AnimationLibrary.new()
	for view in ["front","back","side"]:
		for action in ["punch","club","death"]:
			var clip: Animation=player.get_animation(view+"_breathe").duplicate(true)
			clip.loop_mode=Animation.LOOP_NONE
			for i in clip.get_track_count():
				var value=clip.track_get_key_value(i,0)
				for j in range(clip.track_get_key_count(i)-1,-1,-1):clip.track_remove_key(i,j)
				clip.track_insert_key(i,0,value)
			if action=="death":
				clip.length=3
				key(clip,"Visual/Pelvis:rotation",[0,.35,.7,3],[0,.2,1.45,1.45])
				key(clip,"Visual/Pelvis:position",[0,.7,3],[Vector2(64,94),Vector2(64,106),Vector2(64,106)])
				for leg in ["LegL","LegR"]:
					var x:=59 if leg=="LegL" else 69
					key(clip,"Visual/"+leg+":rotation",[0,.7,3],[0,1.45,1.45])
					key(clip,"Visual/"+leg+":position",[0,.7,3],[Vector2(x,94),Vector2(x,106),Vector2(x,106)])
				key(clip,"Visual/Pelvis/ArmR:rotation",[0,.4,.7,3],[0,-.4,.15,.15])
				key(clip,"Visual/Pelvis/ArmL:rotation",[0,.4,.7,3],[0,.4,-.15,-.15])
			else:
				clip.length=.56 if action=="punch" else .74
				var hit:=.18 if action=="punch" else .24
				if action=="club":
					var angles: Array=[0,-.65,1.0,.6,0] if action=="punch" else [0,-1.8,1.4,.8,0]
					if view=="back":angles=[0,.8,-1.2,-.5,0] if action=="punch" else [0,1.9,-1.3,-.7,0]
					key(clip,"Visual/Pelvis/ArmR:rotation",[0,hit*.8,hit,hit+.08,clip.length],angles)
					key(clip,"Visual/Pelvis/ArmL:rotation",[0,hit,clip.length],[0,-.3,0])
				else:
					var times: Array=[0,hit*.70,hit,hit+.08,clip.length]
					var right_path: String="Visual/Pelvis/ArmR:rotation"
					var left_path: String="Visual/Pelvis/ArmL:rotation"
					var right_base: float=clip.track_get_key_value(clip.find_track(NodePath(right_path),Animation.TYPE_VALUE),0)
					var left_base: float=clip.track_get_key_value(clip.find_track(NodePath(left_path),Animation.TYPE_VALUE),0)
					var angles: Array=[0,-2.25,-.45,-.3,0] if action=="punch" else [0,-2.35,-1.15,-.7,0]
					if view=="front":angles=[0,-2.45,.38,.28,0] if action=="punch" else [0,-2.65,-.25,.15,0]
					if view=="back":angles=[0,-2.35,-PI-right_base,-PI-right_base,0] if action=="punch" else [0,2.45,2.8,2.4,0]
					var right_values: Array=[]
					for angle in angles:right_values.append(right_base+angle)
					key(clip,right_path,times,right_values)
					key(clip,left_path,times,[left_base,left_base,left_base,left_base,left_base])
					key(clip,"Visual/Pelvis/ArmR:scale",times,[Vector2.ONE,Vector2(1,.92),Vector2(1,.85 if view=="back" else 1.42),Vector2(1,.85 if view=="back" else 1.25),Vector2.ONE])
					key(clip,"Visual/Pelvis/Torso:rotation",times,[0,0,0,0,0] if view=="back" else [0,-.06,.18,.12,0])
					var lean: Vector2=Vector2(4,0) if view=="side" else Vector2(0,3 if view=="front" else -3)
					var base: Vector2=clip.track_get_key_value(clip.find_track(NodePath("Visual/Pelvis:position"),Animation.TYPE_VALUE),0)
					key(clip,"Visual/Pelvis:position",times,[base,base-lean*.25,base+lean,base+lean*.7,base])

			library.add_animation(view+"_"+action,clip)
	var error:=ResourceSaver.save(library,"res://assets/hero/cartoon/combat_actions.tres")
	rig.free();quit(error)
