extends RefCounted
## Shared state; receives only elapsed gameplay time, never clock jumps or wall time.
signal changed
const RULES = preload("res://scripts/body_rules.gd")
var rules: Dictionary = RULES.load_rules()
var discomfort := 0.0
var health := 100.0
var hunger := 100.0
var stamina := 100.0
var energy := 100.0
var sleeping := false
var sleep_forced := false
var sleep_elapsed := 0.0
var sleep_duration := 0.0
var sleep_session: Dictionary={}

func sleep_active() -> bool:
	return sleeping or not sleep_session.is_empty()
var deprivation := 0.0
var illness := 0.0
var reserve := 0.0
var build := 0.0
var damage_clock := 0.0
var rest_clock := 0.0
var rescue_clock := 0.0
var exhausted := false
var down := false
var busy := false
var hallucination_remaining := 0.0

func can_labor(action: String, finishing: bool=false) -> bool:
	return not sleep_active() and (energy>0 or finishing) and not down and not exhausted and stamina >= float(rules.labor_cost.get(action,0.0))

func spend_labor(action: String) -> void:
	stamina=maxf(0.0,stamina-float(rules.labor_cost.get(action,0.0)))
	rest_clock=0.0
	exhausted=stamina<float(rules.labor_cost.get(action,0.0))
	changed.emit()

func advance(seconds: float, minutes: float, sprinting: bool, working: bool) -> void:
	if seconds<=0.0 or minutes<=0.0: return
	# Fixed bounded slices keep thresholds, illness intervals and rescue reproducible.
	var remaining := minutes
	while remaining>0.000001:
		var step := minf(remaining,1.0)
		_tick(seconds*step/minutes,step,sprinting,working)
		remaining-=step
	changed.emit()

func _tick(seconds: float, minutes: float, sprinting: bool, working: bool) -> void:
	var affected := minf(minutes,hallucination_remaining)
	hallucination_remaining=maxf(0.0,hallucination_remaining-affected)
	health=maxf(0.0,health-affected*float(rules.hallucination_damage)/float(rules.hallucination_minutes))
	var days := minutes/1440.0
	var active := not sleeping and (sprinting or working)
	hunger=maxf(0.0,hunger-days*float(rules.hunger_per_day)*(float(rules.hunger_activity_multiplier) if active else 1.0))
	if sleeping:
		sleep_elapsed+=minutes
		var limit: float=float(sleep_session.get("target",100.0))
		var elapsed: float=minf(minutes,maxf(0,sleep_duration-(sleep_elapsed-minutes)))
		energy=minf(limit,energy+elapsed/60.0*float(sleep_session.get("rate",rules.sleep_energy_per_hour)))
		if sleep_elapsed+0.00001>=sleep_duration or energy+0.00001>=limit:
			sleep_elapsed=minf(sleep_elapsed,sleep_duration)
			sleeping=false
			if not sleep_session.is_empty(): sleep_session.reason="target" if energy+0.00001>=limit else "duration"
	else:
		energy=maxf(0.0,energy-minutes/60.0*float(rules.energy_per_hour)*(float(rules.energy_activity_multiplier) if active else 1.0))
	var shortage := 1.0-smoothstep(float(rules.hunger_severe),float(rules.hunger_low),hunger)
	deprivation=clampf(deprivation+days*(shortage if hunger<=0.0 else -float(rules.nutrition_recovery_per_day)),0.0,4.0)
	if hunger>=float(rules.hunger_recovery): illness=maxf(0.0,illness-days*float(rules.illness_recovery_per_day))
	elif hunger<=0.0 and deprivation>=float(rules.malnutrition_days): illness=minf(3.0,illness+days*float(rules.illness_threshold)/maxf(.1,float(rules.illness_days)-float(rules.malnutrition_days)))
	# Damage is interval based and stops immediately when nutrition improves.
	if illness>=float(rules.illness_threshold) and hunger<float(rules.hunger_low) and not down:
		damage_clock+=minutes
		while damage_clock>=float(rules.disease_damage_interval_minutes):
			damage_clock-=float(rules.disease_damage_interval_minutes)
			health=maxf(0.0,health-float(rules.disease_damage))
	else: damage_clock=0.0
	if health<=float(rules.down_health): down=true
	if down:
		rescue_clock+=minutes
		if rescue_clock>=float(rules.rescue_game_minutes):
			# Safe solo care, without granting items or losing inventory.
			health=minf(float(rules.revive_health),health+minutes*1.0)
			stamina=minf(40.0,stamina+minutes*2.0)
			illness=maxf(0.0,illness-days*3.0)
			if health>=float(rules.revive_health):
				down=false;rescue_clock=0.0;deprivation=minf(deprivation,.5);illness=0.0;exhausted=false
	elif sprinting and not exhausted:
		stamina=maxf(0.0,stamina-seconds*float(rules.run_per_second))
		rest_clock=0.0
		if stamina<=0: exhausted=true
	elif working:
		rest_clock=0.0
	else:
		rest_clock+=seconds
		if rest_clock>=float(rules.recovery_delay_seconds):
			stamina=minf(100.0,stamina+seconds*float(rules.recovery_per_second)*recovery_factor())
		if exhausted and stamina>=float(rules.resume_stamina): exhausted=false
		if hunger>=float(rules.hunger_recovery) and not busy and affected<=0.0: health=minf(100.0,health+minutes/float(rules.health_recovery_game_minutes))
	# Energy reserve integrates diet and activity over days, then body follows slowly.
	var reserve_input := (hunger-float(rules.reserve_balance_hunger))/(100.0-float(rules.reserve_balance_hunger))-(float(rules.reserve_activity_cost) if sprinting or working else 0.0)
	reserve=clampf(reserve+(reserve_input-reserve)*days/float(rules.reserve_response_days),-1.0,1.0)
	build=move_toward(build,reserve,days/float(rules.body_response_days))

func recovery_factor() -> float:
	return (.2+.8*smoothstep(0.0,float(rules.hunger_optimal),hunger))*(1.0-minf(.35,illness*.12))

func can_eat(effect: Dictionary) -> bool:
	return (hunger<100.0 and float(effect.get("hunger",0))>0) or (health<100.0 and float(effect.get("health",0))>0) or (illness>0 and float(effect.get("treatment",0))>0)

func eat(effect: Dictionary) -> void:
	discomfort=maxf(discomfort,float(effect.get("discomfort",0)))
	# Refresh one timer, never stack the damage rate.
	if effect.get("hallucination",false): hallucination_remaining=float(rules.hallucination_minutes)
	hunger=clampf(hunger+float(effect.get("hunger",0)),0,100)
	health=clampf(health+float(effect.get("health",0)),0,100)
	illness=maxf(0.0,illness-float(effect.get("treatment",0)))
	if hunger>=float(rules.hunger_low): damage_clock=0.0
	changed.emit()

func status() -> String:
	if sleeping: return "强制睡眠" if sleep_forced else "睡眠中"
	if down: return "严重虚弱 · 正在休养"
	if hallucination_remaining>0.0: return "致幻中"
	if illness>=float(rules.illness_threshold): return "生病中" if hunger<float(rules.hunger_recovery) else "生病中 · 正在恢复"
	if illness>0: return "身体不适" if hunger<float(rules.hunger_recovery) else "身体不适 · 正在改善"
	if deprivation>=.25: return "营养不足"
	if hunger<=float(rules.hunger_severe): return "严重饥饿"
	if hunger<float(rules.hunger_obvious): return "明显饥饿"
	if hunger<float(rules.hunger_warning): return "有些饥饿"
	if energy<float(rules.energy_drowsy): return energy_status()
	if exhausted or stamina<25: return "体力不足"
	return "健康"

func advice() -> String:
	if hallucination_remaining>0.0: return "生蘑菇致幻期间生命逐渐下降；熟食安全，但不会解除已经发生的致幻。"
	if sleeping: return "正在睡眠，时间与营地燃料会同步推进。"
	if energy<float(rules.energy_drowsy): return "需要睡眠补充精力；进食和站立休息无法替代睡眠。"
	if down: return "安心休养，稍后会逐渐恢复行动。物品与装备都在。"
	if hunger<float(rules.hunger_recovery) or deprivation>=.25: return "补充食物并保持正常饮食，营养改善会先停止疾病恶化。"
	if illness>0: return "身体正在改善，继续保持正常饮食与适当休息。"
	if stamina<40: return "停止奔跑与劳动片刻，有助于恢复体力。"
	return "身体状态良好，无需特别照料。"

func body_description() -> String:
	var shape := "偏瘦" if build<-.18 else "偏胖" if build>.18 else "正常"
	var trend := "逐渐消瘦" if reserve<build-.04 else "逐渐圆润" if reserve>build+.04 else "体型稳定"
	return shape+" · "+trend

func serialize() -> Dictionary:
	return {"hallucination_remaining":hallucination_remaining,"version":2,"sleep_session":sleep_session.duplicate(true),"energy":energy,"sleeping":sleeping,"sleep_forced":sleep_forced,"sleep_elapsed":sleep_elapsed,"sleep_duration":sleep_duration,"health":health,"hunger":hunger,"stamina":stamina,"deprivation":deprivation,"illness":illness,"reserve":reserve,"build":build,"damage_clock":damage_clock,"rest_clock":rest_clock,"rescue_clock":rescue_clock,"exhausted":exhausted,"down":down}

func restore(value: Variant) -> bool:
	if not value is Dictionary: return false
	var raw_version = value.get("version")
	if not (raw_version is int or raw_version is float) or not is_finite(float(raw_version)) or raw_version!=floor(raw_version): return false
	var version := int(raw_version)
	if version not in [1,2]: return false
	if not preload("res://scripts/sleep_controller.gd").valid_session(value.get("sleep_session",{}),value): return false
	var raw_hallucination = value.get("hallucination_remaining",0.0)
	if not (raw_hallucination is int or raw_hallucination is float) or not is_finite(float(raw_hallucination)) or raw_hallucination<0 or raw_hallucination>float(rules.hallucination_minutes): return false
	var ranges := {"health":[0,100],"hunger":[0,100],"stamina":[0,100],"deprivation":[0,4],"illness":[0,3],"reserve":[-1,1],"build":[-1,1],"damage_clock":[0,rules.disease_damage_interval_minutes],"rest_clock":[0,1000000],"rescue_clock":[0,1000000]}
	if version==2:
		ranges.merge({"energy":[0,100],"sleep_elapsed":[0,1440],"sleep_duration":[0,float(rules.sleep_max_minutes)]})
		for key in ["sleeping","sleep_forced"]:
			if not value.get(key) is bool: return false
	for key in ranges:
		var number = value.get(key)
		if not (number is float or number is int) or not is_finite(float(number)) or float(number)<float(ranges[key][0]) or float(number)>float(ranges[key][1]): return false
	if version==2 and value.sleeping:
		if value.sleep_duration<=0 or value.sleep_elapsed>=value.sleep_duration: return false
	for key in ["down","exhausted"]:
		if not value.get(key) is bool: return false
	for key in ranges: set(key,float(value[key]))
	hallucination_remaining=float(raw_hallucination)
	energy=float(value.get("energy",100.0))
	sleeping=bool(value.get("sleeping",false));sleep_forced=bool(value.get("sleep_forced",false))
	sleep_elapsed=float(value.get("sleep_elapsed",0));sleep_duration=float(value.get("sleep_duration",0))
	sleep_session=value.get("sleep_session",{}).duplicate(true)
	down=bool(value.down) or health<=float(rules.down_health)
	exhausted=bool(value.exhausted) or stamina<=0
	return true


func efficiency() -> float:
	if energy<float(rules.energy_severe): return float(rules.severe_efficiency)
	if energy<float(rules.energy_tired): return float(rules.tired_efficiency)
	return 1.0

func energy_status() -> String:
	if sleeping: return "强制睡眠" if sleep_forced else "睡眠中"
	if energy<=0: return "精力耗尽 · 即将睡眠"
	if energy<float(rules.energy_severe): return "极度疲惫"
	if energy<float(rules.energy_tired): return "疲惫"
	if energy<float(rules.energy_drowsy): return "开始困倦"
	return "精力充足"

func start_sleep(minute: float, forced: bool=false) -> bool:
	if sleep_active() or (not forced and (down or energy>=float(rules.sleep_need_energy))): return false
	sleep_forced=forced;sleep_elapsed=0.0
	sleep_duration=float(rules.sleep_min_minutes)
	if not forced:
		if minute>=float(rules.sleep_night_minute) or minute<float(rules.sleep_morning_minute):
			sleep_duration=clampf(fposmod(float(rules.sleep_morning_minute)-minute,1440.0),float(rules.sleep_min_minutes),float(rules.sleep_max_minutes))
		else: sleep_duration=float(rules.sleep_nap_minutes)
	sleeping=true
	changed.emit()
	return true
