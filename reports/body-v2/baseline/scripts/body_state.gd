extends RefCounted
## Shared state; receives only elapsed gameplay time, never clock jumps or wall time.
signal changed
const RULES = preload("res://scripts/body_rules.gd")
var rules: Dictionary = RULES.load_rules()
var health := 100.0
var hunger := 100.0
var stamina := 100.0
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

func can_labor(action: String) -> bool:
	return not down and not exhausted and stamina >= float(rules.labor_cost.get(action,0.0))

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
	var days := minutes/1440.0
	hunger=maxf(0.0,hunger-days*float(rules.hunger_per_day))
	var shortage := 1.0-smoothstep(float(rules.hunger_severe),float(rules.hunger_low),hunger)
	deprivation=clampf(deprivation+days*(shortage if hunger<float(rules.hunger_low) else -float(rules.nutrition_recovery_per_day)),0.0,4.0)
	if hunger>=float(rules.hunger_recovery): illness=maxf(0.0,illness-days*float(rules.illness_recovery_per_day))
	elif hunger<float(rules.hunger_low) and deprivation>=float(rules.malnutrition_days): illness=minf(3.0,illness+days*float(rules.illness_threshold)/maxf(.1,float(rules.illness_days)-float(rules.malnutrition_days)))
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
		if hunger>=float(rules.hunger_recovery) and not busy: health=minf(100.0,health+minutes/float(rules.health_recovery_game_minutes))
	# Energy reserve integrates diet and activity over days, then body follows slowly.
	var energy := (hunger-float(rules.reserve_balance_hunger))/(100.0-float(rules.reserve_balance_hunger))-(float(rules.reserve_activity_cost) if sprinting or working else 0.0)
	reserve=clampf(reserve+(energy-reserve)*days/float(rules.reserve_response_days),-1.0,1.0)
	build=move_toward(build,reserve,days/float(rules.body_response_days))

func recovery_factor() -> float:
	return (.2+.8*smoothstep(0.0,float(rules.hunger_optimal),hunger))*(1.0-minf(.35,illness*.12))

func can_eat(effect: Dictionary) -> bool:
	return (hunger<100.0 and float(effect.get("hunger",0))>0) or (health<100.0 and float(effect.get("health",0))>0) or (illness>0 and float(effect.get("treatment",0))>0)

func eat(effect: Dictionary) -> void:
	hunger=clampf(hunger+float(effect.get("hunger",0)),0,100)
	health=clampf(health+float(effect.get("health",0)),0,100)
	illness=maxf(0.0,illness-float(effect.get("treatment",0)))
	if hunger>=float(rules.hunger_low): damage_clock=0.0
	changed.emit()

func status() -> String:
	if down: return "严重虚弱 · 正在休养"
	if illness>=float(rules.illness_threshold): return "生病中" if hunger<float(rules.hunger_recovery) else "生病中 · 正在恢复"
	if illness>0: return "身体不适" if hunger<float(rules.hunger_recovery) else "身体不适 · 正在改善"
	if deprivation>=.25: return "营养不足"
	if exhausted or stamina<25: return "有些疲惫"
	return "健康"

func advice() -> String:
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
	return {"version":1,"health":health,"hunger":hunger,"stamina":stamina,"deprivation":deprivation,"illness":illness,"reserve":reserve,"build":build,"damage_clock":damage_clock,"rest_clock":rest_clock,"rescue_clock":rescue_clock,"exhausted":exhausted,"down":down}

func restore(value: Variant) -> bool:
	if not value is Dictionary or int(value.get("version",0))!=1: return false
	var ranges := {"health":[0,100],"hunger":[0,100],"stamina":[0,100],"deprivation":[0,4],"illness":[0,3],"reserve":[-1,1],"build":[-1,1],"damage_clock":[0,rules.disease_damage_interval_minutes],"rest_clock":[0,1000000],"rescue_clock":[0,1000000]}
	for key in ranges:
		var number = value.get(key)
		if not (number is float or number is int) or not is_finite(float(number)) or float(number)<float(ranges[key][0]) or float(number)>float(ranges[key][1]): return false
	for key in ["down","exhausted"]:
		if not value.get(key) is bool: return false
	for key in ranges: set(key,float(value[key]))
	down=bool(value.down) or health<=float(rules.down_health)
	exhausted=bool(value.exhausted) or stamina<=0
	return true

