extends SceneTree
## Additive native AnimationLibrary. Existing accepted resources/PNG remain byte-identical.
func key(clip: Animation, path: String, times: Array, values: Array) -> void:
	for i in range(clip.get_track_count()-1,-1,-1):
		if str(clip.track_get_path(i))==path: clip.remove_track(i)
	var track := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track,NodePath(path))
	for i in times.size(): clip.track_insert_key(track,float(times[i]),values[i])
func _initialize() -> void:
	var rig: Node2D=load("res://assets/hero/cartoon/character.tscn").instantiate()
	root.add_child(rig)
	var player: AnimationPlayer=rig.get_node("AnimationPlayer")
	var library := AnimationLibrary.new()
	var summary := {}
	for view in ["front","back","side"]:
		player.play(view+"_breathe");player.seek(0,true)
		var r: Vector2=rig.get_node("Visual/Pelvis/ArmR").position
		var l: Vector2=rig.get_node("Visual/Pelvis/ArmL").position
		for action in ["mine","dig"]:
			var clip: Animation=player.get_animation(view+"_breathe").duplicate(true)
			clip.loop_mode=Animation.LOOP_NONE
			clip.length=1.12 if action=="mine" else 1.25
			# Keep direction textures and original layering, make all base transforms static.
			for i in clip.get_track_count():
				var value: Variant=clip.track_get_key_value(i,0)
				for j in range(clip.track_get_key_count(i)-1,-1,-1):clip.track_remove_key(i,j)
				clip.track_insert_key(i,0,value)
			var times: Array=[0,.18,.39,.55,.62,.78,1.12] if action=="mine" else [0,.18,.43,.50,.68,.85,1.25]
			var side: bool=view=="side"
			# Shoulder, pelvis, torso, head and knee stance all participate.
			# Shaft turns around the original palm registration, independent of upper arm.
			var arms: Array=[-.35,-2.35,-2.65,-.88,-.88,-1.15,-.35] if action=="mine" else [-.35,-.70,-.94,-.94,-1.55,-1.95,-.35]
			if action=="dig" and view=="front": arms=[-.35,.35,.65,.65,.15,-.25,-.35]
			if view=="back":
				for i in arms.size(): arms[i]=-float(arms[i])
			key(clip,"Visual/Pelvis/ArmR:rotation",times,arms)
			key(clip,"Visual/Pelvis/ArmR:position",times,[r,r+Vector2(0,-2),r+Vector2(2,-3),r+Vector2(5,2),r+Vector2(5,2),r+Vector2(2,0),r] if action=="mine" else [r,r+Vector2(1,1),r+Vector2(5,4),r+Vector2(5,4),r+Vector2(2,0),r+Vector2(0,-2),r])
			var body: Array=[0,-.10,-.15,.18,.18,.08,0] if action=="mine" else [0,.10,.22,.22,.12,-.10,0]
			if not side:
				for i in body.size():body[i]=float(body[i])*.30*(-1 if view=="back" else 1)
			key(clip,"Visual/Pelvis:rotation",times,body)
			key(clip,"Visual/Pelvis:position",times,[Vector2(64,94),Vector2(64,93),Vector2(64,92),Vector2(66 if side else 64,97),Vector2(66 if side else 64,97),Vector2(64,95),Vector2(64,94)] if action=="mine" else [Vector2(64,94),Vector2(65 if side else 64,96),Vector2(67 if side else 64,98),Vector2(67 if side else 64,98),Vector2(65 if side else 64,96),Vector2(64,93),Vector2(64,94)])
			key(clip,"Visual/Pelvis/Head:rotation",times,[0,-.05,-.08,.09,.09,.03,0] if action=="mine" else [0,.05,.11,.11,.02,-.06,0])
			key(clip,"Visual/LegL:rotation",times,[0,.05,.08,-.12,-.12,-.04,0])
			key(clip,"Visual/LegR:rotation",times,[0,-.06,-.09,.13,.13,.04,0])
			# Two-hand support reaches a point on the shaft at every authored phase.
			# Left shoulder stays native; hand solved by a small natural elbow/shoulder travel.
			var left_angles: Array=[]
			var left_positions: Array=[]
			for i in arms.size():
				var right_at: Vector2=clip.value_track_interpolate(clip.find_track(NodePath("Visual/Pelvis/ArmR:position"),Animation.TYPE_VALUE),times[i])
				var palm: Vector2=right_at+Vector2(0,18.25).rotated(float(arms[i]))
				var support := palm+Vector2(0,-5).rotated(float(arms[i]))
				var reach := support-l
				left_angles.append(reach.angle()-PI*.5)
				var left_at := support-reach.normalized()*18.25
				left_positions.append(left_at if action=="dig" else l)
			key(clip,"Visual/Pelvis/ArmL:rotation",times,left_angles)
			key(clip,"Visual/Pelvis/ArmL:position",times,left_positions)
			# Wrist pitch: pick follows overhead arc; shovel pitches down then scoops up.
			var desired: Array=[0,-.40,-.55,1.45,1.45,.70,0] if action=="mine" else [PI,3.7,4.65,4.65,3.6,3.15,PI]
			if view=="front" and action=="mine": desired=[0,-.40,-.55,2.2,2.2,1.0,0]
			if view=="back": desired=[0,-.65,-.9,-1.35,-1.35,-.7,0] if action=="mine" else [PI,3.0,2.6,2.6,3.3,3.7,PI]
			var wrist: Array=[]
			for i in arms.size(): wrist.append(float(desired[i])-float(arms[i])-(PI if action=="dig" else 0)-float(body[i]))
			key(clip,"Visual/Pelvis/ArmR/Grip:rotation",times,wrist)
			library.add_animation(view+"_"+action,clip)
			summary[view+"_"+action]={"shoulder_r":str(r),"shoulder_l":str(l),"length":clip.length,"hit":.55 if action=="mine" else .68,"tracks":clip.get_track_count(),"phases":times}
	var result := ResourceSaver.save(library,"res://assets/hero/cartoon/harvest_actions.tres")
	var file := FileAccess.open("res://art/harvest-v05/animation-build.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"\t"));file.close()
	print("HARVEST_ANIMATIONS ",result)
	rig.free();quit(result)
