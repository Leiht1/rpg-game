extends RefCounted
var rig:Node2D
func prop(n:String,parent:Node,texture:String,pos:Vector2,z:int)->Sprite2D:
	var s:=Sprite2D.new()
	s.name=n
	parent.add_child(s)
	s.owner=rig
	s.texture=load("res://art/"+texture+".png")
	s.scale=Vector2.ONE*.25
	s.position=pos
	s.z_index=z
	s.visible=false
	return s
func keys(a:Animation,path:String,values:Array,discrete:bool=false)->void:
	var old:=a.find_track(NodePath(path),Animation.TYPE_VALUE)
	if old>=0:a.remove_track(old)
	var ti:=a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti,NodePath(path))
	if discrete:a.value_track_set_update_mode(ti,Animation.UPDATE_DISCRETE)
	for k in values.size():a.track_insert_key(ti,a.length*k/maxf(values.size()-1,1),values[k])
func curve(t:float,points:Array)->float:
	for i in range(1,points.size()):
		if t<=points[i][0]:
			var u:=clampf((t-points[i-1][0])/(points[i][0]-points[i-1][0]),0,1)
			u=u*u*(3-2*u)
			return lerpf(points[i-1][1],points[i][1],u)
	return points[-1][1]
func build(character:Node2D,lib:AnimationLibrary)->void:
	rig=character
	var v:=rig.get_node("Visual")
	var grip:=Node2D.new()
	grip.name="Grip"
	rig.get_node("Visual/Pelvis/ArmR").add_child(grip)
	grip.owner=rig
	grip.position=Vector2(0,21)
	# Handle axis is x=-4.8; its lower grip lies 13px below image centre.
	prop("Axe",grip,"axe",Vector2(4.8,-13),0)
	prop("Tree",v,"tree",Vector2(113,76),-8)
	prop("Fruit",v,"fruit",Vector2(82,108),6)
	for name in lib.get_animation_list():
		var a:=lib.get_animation(name)
		for path in ["Visual/Pelvis/ArmR/Grip/Axe:visible","Visual/Tree:visible","Visual/Fruit:visible"]:keys(a,path,[false],true)
	for d in ["front","side"]:
		for action in ["chop","pickup"]:
			var a:Animation=lib.get_animation(d+"_breathe").duplicate(true)
			a.length=1.65 if action=="chop" else 2.2
			# Keep direction-specific texture and layer tracks; replace all pose tracks.
			var paths=["Visual/Pelvis:position","Visual/Pelvis:rotation","Visual/Pelvis/Head:position","Visual/Pelvis/Head:rotation","Visual/Pelvis/Torso:scale","Visual/Pelvis/ArmL:position","Visual/Pelvis/ArmR:position","Visual/Pelvis/ArmL:rotation","Visual/Pelvis/ArmR:rotation","Visual/LegL:position","Visual/LegR:position","Visual/LegL:rotation","Visual/LegR:rotation","Visual/LegL:scale","Visual/LegR:scale","Visual/Pelvis/ArmR/Grip:rotation","Visual/Tree:rotation","Visual/Tree:position","Visual/Fruit:position","Visual/Fruit:modulate"]
			var samples:Array=[]
			for path in paths:samples.append([])
			var contact:=Vector2.ZERO
			for k in 97:
				var t:=float(k)/96
				var body:=0.0;var drop:=0.0;var right:=-.10;var left:=.10;var headrot:=0.0;var toolworld:=.6
				if action=="chop":
					body=curve(t,[[0,0.02],[.3,-.10],[.47,.18],[.54,.18],[.77,.04],[1,.02]])
					right=curve(t,[[0,-.65],[.30,-2.45],[.36,-2.5],[.47,-.70],[.54,-.70],[.8,-.65],[1,-.65]])
					toolworld=curve(t,[[0,.15],[.30,.15],[.36,.15],[.47,.95],[.54,.95],[.8,.15],[1,.15]])
					left=curve(t,[[0,.1],[.32,.35],[.48,-.3],[.55,-.3],[.85,.1],[1,.1]])
					headrot=-body*.35
				else:
					var bend:=curve(t,[[0,0],[.12,0],[.43,1],[.52,1],[.8,0],[1,0]])
					body=bend*(.8 if d=="side" else .7)
					drop=bend*(5 if d=="side" else 3.5)
					right=-body+(-.55*bend if d=="front" else 0)
					left=.10+bend*.35
					headrot=-body*.65
				var pelvis:=Vector2(64,94+drop)
				var hip_depth:float=-3.0*(drop/(5 if d=="side" else 3.5)) if action=="pickup" else 0.0
				var spread:float=5.0 if d=="front" else 2.0
				# Hip roots follow the shirt waist; sole targets stay on the floor.
				var hips=[pelvis+Vector2(-spread,hip_depth).rotated(body),pelvis+Vector2(spread,hip_depth).rotated(body)]
				var feet=[Vector2(64-spread,112),Vector2(64+spread,112)]
				var lv:Vector2=feet[0]-hips[0]
				var rv:Vector2=feet[1]-hips[1]
				var arpos:=Vector2(2 if d=="side" else 11,-19)
				var alpos:=Vector2(-2 if d=="side" else -11,-19)
				var shoulder:=pelvis+arpos.rotated(body)
				var hand:=shoulder+Vector2(0,21).rotated(body+right)
				# The floor item sits at the exact maximum-reach hand contact.
				var maxbody:float=.8 if d=="side" else .7
				var maxarm:float=-maxbody+(-.55 if d=="front" else 0)
				contact=Vector2(64,99 if d=="side" else 97.5)+arpos.rotated(maxbody)+Vector2(0,21).rotated(maxbody+maxarm)
				var itempos:=hand if action=="pickup" and t>=.52 and t<.94 else contact
				var alpha:=curve(t,[[0,1],[.84,1],[.92,0],[.96,0],[1,1]])
				var tree_rot:=curve(t,[[0,0],[.47,0],[.49,.018],[.52,-.014],[.56,.008],[.61,0],[1,0]]) if action=="chop" else 0.0
				var values=[pelvis,body,Vector2(-2 if d=="side" else 0,-20),headrot,Vector2.ONE*.25,alpos,arpos,left,right,hips[0],hips[1],-atan2(lv.x,lv.y),-atan2(rv.x,rv.y),Vector2(1,lv.length()/18),Vector2(1,rv.length()/18),toolworld-body-right,tree_rot,Vector2(115 if d=="front" else 106,76),itempos,Color(1,1,1,alpha)]
				for i in paths.size():samples[i].append(values[i])
			for i in paths.size():keys(a,paths[i],samples[i])
			keys(a,"Visual/Pelvis/ArmR:z_index",[5],true)
			keys(a,"Visual/Pelvis/ArmR/Grip/Axe:visible",[action=="chop"],true)
			keys(a,"Visual/Tree:visible",[action=="chop"],true)
			keys(a,"Visual/Fruit:visible",[action=="pickup"],true)
			lib.add_animation(d+"_"+action,a)
