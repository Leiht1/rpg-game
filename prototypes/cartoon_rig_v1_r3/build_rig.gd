extends SceneTree
var rig: Node2D
func _initialize() -> void:
	call_deferred("build")
func node(n: String, parent: Node, pos: Vector2, z: int=0) -> Node2D:
	var v:=Node2D.new()
	v.name=n
	parent.add_child(v)
	v.owner=rig
	v.position=pos
	v.z_index=z
	return v
func sprite(n: String, parent:Node, tex:String, offset:Vector2) -> void:
	var v:=Sprite2D.new()
	v.name=n
	parent.add_child(v)
	v.owner=rig
	v.texture=load("res://art/front_"+tex+".png")
	v.position=offset
	v.scale=Vector2.ONE*0.25
func track(a:Animation,path:String,values:Array,discrete:bool=false) -> void:
	var i:=a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i,NodePath(path))
	if discrete:a.value_track_set_update_mode(i,Animation.UPDATE_DISCRETE)
	for k in values.size():
		a.track_insert_key(i,a.length*float(k)/float(maxi(values.size()-1,1)),values[k])
func build() -> void:
	rig=Node2D.new()
	rig.name="Character"
	var visual:=node("Visual",rig,Vector2.ZERO)
	var pelvis:=node("Pelvis",visual,Vector2(64,87),0)
	sprite("Torso",pelvis,"torso",Vector2(0,-11))
	var head:=node("Head",pelvis,Vector2(0,-20),4)
	sprite("Sprite",head,"head",Vector2(0,-22.5))
	for side in ["L","R"]:
		var arm:=node("Arm"+side,pelvis,Vector2(-11 if side=="L" else 11,-19),-1)
		sprite("Sprite",arm,"arm",Vector2(0,9.5))
		var leg:=node("Leg"+side,visual,Vector2(59 if side=="L" else 69,87),-2)
		sprite("Sprite",leg,"leg",Vector2(0,11.5))
	var ap:=AnimationPlayer.new()
	ap.name="AnimationPlayer"
	rig.add_child(ap)
	ap.owner=rig
	var lib:=AnimationLibrary.new()
	for d in ["front","side"]:
		for action in ["breathe","walk","run","wave"]:
			var a:=Animation.new()
			a.length={"breathe":1.8,"walk":0.64,"run":0.44,"wave":1.6}[action]
			a.loop_mode=Animation.LOOP_LINEAR
			var pv:Array=[];var pr:Array=[];var hp:Array=[];var hr:Array=[];var ts:Array=[]
			var al:Array=[];var ar:Array=[];var alp:Array=[];var arp:Array=[]
			var ll:Array=[];var lr:Array=[];var llp:Array=[];var lrp:Array=[];var lls:Array=[];var lrs:Array=[]
			for k in 65:
				var t:=float(k)/64.0
				var w:=t*TAU
				var moving:bool=action=="walk" or action=="run"
				var running:bool=action=="run"
				var bob:float=(-0.6 if not running else -1.6)*(1.0-cos(w*2.0)) if moving else 0.0
				var sway:float=sin(w)*0.6 if moving and d=="front" else 0.0
				pv.append(Vector2(64+sway,87+bob))
				pr.append((-0.10 if running and d=="side" else 0.0)+(sin(w)*0.016 if moving else sin(w)*0.006))
				hp.append(Vector2(-2 if d=="side" else 0,-20-(0.25+0.25*sin(w))) if action=="breathe" else Vector2(-2 if d=="side" else 0,-20))
				hr.append(sin(w-0.4)*0.012 if not moving else -sin(w)*0.02)
				ts.append(Vector2(1.0+sin(w)*0.006,1.0+sin(w)*0.009)*0.25 if action=="breathe" else Vector2.ONE*0.25)
				for j in 2:
					var sign_:float=-1.0 if j==0 else 1.0
					var p:float=fposmod(t+float(j)*0.5,1.0)
					var x:=0.0;var lift:=0.0
					if moving:
						# 60% stance: constant ground velocity. 40% return: eased low arc.
						var stride:float=8.0 if running else 5.5
						if p<0.6:x=lerpf(stride,-stride,p/0.6)
						else:
							var u:float=(p-0.6)/0.4
							x=lerpf(-stride,stride,u*u*(3.0-2.0*u))
							lift=sin(u*PI)*(5.0 if running else 2.3)
					var hip:=Vector2(64+sign_*5+sway,87+bob) if d=="front" else Vector2(64+sign_*2,87+bob)
					var dx:float=x if d=="side" else sign_*absf(x)*0.18
					var dy:float=25.0-bob-lift
					var rot:float=-atan2(dx,dy)
					var scl:=Vector2(1.0,sqrt(dx*dx+dy*dy)/25.0)
					(llp if j==0 else lrp).append(hip)
					(ll if j==0 else lr).append(rot)
					(lls if j==0 else lrs).append(scl)
					var arm_rot:float=-sign_*0.10
					if moving:arm_rot=-rot*2.0-sign_*0.10 if d=="side" else sin((t+float(j)*0.5)*TAU)*0.16-sign_*0.10
					if action=="wave" and j==1:arm_rot=-1.8+sin(w*2.0)*0.25
					(al if j==0 else ar).append(arm_rot)
					(alp if j==0 else arp).append(Vector2(sign_*11,-19) if d=="front" else Vector2(sign_*2,-19))
			track(a,"Visual/Pelvis:position",pv)
			track(a,"Visual/Pelvis:rotation",pr)
			track(a,"Visual/Pelvis/Head:position",hp)
			track(a,"Visual/Pelvis/Head:rotation",hr)
			track(a,"Visual/Pelvis/Torso:scale",ts)
			track(a,"Visual/Pelvis/ArmL:z_index",[-1 if d=="front" else -3],true)
			track(a,"Visual/Pelvis/ArmR:z_index",[5 if action=="wave" else (-1 if d=="front" else 2)],true)
			track(a,"Visual/Pelvis/ArmL/Sprite:flip_h",[d=="front"],true)
			track(a,"Visual/LegL/Sprite:flip_h",[d=="front"],true)
			for j in 2:
				var s:String="L" if j==0 else "R"
				track(a,"Visual/Pelvis/Arm"+s+":rotation",al if j==0 else ar)
				track(a,"Visual/Pelvis/Arm"+s+":position",alp if j==0 else arp)
				track(a,"Visual/Leg"+s+":position",llp if j==0 else lrp)
				track(a,"Visual/Leg"+s+":rotation",ll if j==0 else lr)
				track(a,"Visual/Leg"+s+":scale",lls if j==0 else lrs)
			for path in ["Pelvis/Head/Sprite","Pelvis/Torso","Pelvis/ArmL/Sprite","Pelvis/ArmR/Sprite","LegL/Sprite","LegR/Sprite"]:
				var part:String="head" if "Head" in path else ("torso" if "Torso" in path else ("arm" if "Arm" in path else "leg"))
				track(a,"Visual/"+path+":texture",[load("res://art/"+d+"_"+part+".png")],true)
			lib.add_animation(d+"_"+action,a)
	ap.add_animation_library("",lib)
	ap.autoplay="front_breathe"
	var packed:=PackedScene.new()
	packed.pack(rig)
	ResourceSaver.save(packed,"res://character.tscn")
	print("Built 8 editable native animations, 6 clothed part sprites, sleeves/shorts attached to limbs, 6 pivots")
	rig.free()
	quit()


