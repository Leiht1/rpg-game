extends SceneTree
var failures:=0
class Body extends RefCounted:
	var down:=false
	func sleep_active() -> bool:return false
class Service extends Node:
	var body=Body.new()
func check(ok: bool,label: String) -> void:
	print("CHECK ",ok," ",label)
	if not ok:failures+=1
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var Motion=load("res://scripts/network_animal_motion.gd")
	for cadence in [.2,.4,.75]:
		var motion=Motion.new();var old:=Vector2.ZERO;var direct:=Vector2.ZERO
		var previous:=Vector2.ZERO;var deltas: Array=[];var before: Array=[];var burst: Array=[]
		for frame in 900:
			var target:=Vector2(floori(frame/(cadence*60))*cadence*36,0)
			var next: Vector2=motion.advance(target,1.0/60)
			var old_previous:=old
			old=old.lerp(target,.2)
			if frame>180:
				deltas.append(next.distance_to(previous));before.append(target.distance_to(direct));burst.append(old.distance_to(old_previous))
			previous=next;direct=target
		var maximum: float=deltas.max()
		check(maximum<1.5,"bounded per-frame animal motion cadence "+str(cadence))
		check(deltas.filter(func(v):return v<.01).size()<10,"no stop/burst between moving samples "+str(cadence))
		print("METRIC cadence=",cadence," direct_max=",before.max()," chicken_before_max=",burst.max()," smooth_max=",maximum," chicken_before_stopped_frames=",burst.filter(func(v):return v<.01).size()," smooth_stopped_frames=",deltas.filter(func(v):return v<.01).size())
		var stopped: Vector2=motion.target
		for i in 180:motion.advance(stopped,1.0/60)
		check(motion.displayed.is_equal_approx(stopped),"stop converges without extrapolation")
		check(motion.advance(stopped+Vector2(500,0),.016)==stopped+Vector2(500,0),"teleport snaps without crossing map")
		check(motion.advance(stopped,.016,true)==stopped,"death/reset snaps")
	var service=Service.new();root.add_child(service)
	var combat=load("res://scripts/combat_service.gd").new();combat.service=service
	combat.attack_preview={"weapon":{"windup":.1,"active":.1,"recovery":.1},"hit_serial":0,"elapsed":0}
	combat.attack_preview_started=Time.get_ticks_msec()-1000
	check(not combat.attack_state().is_empty(),"late acceptance cannot open a movement prediction window")
	combat.personal.attack=combat.attack_preview.duplicate(true);combat.confirm_attack_preview(true)
	check(not combat.attack_state().is_empty(),"authority attack remains locked")
	combat.personal.attack={}
	check(combat.attack_state().is_empty(),"authority completion releases lock")
	combat.attack_preview={"weapon":{"windup":.1,"active":.1,"recovery":.1},"hit_serial":0};combat.confirm_attack_preview(false)
	check(combat.attack_state().is_empty(),"rejection releases preview")
	# Exercise the actual boar drawing while keeping its collision at authority.
	var boar=load("res://scripts/combat_world_view.gd").Boar.new()
	boar.networked=true;boar.position=Vector2(100,100)
	boar.record={"health":45,"mode":"patrol","clock":0,"hit":0}
	root.add_child(boar);boar.set_process(false)
	for i in 45:boar._process(1.0/60)
	boar.position+=Vector2(27,0);boar._process(1.0/60)
	check(boar.position==Vector2(127,100),"collision remains at authoritative location")
	check(boar.skeleton.position.x< -20,"boar drawing interpolates instead of teleporting")
	for i in 60:boar._process(1.0/60)
	check(boar.skeleton.position.is_zero_approx(),"boar drawing reaches stopped authority")
	boar.networked=false;boar.position+=Vector2(20,0);boar._process(.016)
	check(boar.skeleton.position.is_zero_approx(),"offline boar remains exact")
	boar.free();service.free()
	print("FAILURES ",failures);quit(1 if failures else 0)
