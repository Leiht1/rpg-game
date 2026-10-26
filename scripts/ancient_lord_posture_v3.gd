extends Node2D
## V2 rework, new necessary-part cutouts. Neutral reviewed before pose authoring. No movement clock, gait loop, IK, combat or authority writes.
const ART := "res://prototypes/boss-posture-v3/parts/"
const UPPER_ARM := 35.0
const FOREARM := 33.0
const THIGH := 32.0
const SHIN := 32.0
var joints: Dictionary = {}
var pieces: Dictionary = {}
var rest: Dictionary = {}
var facing := "front"
var posture := "neutral"
var ground_depth := {"Left":0.0,"Right":0.0}
var sagittal := {"Left":[0.0,0.0],"Right":[0.0,0.0]}

func sole(side: String) -> Vector2:
	var sprite: Sprite2D=pieces[side.to_lower()+"_foot"].sprite
	return to_local(sprite.to_global(Vector2(0,sprite.texture.get_height()*.5)))

func project_leg(side: String, hip_pitch: float, knee_flex: float) -> void:
	# Oblique world projection: fixed 32-unit physical segments, screen Y=height-depth*0.7.
	# Bone attachment moves in projection; pixels retain their constant uniform scale.
	sagittal[side]=[hip_pitch,knee_flex]
	var depth_sign := -1.0 if facing=="front" else 1.0
	joints[side+"Knee"].position.y=THIGH*(cos(hip_pitch)+depth_sign*.7*sin(hip_pitch))
	joints[side+"Ankle"].position.y=SHIN*(cos(hip_pitch+knee_flex)+depth_sign*.7*sin(hip_pitch+knee_flex))
	ground_depth[side]=depth_sign*.7*(THIGH*sin(hip_pitch)+SHIN*sin(hip_pitch+knee_flex))

func bone(id: String, parent: Node2D, at: Vector2, z: int=0) -> Node2D:
	var node := Node2D.new();node.name=id;node.position=at;node.z_index=z;parent.add_child(node)
	joints[id]=node;rest[id]=at;return node

func piece(slot: String, parent: Node2D, size: Vector2, at: Vector2) -> void:
	var sprite := Sprite2D.new();sprite.name=slot;parent.add_child(sprite);sprite.position=at
	pieces[slot]={"sprite":sprite,"size":size}

func _ready() -> void:
	var pelvis := bone("Pelvis",self,Vector2(0,-72))
	var torso := bone("Torso",pelvis,Vector2(0,-46),2)
	piece("torso",torso,Vector2(146,124),Vector2(0,-1))
	var chest := bone("Chest",torso,Vector2(0,-8))
	var core := bone("Core",chest,Vector2(0,-8.72),-1)
	piece("core",core,Vector2(56,45),Vector2.ZERO)
	var neck := bone("Neck",torso,Vector2(0,-50))
	var head := bone("Head",neck,Vector2(0,-18),4)
	piece("head",head,Vector2(45,48),Vector2.ZERO)
	for side in ["Left","Right"]:
		var prefix: String=side.to_lower()
		var sign_x := -1.0 if side=="Left" else 1.0
		var shoulder := bone(side+"Shoulder",torso,Vector2(sign_x*76,-20),1)
		var upper := bone(side+"UpperArm",shoulder,Vector2.ZERO)
		piece(prefix+"_upper",upper,Vector2(46,52),Vector2(0,UPPER_ARM*.5))
		var elbow := bone(side+"Elbow",upper,Vector2(0,UPPER_ARM))
		var lower := bone(side+"Forearm",elbow,Vector2.ZERO)
		piece(prefix+"_forearm",lower,Vector2(53,51),Vector2(0,FOREARM*.5))
		var wrist := bone(side+"Wrist",lower,Vector2(0,FOREARM))
		var fist := bone(side+"Fist",wrist,Vector2(0,7))
		piece(prefix+"_fist",fist,Vector2(51,43),Vector2(0,5))
		var armor := bone(side+"Armor",shoulder,Vector2(sign_x*2,0),2)
		piece(prefix+"_armor",armor,Vector2(64,48),Vector2.ZERO)
		var hip := bone(side+"Hip",pelvis,Vector2(sign_x*37,0))
		var thigh := bone(side+"Thigh",hip,Vector2.ZERO)
		piece(prefix+"_thigh",thigh,Vector2(45,48),Vector2(0,THIGH*.5))
		var knee := bone(side+"Knee",thigh,Vector2(0,THIGH))
		var shin := bone(side+"Shin",knee,Vector2.ZERO)
		piece(prefix+"_shin",shin,Vector2(42,47),Vector2(0,SHIN*.5))
		var ankle := bone(side+"Ankle",shin,Vector2(0,SHIN))
		var foot := bone(side+"Foot",ankle,Vector2.ZERO)
		piece(prefix+"_foot",foot,Vector2(56,27),Vector2(0,2))
	set_view(facing)

func set_view(view: String) -> void:
	facing=view
	var folder := "side" if view in ["right","left"] else view
	scale.x=-absf(scale.x) if view=="left" else absf(scale.x)
	for slot in pieces:
		var file: String=slot.trim_suffix("_armor")+"_armor" if slot.ends_with("_armor") else slot
		if slot.ends_with("_armor"):file="armor"
		var texture: Texture2D=ImageTexture.create_from_image(Image.load_from_file(ART+folder+"/"+file+".png"))
		var entry: Dictionary=pieces[slot];entry.sprite.texture=texture;entry.sprite.scale=Vector2.ONE*minf(entry.size.x/texture.get_width(),entry.size.y/texture.get_height())
	pieces.torso.sprite.scale=Vector2.ONE*minf((128.0 if folder=="side" else 146.0)/pieces.torso.sprite.texture.get_width(),124.0/pieces.torso.sprite.texture.get_height())
	pieces.core.sprite.visible=false # New torso owns the embedded crystal; no duplicate rim.
	joints.Head.position.x=0
	for side in ["Left","Right"]:
		var sign_x := -1.0 if side=="Left" else 1.0
		joints[side+"Shoulder"].position=Vector2((-18 if side=="Left" else 3) if folder=="side" else sign_x*76,-15 if folder=="side" else -20)
		joints[side+"Shoulder"].z_index=(-2 if side=="Left" else 1) if folder=="side" else (-1 if folder=="back" else 1)
		joints[side+"Armor"].z_index=3 if folder=="back" else 1
		joints[side+"Armor"].visible=not(folder=="side" and side=="Left")
		var armor_sprite: Sprite2D=pieces[side.to_lower()+"_armor"].sprite
		armor_sprite.scale=Vector2.ONE*minf(60.0/armor_sprite.texture.get_width(),40.0/armor_sprite.texture.get_height())
		joints[side+"Hip"].position=Vector2(sign_x*(18 if folder=="side" else 37),0)
		joints[side+"Hip"].z_index=0 if side=="Left" else 1
		var tint := Color(.72,.77,.80) if folder=="side" and side=="Left" else Color.WHITE
		for part in ["upper","forearm","fist","thigh","shin","foot"]:pieces[side.to_lower()+"_"+part].sprite.modulate=tint
	set_posture(posture)

func set_posture(value: String) -> void:
	posture=value
	for node in joints.values():node.rotation=0
	joints.Pelvis.position=Vector2(0,-72)
	joints.Torso.position=Vector2(0,-46)
	joints.Head.position=Vector2(0,-18)
	var side_view := facing in ["right","left"]
	for side in ["Left","Right"]:
		var sign_x := -1.0 if side=="Left" else 1.0
		joints[side+"Hip"].position=Vector2(sign_x*(4 if side_view else 37),0)
		joints[side+"Knee"].position=Vector2(0,THIGH)
		joints[side+"Ankle"].position=Vector2(0,SHIN)
		# Outward progression from hip to knee to ankle, never a knock-knee IK solution.
		joints[side+"Thigh"].rotation=-sign_x*.16 if not side_view else -.10
		joints[side+"Shin"].rotation=sign_x*.02 if not side_view else .20
		joints[side+"UpperArm"].rotation=-sign_x*.08 if not side_view else -.07
		joints[side+"Elbow"].rotation=sign_x*.13 if not side_view else -.15
		joints[side+"Foot"].rotation=-joints[side+"Thigh"].rotation-joints[side+"Shin"].rotation
	joints.LeftHip.z_index=0;joints.RightHip.z_index=1
	ground_depth={"Left":0.0,"Right":0.0}
	sagittal={"Left":[0.0,0.0],"Right":[0.0,0.0]}
	if value=="contact":
		if side_view:
			joints.LeftThigh.rotation=-.43;joints.LeftShin.rotation=.12
			joints.RightThigh.rotation=.43;joints.RightShin.rotation=-.12
			joints.LeftUpperArm.rotation=.30;joints.LeftElbow.rotation=-.38
			joints.RightUpperArm.rotation=-.38;joints.RightElbow.rotation=-.12
			joints.Torso.rotation=-.035;joints.Neck.rotation=.035
		else:
			var back := facing=="back"
			project_leg("Right",.42,-.12)
			joints.LeftThigh.rotation=.18;joints.LeftShin.rotation=-.10
			joints.RightThigh.rotation=-.25;joints.RightShin.rotation=.18
			joints.LeftUpperArm.rotation=-.24 if back else .26
			joints.RightUpperArm.rotation=-.30 if back else -.38
			joints.LeftElbow.rotation=.30 if back else -.32
			joints.RightElbow.rotation=.14 if back else .24
			joints.Torso.rotation=.025 if back else -.025;joints.Neck.rotation=-joints.Torso.rotation
			joints.RightHip.z_index=1 if back else 0
	if value=="down":
		if side_view:
			joints.LeftThigh.rotation=-.70;joints.LeftShin.rotation=1.12
			joints.RightThigh.rotation=.85;joints.RightShin.rotation=-1.10
			joints.LeftUpperArm.rotation=.20;joints.LeftElbow.rotation=-.52
			joints.RightUpperArm.rotation=-.29;joints.RightElbow.rotation=-.31
			joints.Torso.rotation=-.065;joints.Neck.rotation=.065
		else:
			var back := facing=="back"
			project_leg("Right",.36,.18)
			joints.LeftThigh.rotation=.55 if not back else .58
			joints.LeftShin.rotation=-.90 if not back else -.94
			joints.RightThigh.rotation=-.46;joints.RightShin.rotation=.85

			joints.LeftUpperArm.rotation=.17 if not back else -.28
			joints.RightUpperArm.rotation=-.25 if not back else -.18
			joints.LeftElbow.rotation=-.46 if not back else .46
			joints.RightElbow.rotation=.40 if not back else .26
			joints.Torso.rotation=-.045 if not back else .035;joints.Neck.rotation=-joints.Torso.rotation
		joints.Torso.position.y+=2.0
		joints.RightWrist.rotation=.08;joints.LeftWrist.rotation=-.06
		joints.RightArmor.rotation=-.07;joints.LeftArmor.rotation=.06
	if value=="passing":
		if side_view:
			joints.LeftThigh.rotation=-.08;joints.LeftShin.rotation=.16
			joints.RightThigh.rotation=-.65;joints.RightShin.rotation=1.45
			joints.LeftUpperArm.rotation=.10;joints.LeftElbow.rotation=-.25
			joints.RightUpperArm.rotation=-.15;joints.RightElbow.rotation=-.48
			joints.Torso.rotation=-.025;joints.Neck.rotation=.025
		else:
			var back := facing=="back"
			joints.LeftThigh.rotation=.10;joints.LeftShin.rotation=-.16
			joints.RightThigh.rotation=-.60 if back else -.75
			joints.RightShin.rotation=1.25 if back else 1.15
			project_leg("Right",-.25,.55)
			joints.LeftUpperArm.rotation=.11 if not back else -.12
			joints.RightUpperArm.rotation=-.15 if not back else -.24
			joints.LeftElbow.rotation=-.22 if not back else .24
			joints.RightElbow.rotation=.50 if not back else .55
			joints.Torso.rotation=-.02 if not back else .025;joints.Neck.rotation=-joints.Torso.rotation
		joints.RightWrist.rotation=-.045;joints.RightArmor.rotation=.04
	# Center the complete rock between projected joints; no texture deformation.
	for side in ["Left","Right"]:
		var prefix: String=side.to_lower()
		pieces[prefix+"_thigh"].sprite.position.y=joints[side+"Knee"].position.y*.5
		pieces[prefix+"_shin"].sprite.position.y=joints[side+"Ankle"].position.y*.5
	# Explicit limits for this reusable candidate skeleton, in radians.
	for side in ["Left","Right"]:
		joints[side+"Thigh"].rotation=clampf(joints[side+"Thigh"].rotation,-.96,.96)
		joints[side+"Shin"].rotation=clampf(joints[side+"Shin"].rotation,-1.745,1.745)
		joints[side+"UpperArm"].rotation=clampf(joints[side+"UpperArm"].rotation,-.70,.70)
		joints[side+"Elbow"].rotation=clampf(joints[side+"Elbow"].rotation,-1.13,1.13)
		joints[side+"Wrist"].rotation=clampf(joints[side+"Wrist"].rotation,-.21,.21)
		joints[side+"Armor"].rotation=clampf(joints[side+"Armor"].rotation,-.175,.175)
	# Level loaded sole, stationary root ground. Left foot supports these phases.
	for side in ["Left","Right"]:
		joints[side+"Foot"].rotation=-joints[side+"Thigh"].rotation-joints[side+"Shin"].rotation
	var loaded: Vector2=sole("Left")
	joints.Pelvis.position.y-=loaded.y
	if value!="neutral":joints.Pelvis.position.x=(24 if side_view else -47)-to_local(joints.LeftFoot.global_position).x
	if value=="contact" and not side_view:
		# Pelvis roll seats both soles on their own projected ground points.
		joints.RightHip.position.y+=ground_depth.Right-sole("Right").y
