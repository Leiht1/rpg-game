extends Node2D
## Presentation only. Root position is owned by the existing finale view.
const ART := "res://assets/exploration/boss-rig-v1/"
const STRIDE := 72.0
const STANCE := .62
var joints: Dictionary = {}
var pictures: Dictionary = {}
var rest: Dictionary = {}
var feet: Array[Dictionary] = []
var facing := "front"
var heading := Vector2.DOWN
var candidate := "front"
var candidate_time := 0.0
var phase := 0.0
var clock := 0.0
var weight := 0.0
var old_world := Vector2.ZERO
var initialized := false
var motion_root: Node2D
var pelvis: Node2D
var torso: Node2D
var attack_weight := 0.0
var last_mode := "idle"
var pose_override: Dictionary = {}

func joint(id: String, parent: Node2D, at: Vector2) -> Node2D:
	var node := Node2D.new();node.name=id;node.position=at;parent.add_child(node)
	joints[id]=node;rest[id]=at;return node

func art(id: String, slot: String, parent: Node2D, size: Vector2, offset: Vector2, z: int=0) -> void:
	var pic := Sprite2D.new();pic.name=slot;parent.add_child(pic);pic.position=offset;pic.z_index=z
	pictures[id]={"sprite":pic,"slot":slot,"size":size}

func _ready() -> void:
	motion_root=joint("Motion",self,Vector2.ZERO)
	pelvis=joint("BodyRoot",motion_root,Vector2(0,-69))
	torso=joint("Torso",pelvis,Vector2(0,-39));torso.z_index=2
	art("torso","torso",torso,Vector2(100,92),Vector2(0,-4))
	var chest := joint("Chest",torso,Vector2(0,-12))
	var core := joint("Core",chest,Vector2(0,22));art("core","core",core,Vector2(44,46),Vector2.ZERO,2)
	var neck := joint("Neck",torso,Vector2(0,-43))
	var head := joint("Head",neck,Vector2(0,-10));art("head","head",head,Vector2(43,43),Vector2.ZERO,2)
	for side in ["Left","Right"]:
		var sign_x := -1.0 if side=="Left" else 1.0
		var prefix := "left" if side=="Left" else "right"
		var shoulder := joint(side+"Shoulder",torso,Vector2(sign_x*56,-27))
		var upper := joint(side+"UpperArm",shoulder,Vector2.ZERO)
		art(prefix+"_upper",prefix+"_upper",upper,Vector2(38,44),Vector2(0,15))
		var elbow := joint(side+"Elbow",upper,Vector2(0,30))
		var forearm := joint(side+"Forearm",elbow,Vector2.ZERO)
		art(prefix+"_forearm",prefix+"_forearm",forearm,Vector2(45,48),Vector2(0,16))
		var wrist := joint(side+"Wrist",forearm,Vector2(0,31))
		var fist := joint(side+"Fist",wrist,Vector2(0,7));art(prefix+"_fist",prefix+"_fist",fist,Vector2(42,37),Vector2(0,4))
		var armor := joint(side+"Armor",shoulder,Vector2(sign_x*4,-5));art(prefix+"_armor","armor",armor,Vector2(48,39),Vector2.ZERO,3)
		var hip := joint(side+"Hip",pelvis,Vector2(sign_x*23,0));hip.z_index=0
		var thigh := joint(side+"Thigh",hip,Vector2.ZERO)
		art(prefix+"_thigh",prefix+"_thigh",thigh,Vector2(37,54),Vector2(0,20))
		var knee := joint(side+"Knee",thigh,Vector2(0,40))
		var shin := joint(side+"Shin",knee,Vector2.ZERO)
		art(prefix+"_shin",prefix+"_shin",shin,Vector2(34,52),Vector2(0,19))
		var ankle := joint(side+"Ankle",shin,Vector2(0,38))
		var foot := joint(side+"Foot",ankle,Vector2.ZERO)
		art(prefix+"_foot",prefix+"_foot",foot,Vector2(41,23),Vector2(4,0))
		feet.append({"side":side,"anchor":Vector2.ZERO,"from":Vector2.ZERO,"landing":Vector2.ZERO,"swing":false,"lift":0.0})
	set_view("front")

func set_view(view: String) -> void:
	facing=view
	var folder := "side" if view in ["left","right"] else view
	motion_root.scale.x=-1 if view=="left" else 1
	for entry in pictures.values():
		var tex: Texture2D=load(ART+folder+"/"+entry.slot+".png")
		entry.sprite.texture=tex;entry.sprite.scale=entry.size/tex.get_size()
	var side_view := folder=="side"
	for side in ["Left","Right"]:
		var x := -1.0 if side=="Left" else 1.0
		joints[side+"Shoulder"].position=Vector2(x*(25 if side_view else 56),-27)
		joints[side+"Hip"].position=Vector2(x*(12 if side_view else 23),0)
		joints[side+"Shoulder"].z_index=(-2 if side=="Left" else 2) if side_view else (-1 if view=="back" else 2)
		joints[side+"Hip"].z_index=0 if side_view and side=="Left" else 1
		pictures[("left" if side=="Left" else "right")+"_armor"].sprite.modulate=Color(.82,.85,.88) if side_view and side=="Left" else Color.WHITE
	pictures.torso.sprite.scale.x=(76.0 if side_view else 100.0)/pictures.torso.sprite.texture.get_width()
	joints.Core.position.x=31 if side_view else 0
	pictures.core.sprite.visible=view!="back"
	pictures.core.sprite.scale.x=(15.0 if side_view else 44.0)/pictures.core.sprite.texture.get_width()
	# Rebase contact on a view change, without resetting the gait phase.
	initialized=false

func select_heading(velocity: Vector2, delta: float) -> void:
	if velocity.length()<2:return
	var v := velocity.normalized()
	var next := facing
	# Angular hysteresis: only leave a sector beyond its boundary.
	if absf(v.x)>absf(v.y)*1.22:next="right" if v.x>0 else "left"
	elif absf(v.y)>absf(v.x)*1.22:next="front" if v.y>0 else "back"
	if next!=candidate:candidate=next;candidate_time=0
	else:candidate_time+=delta
	if next!=facing and candidate_time>=.10:set_view(next)
	heading=v

func foot_rest(index: int) -> Vector2:
	var x := (-1.0 if index==0 else 1.0)*(12 if facing in ["left","right"] else 23)
	return motion_root.to_global(Vector2(x,-8))

func solve_leg(side: String, target: Vector2, lift: float) -> void:
	var hip: Node2D=joints[side+"Hip"]
	var local := hip.to_local(target)-Vector2(0,lift)
	var distance := clampf(local.length(),6,77.8)
	var axis := local.normalized()
	var along := (40.0*40.0-38.0*38.0+distance*distance)/(2*distance)
	var bend := sqrt(maxf(0,40.0*40.0-along*along))
	var bend_sign := -1.0 if facing in ["left","right"] else (-1.0 if side=="Left" else 1.0)
	var knee := axis*along+Vector2(-axis.y,axis.x)*bend*bend_sign
	var thigh: Node2D=joints[side+"Thigh"]
	var shin: Node2D=joints[side+"Shin"]
	thigh.rotation=knee.angle()-PI*.5
	joints[side+"Knee"].rotation=0
	shin.rotation=(axis*distance-knee).angle()-PI*.5-thigh.rotation
	joints[side+"Foot"].rotation=-thigh.rotation-shin.rotation

func advance(delta: float, world: Vector2, mode: String="chase", force_view: String="") -> void:
	if joints.is_empty():return
	clock+=delta
	var displacement := world-old_world if initialized else Vector2.ZERO
	var velocity := displacement/maxf(delta,.001)
	if displacement.length()>120:initialized=false;displacement=Vector2.ZERO;velocity=Vector2.ZERO
	if not force_view.is_empty():
		if facing!=force_view:set_view(force_view)
	else:select_heading(velocity,delta)
	if velocity.length()>2:heading=velocity.normalized()
	var walking := mode=="chase" and velocity.length()>1
	weight=move_toward(weight,1.0 if walking else 0.0,delta/(.24 if walking else .30))
	if walking:phase+=displacement.length()/STRIDE
	var wave := sin(phase*TAU)
	var idle := sin(clock*TAU/2.8)
	pelvis.position=Vector2(wave*2.6*weight,-69+absf(sin(phase*TAU))*2.5*weight)
	torso.position=Vector2(0,-39+idle*.8*(1-weight))
	torso.rotation=wave*.023*weight+idle*.008*(1-weight)
	joints.Head.rotation=-torso.rotation*.55+sin(clock*1.8)*.015
	joints.Core.scale=Vector2.ONE*(1+sin(clock*TAU/2.8)*.025)
	for i in 2:
		var side: String=feet[i].side
		var signed_wave := sin(phase*TAU+i*PI)
		joints[side+"UpperArm"].rotation=signed_wave*.12*weight+sin(clock*2.24+i*1.7)*.012
		joints[side+"Elbow"].rotation=(-.10 if i==0 else .10)+sin(phase*TAU+i*PI-.35)*.07*weight
		joints[side+"Wrist"].rotation=sin(phase*TAU+i*PI-.65)*.045*weight
		joints[side+"Armor"].position=rest[side+"Armor"]+Vector2(sin(clock*2+i)*.6,sin(phase*TAU+i*PI-.5)*1.5*weight+sin(clock*2.24+i)*.65)
		joints[side+"Armor"].rotation=sin(phase*TAU+i*PI-.6)*.025*weight
	if not initialized:
		for i in 2:
			feet[i].anchor=foot_rest(i);feet[i].from=feet[i].anchor;feet[i].landing=feet[i].anchor;feet[i].swing=false
		initialized=true
	for i in 2:
		var f: Dictionary=feet[i]
		var p := fposmod(phase+i*.5,1)
		var lift := 0.0
		if walking and p>=STANCE:
			if not f.swing:
				f.swing=true;f.from=f.anchor
				f.landing=foot_rest(i)+heading*(STRIDE*(1-STANCE)+STRIDE*.22)
			var t := (p-STANCE)/(1-STANCE)
			f.anchor=f.from.lerp(f.landing,t*t*(3-2*t));lift=sin(t*PI)*17*weight
		else:
			if f.swing:f.anchor=f.landing;f.swing=false
			if not walking:f.anchor=f.anchor.lerp(foot_rest(i),1-exp(-delta*13))
		f.lift=lift
		solve_leg(f.side,f.anchor,lift)
	# A separate override interface for future authored combat poses. No authority writes.
	for id in pose_override:
		if joints.has(id):joints[id].rotation=pose_override[id]
	old_world=world;last_mode=mode

func release_pose() -> void:
	pose_override.clear()
