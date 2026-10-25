extends Node
## Independent, versioned simulation. No wall-clock catch-up or gameplay dependencies.
signal state_changed
signal weather_target_changed(weather: int)
# Keep rain's persisted ID; ID 1 belonged to retired overcast in save v1.
enum Weather { CLEAR = 0, RAIN = 2, THUNDERSTORM = 3 }
@export var day_length_minutes: float = 60.0
@export var time_scale: float = 1.0
@export var paused: bool = false
@export var weather_duration_min: float = 240.0
@export var weather_duration_max: float = 600.0
@export var transition_seconds: float = 25.0
@export var weather_weights := Vector3(5.0, 2.0, 1.0)
const Seasons = preload("res://scripts/season_rules.gd")
var snow := 0.0
var building_snow: Dictionary={}
var season_origin_day: int = 1
var day: int = 1
var minute: float = 480.0
var current_weather: int = Weather.CLEAR
var target_weather: int = Weather.CLEAR
var weather_remaining: float = 420.0
var transition_elapsed: float = 0.0
var blend := Vector3(1, 0, 0)
var transition_from := Vector3(1, 0, 0)
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.seed = 78041

func advance(delta: float) -> void:
	if paused or delta <= 0.0: return
	var dt := delta * maxf(time_scale, 0.0)
	# Consume boundaries so large simulation steps and normal frame steps agree.
	while dt > 0.000001:
		var destination := weather_blend(target_weather)
		if transition_elapsed < transition_seconds and transition_from.distance_to(destination) > 0.000001:
			var step := minf(dt, maxf(transition_seconds - transition_elapsed, 0.000001))
			advance_calendar(step)
			transition_elapsed += step
			dt -= step
			var t := clampf(transition_elapsed / maxf(transition_seconds, 0.001), 0.0, 1.0)
			blend = transition_from.lerp(destination, smoothstep(0.0, 1.0, t))
			if t >= 1.0:
				current_weather = target_weather
				weather_remaining = rng.randf_range(weather_duration_min, maxf(weather_duration_min, weather_duration_max))
		else:
			var step := minf(dt, maxf(weather_remaining, 0.000001))
			advance_calendar(step)
			weather_remaining -= step
			dt -= step
			if weather_remaining <= 0.000001: request_weather(_choose_next())
	state_changed.emit()

func advance_calendar(seconds: float) -> void:
	var remaining := seconds*1440.0/maxf(day_length_minutes*60.0,1.0)
	var f: Dictionary=Seasons.data.features
	while remaining>0.0000001:
		var date: Dictionary=season_date()
		var until_boundary: float=(float(Seasons.data.seasons[date.index].days)-float(date.progress))*1440.0
		var minutes := minf(remaining,maxf(.0000001,until_boundary))
		var wet := maxf(float(f.winter_snow_minimum),blend.y+blend.z) if date.index==3 else 0.0
		snow=clampf(snow+minutes*(wet*float(f.snow_gain_per_minute) if wet>0 else -float(f.snow_melt_per_minute)),0,1)
		var total := minute+minutes
		day+=int(floor(total/1440.0))
		minute=fposmod(total,1440.0)
		remaining-=minutes

func season_elapsed_days() -> float:
	return maxf(0,float(day-season_origin_day)+minute/1440.0)

func season_date() -> Dictionary:
	return Seasons.date(season_elapsed_days())

func season_temperature() -> float:
	return Seasons.temperature(season_elapsed_days())

func _choose_next() -> int:
	var seasonal: Array=Seasons.data.seasons[season_date().index].weather_weights
	var reference: Array=Seasons.data.weather_reference_weights
	var weights := Vector3(float(seasonal[0]),float(seasonal[1]),float(seasonal[2]))*weather_weights/Vector3(float(reference[0]),float(reference[1]),float(reference[2]))
	var clear_weight := maxf(0.0, weights.x)
	var rain_weight := maxf(0.0, weights.y)
	var total := maxf(.001, clear_weight + rain_weight + maxf(0.0, weights.z))
	var roll := rng.randf() * total
	if roll < clear_weight: return Weather.CLEAR
	return Weather.RAIN if roll < clear_weight + rain_weight else Weather.THUNDERSTORM

func weather_slot(weather: int) -> int:
	return 1 if weather == Weather.THUNDERSTORM else (2 if weather == Weather.RAIN else 0)

func weather_blend(weather: int) -> Vector3:
	var result := Vector3.ZERO
	result[weather_slot(weather)] = 1.0
	return result

func force_weather(weather: int) -> void:
	request_weather(weather)

func request_weather(weather: int) -> void:
	if weather not in [Weather.CLEAR, Weather.RAIN, Weather.THUNDERSTORM]: weather = Weather.CLEAR
	transition_from = blend
	target_weather = weather
	transition_elapsed = 0.0
	if absf(blend[weather_slot(weather)] - 1.0) < 0.000001:
		current_weather = weather
		weather_remaining = rng.randf_range(weather_duration_min, maxf(weather_duration_min, weather_duration_max))
	weather_target_changed.emit(weather)

func set_time(hour: float) -> void:
	minute = fposmod(hour * 60.0, 1440.0)
	state_changed.emit()

func light_hours() -> Array:
	var date: Dictionary=season_date()
	var current: Array=Seasons.data.seasons[date.index].light_hours
	var previous: Array=Seasons.data.seasons[posmod(int(date.index)-1,4)].light_hours
	var fraction := smoothstep(0,float(Seasons.data.transition_days),float(date.progress))
	var result: Array=[]
	for i in 4:result.append(lerpf(float(previous[i]),float(current[i]),fraction) if season_elapsed_days()>=float(Seasons.data.transition_days) else float(current[i]))
	return result

func daylight() -> float:
	var h := light_hours()
	return smoothstep(h[0],h[1],minute/60.0)*(1.0-smoothstep(h[2],h[3],minute/60.0))

func lakes_frozen() -> bool:
	return season_date().index==3 and float(season_date().progress)>=float(Seasons.data.features.freeze_day)

func phase() -> String:
	var h := light_hours()
	var hour := minute/60.0
	if hour>=h[0] and hour<h[1]:return "清晨"
	if hour>=h[1] and hour<h[2]:return "白天"
	if hour>=h[2] and hour<h[3]:return "黄昏"
	return "夜晚"

func clock_text() -> String:
	return "%02d:%02d" % [int(minute) / 60, int(minute) % 60]

func weather_name(value: int = -1) -> String:
	match target_weather if value < 0 else value:
		Weather.RAIN: return "小雨"
		Weather.THUNDERSTORM: return "雷暴雨"
	return "晴朗"

func light_parameters() -> Dictionary:
	var h := light_hours()
	var hours := [0.0, h[0], (h[0]+h[1])*.5, h[1], h[2], (h[2]+h[3])*.5, h[3], 24.0]
	var colors := [Color(.70,.76,.89), Color(.70,.76,.89), Color(.96,.89,.82), Color.WHITE, Color.WHITE, Color(1.02,.88,.74), Color(.70,.76,.89), Color(.70,.76,.89)]
	var hour := minute / 60.0
	var tint := Color.WHITE
	for i in range(hours.size()-1):
		if hour >= hours[i] and hour <= hours[i+1]:
			tint = colors[i].lerp(colors[i+1], smoothstep(hours[i], hours[i+1], hour))
			break
	tint=tint.lerp(Color(Seasons.data.seasons[season_date().index].color),float(Seasons.data.features.tint_strength))
	return {"tint": tint, "brightness": (1.0 - blend.z*.125 - blend.y*.25)*lerpf(.22,1.0,daylight()), "saturation": 1.0 - blend.z*.15 - blend.y*.20, "contrast": 1.0 - blend.z*.06 - blend.y*.07, "rain": blend.z + blend.y, "storm": blend.y}

func serialize() -> Dictionary:
	return {"season_surface":{"version":1,"snow":snow,"buildings":building_snow.duplicate(true)},"season":{"version":1,"origin_day":season_origin_day},"version":3,"day":day,"minute":minute,"day_length_minutes":day_length_minutes,"time_scale":time_scale,"paused":paused,"current_weather":current_weather,"target_weather":target_weather,"weather_remaining":weather_remaining,"transition_elapsed":transition_elapsed,"blend":[blend.x,blend.y,blend.z],"transition_from":[transition_from.x,transition_from.y,transition_from.z],"rng_state":str(rng.state),"duration_min":weather_duration_min,"duration_max":weather_duration_max,"transition_seconds":transition_seconds,"weights":[weather_weights.x,weather_weights.y,weather_weights.z]}

func restore(data: Dictionary) -> bool:
	var version := int(data.get("version",0))
	if version not in [1,2,3]: return false
	for key in ["blend", "transition_from"]:
		if not data.get(key) is Array or data[key].size() != 3: return false
	if not data.get("weights") is Array or data.weights.size() != (2 if version == 2 else 3): return false
	if data.has("season") and not Seasons.valid(data.season,maxi(1,int(data.get("day",1)))):return false
	if not preload("res://scripts/season_surface.gd").valid(data.get("season_surface",{})):return false
	snow=float(data.get("season_surface",{}).get("snow",0))
	building_snow=data.get("season_surface",{}).get("buildings",{}).duplicate(true)
	day = maxi(1, int(data.get("day",1)))
	season_origin_day=int(data.season.origin_day) if data.has("season") else day
	minute = fposmod(float(data.get("minute",480)),1440.0)
	day_length_minutes = maxf(.1,float(data.get("day_length_minutes",60)))
	time_scale = clampf(float(data.get("time_scale",1)),0,10000)
	paused = bool(data.get("paused",false))
	current_weather = Weather.RAIN if int(data.get("current_weather",0)) == 2 else Weather.CLEAR
	target_weather = Weather.RAIN if int(data.get("target_weather",0)) == 2 else Weather.CLEAR
	if version == 3:
		if int(data.get("current_weather",0)) == 3: current_weather = Weather.THUNDERSTORM
		if int(data.get("target_weather",0)) == 3: target_weather = Weather.THUNDERSTORM
	weather_remaining = maxf(.01,float(data.get("weather_remaining",420)))
	weather_duration_min = maxf(1,float(data.get("duration_min",240)))
	weather_duration_max = maxf(weather_duration_min,float(data.get("duration_max",600)))
	transition_seconds = maxf(.1,float(data.get("transition_seconds",25)))
	transition_elapsed = clampf(float(data.get("transition_elapsed",0)),0,transition_seconds)
	blend = Vector3(float(data.blend[0]),float(data.blend[1]),float(data.blend[2]))
	transition_from = Vector3(float(data.transition_from[0]),float(data.transition_from[1]),float(data.transition_from[2]))
	weather_weights = Vector3(float(data.weights[0]),float(data.weights[2 if version == 1 else 1]),float(data.weights[2]) if version == 3 else 1.0)
	if version == 1:
		# Retired cloud contribution becomes dry sky; retain the visible rain amount.
		blend = Vector3(1.0 - blend.z, 0.0, blend.z)
		transition_from = blend
		transition_elapsed = 0.0
		if int(data.get("queued_weather",-1)) == 2: target_weather = Weather.RAIN
	rng.state = int(data.get("rng_state","78041"))
	state_changed.emit()
	return true

