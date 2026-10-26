extends Node2D
## V2 posture study. No movement clock, gait loop, IK, combat or authority writes.
const ART := "res://prototypes/boss-posture-v2/parts/"
const UPPER_ARM := 35.0
const FOREARM := 33.0
const THIGH := 32.0
const SHIN := 32.0
var joints: Dictionary = {}
var pieces: Dictionary = {}
var rest: Dictionary = {}
var facing := "front"
var posture := "neutral"

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
		var entry: Dictionary=pieces[slot];entry.sprite.texture=texture;entry.sprite.scale=entry.size/texture.get_size()
	pieces.torso.sprite.scale.x=(128.0 if folder=="side" else 146.0)/pieces.torso.sprite.texture.get_width()
	pieces.core.sprite.visible=folder=="front"
	joints.Head.position.x=0
	for side in ["Left","Right"]:
		var sign_x := -1.0 if side=="Left" else 1.0
		joints[side+"Shoulder"].position=Vector2((-18 if side=="Left" else 3) if folder=="side" else sign_x*76,-15 if folder=="side" else -20)
		joints[side+"Shoulder"].z_index=(-2 if side=="Left" else 1) if folder=="side" else (-1 if folder=="back" else 1)
		joints[side+"Armor"].z_index=3 if folder=="back" else 1
		joints[side+"Armor"].visible=not(folder=="side" and side=="Left")
		var armor_sprite: Sprite2D=pieces[side.to_lower()+"_armor"].sprite
		armor_sprite.scale=Vector2(52,44)/armor_sprite.texture.get_size() if folder=="side" else Vector2(64,48)/armor_sprite.texture.get_size()
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
		joints[side+"Hip"].position=Vector2(sign_x*(18 if side_view else 37),0)
		joints[side+"Knee"].position=Vector2(0,THIGH)
		joints[side+"Ankle"].position=Vector2(0,SHIN)
		# Outward progression from hip to knee to ankle, never a knock-knee IK solution.
		joints[side+"Thigh"].rotation=-sign_x*.16 if not side_view else -.10
		joints[side+"Shin"].rotation=sign_x*.02 if not side_view else .20
		joints[side+"UpperArm"].rotation=-sign_x*.08 if not side_view else -.07
		joints[side+"Elbow"].rotation=sign_x*.13 if not side_view else -.15
		joints[side+"Foot"].rotation=-joints[side+"Thigh"].rotation-joints[side+"Shin"].rotation
	# Static stance reviewed before authoring these discrete phases. No interpolation.
	if value!="neutral":
		if side_view:
			var angles: Array={"contact":[.28,-.38,-.28,.38],"down":[.18,-.38,-.40,.65],"passing":[.08,-.12,-.70,1.25]}[value]
			joints.LeftThigh.rotation=angles[0];joints.LeftShin.rotation=angles[1]
			joints.RightThigh.rotation=angles[2];joints.RightShin.rotation=angles[3]
			joints.Torso.rotation=-.018 if value=="contact" else -.03
			joints.Neck.rotation=-joints.Torso.rotation
			joints.LeftUpperArm.rotation=-.12;joints.RightUpperArm.rotation=.10
			joints.RightElbow.rotation=-.20;joints.LeftElbow.rotation=-.10
			joints.RightWrist.rotation=.025;joints.RightArmor.rotation=-.035
		else:
			# Sagittal foreshortening: projected segments shorten on the swinging leg;
			# physical limb lengths remain THIGH/SHIN and assets never rescale.
			if value=="contact":
				joints.RightThigh.rotation=-.20;joints.RightShin.rotation=.04
			elif value=="down":
				joints.LeftHip.position.x=-14
				joints.LeftThigh.rotation=.26;joints.LeftShin.rotation=-.10
				joints.RightKnee.position.y=THIGH*.96
				joints.RightAnkle.position.y=SHIN*.94
			else:
				joints.LeftHip.position.x=-17
				joints.RightThigh.rotation=-.42;joints.RightShin.rotation=.30
				joints.RightKnee.position.y=THIGH*.88
				joints.RightAnkle.position.y=SHIN*.82
			joints.LeftUpperArm.rotation=-.035;joints.RightUpperArm.rotation=-.14
			joints.LeftElbow.rotation=-.17;joints.RightElbow.rotation=.08
			joints.RightWrist.rotation=.02;joints.RightArmor.rotation=-.025
		if value=="down":
			joints.Torso.position.y+=2.5
			joints.Head.position.y=-17
	# Level loaded sole, stationary root ground. Left foot supports these phases.
	for side in ["Left","Right"]:
		joints[side+"Foot"].rotation=-joints[side+"Thigh"].rotation-joints[side+"Shin"].rotation
	var loaded: Vector2=to_local(joints.LeftFoot.global_position)
	joints.Pelvis.position.y-=loaded.y+15.5
	if value!="neutral":joints.Pelvis.position.x=(-18 if side_view else -47)-to_local(joints.LeftFoot.global_position).x
