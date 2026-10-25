extends RefCounted
## All dates are derived from the saved authoritative game calendar.
static var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/season_rules.json"))

static func valid(value: Variant, world_day: int) -> bool:
	if not value is Dictionary or value.get("version")!=1:return false
	var origin = value.get("origin_day")
	return (origin is int or origin is float) and is_finite(float(origin)) and origin==floor(origin) and origin>=1 and origin<=world_day

static func date(elapsed_days: float) -> Dictionary:
	var total := 0.0
	for row in data.seasons:total+=float(row.days)
	var position := fposmod(maxf(0,elapsed_days),total)
	for i in data.seasons.size():
		var row: Dictionary=data.seasons[i]
		if position<float(row.days):return {"index":i,"day":int(floor(position))+1,"progress":position,"cycle":int(floor(maxf(0,elapsed_days)/total))+1}
		position-=float(row.days)
	return {}

static func temperature(elapsed_days: float) -> float:
	var current := date(elapsed_days)
	var row: Dictionary=data.seasons[current.index]
	var target := lerpf(float(row.temperature_start),float(row.temperature_end),float(current.progress)/float(row.days))
	if elapsed_days<float(data.transition_days):return target
	var previous: Dictionary=data.seasons[posmod(int(current.index)-1,data.seasons.size())]
	return lerpf(float(previous.temperature_end),target,smoothstep(0,float(data.transition_days),float(current.progress)))

static func growth(crop: String, elapsed_days: float, minutes: float) -> float:
	# Integrate the actual interval, splitting at season boundaries. No crop timestamps.
	var cursor := maxf(0,elapsed_days-minutes/1440.0)
	var remaining := minutes/1440.0
	var result := 0.0
	while remaining>0.000000001:
		var current := date(cursor)
		var row: Dictionary=data.seasons[current.index]
		var step := minf(remaining,float(row.days)-float(current.progress))
		result+=step*1440.0*float(row.growth.get(crop,1.0))
		remaining-=step
		cursor+=step+0.00000000001
	return result
