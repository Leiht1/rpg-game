extends RefCounted
## Connected rest poses. Only a breathing loop, no lie-down or get-up transitions.
const Rules = preload("res://scripts/sleep_rules.gd")

static func library(player: AnimationPlayer) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var reset: Animation=player.get_animation("side_breathe").duplicate(true)
	reset.length=.01;reset.loop_mode=Animation.LOOP_NONE
	var restored := {}
	for vertical in [false,true]:
		var clip: Animation=player.get_animation("side_breathe").duplicate(true)
		clip.length=float(Rules.data().breath_seconds);clip.loop_mode=Animation.LOOP_LINEAR
		var pose := {
			"Visual/Pelvis:position":Vector2(64,106),"Visual/Pelvis:rotation":-PI*.5,
			"Visual/Pelvis/Torso:position":Vector2(0,-5),"Visual/Pelvis/Torso:rotation":0.0,
			"Visual/Pelvis/Head:position":Vector2(0,-32),"Visual/Pelvis/Head:rotation":PI*.5,
			"Visual/Pelvis/Head/Sprite:position":Vector2.ZERO,
			"Visual/Pelvis/ArmL:position":Vector2(-4,-17),"Visual/Pelvis/ArmL:rotation":0.0,
			"Visual/Pelvis/ArmR:position":Vector2(0,-11),"Visual/Pelvis/ArmR:rotation":.15,
			"Visual/LegL:position":Vector2(64,102),"Visual/LegL:rotation":-PI*.5+.1,
			"Visual/LegR:position":Vector2(65,110),"Visual/LegR:rotation":-PI*.5-.08,
			"Visual/Pelvis/ArmR:show_behind_parent":false}
		if vertical:
			pose={
				"Visual/Pelvis:position":Vector2(62,100),"Visual/Pelvis:rotation":0.0,
				"Visual/Pelvis/Torso:position":Vector2(0,-8),"Visual/Pelvis/Torso:rotation":-.28,
				"Visual/Pelvis/Head:position":Vector2(0,-12),"Visual/Pelvis/Head:rotation":-.20,
				"Visual/Pelvis/Head/Sprite:position":Vector2(0,-22.5),
				"Visual/Pelvis/ArmL:position":Vector2(-11,-13),"Visual/Pelvis/ArmL:rotation":-.9,
				"Visual/Pelvis/ArmR:position":Vector2(10,-13),"Visual/Pelvis/ArmR:rotation":1.15,
				"Visual/LegL:position":Vector2(63,101),"Visual/LegL:rotation":-.8,
				"Visual/LegR:position":Vector2(67,104),"Visual/LegR:rotation":-.95,
				"Visual/Pelvis/ArmR:show_behind_parent":false}
		for path in pose:
			var index := clip.find_track(NodePath(path),Animation.TYPE_VALUE)
			if index>=0: clip.remove_track(index)
			index=clip.add_track(Animation.TYPE_VALUE);clip.track_set_path(index,NodePath(path))
			clip.track_insert_key(index,0,pose[path])
			if pose[path] is bool: clip.value_track_set_update_mode(index,Animation.UPDATE_DISCRETE)
			else:
				var peak=pose[path]
				if path=="Visual/Pelvis/Torso:position": peak+=Vector2(0,-.55) if vertical else Vector2(.55,0)
				if path=="Visual/Pelvis/ArmR:rotation": peak+=.012
				clip.track_insert_key(index,clip.length*.5,peak);clip.track_insert_key(index,clip.length,pose[path])
			if not restored.has(path):
				var pieces: PackedStringArray=String(path).split(":")
				var original=player.get_parent().get_node(pieces[0]).get(pieces[1])
				var track := reset.find_track(NodePath(path),Animation.TYPE_VALUE)
				if track>=0: reset.remove_track(track)
				track=reset.add_track(Animation.TYPE_VALUE);reset.track_set_path(track,NodePath(path));reset.track_insert_key(track,0,original)
				restored[path]=true
		lib.add_animation("vertical_breathe" if vertical else "breathe",clip)
	lib.add_animation("reset",reset)
	return lib
