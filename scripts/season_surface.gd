extends RefCounted
## Saved surface state belongs to the authoritative environment atomic snapshot.
const Rules=preload("res://scripts/season_rules.gd")
static func valid(value: Variant) -> bool:
	if not value is Dictionary:return false
	if value.is_empty():return true
	if value.get("version")!=1 or not value.get("buildings") is Dictionary:return false
	var values: Array=[value.get("snow")]
	for row in value.buildings.values():
		if not row is Dictionary or not row.get("blocked") is bool:return false
		values.append(row.get("amount"))
	for number in values:
		if not (number is float or number is int) or not is_finite(float(number)) or number<0 or number>1:return false
	return true

static func heat_sources(service: Node) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	var sources: Dictionary=preload("res://scripts/weather_body_rules.gd").data.heat_sources
	var f: Dictionary=Rules.data.features
	for row in service.camps.states.values()+service.builds.states.values():
		var kind: String=str(row.get("kind","simple_campfire"))
		var radius:=float(sources.get(kind,0))
		var ratio:=float(row.get("fuel",0))/float(service.camps.rules.max_fuel)
		if radius>0 and row.get("lit",false) and ratio>=float(f.snow_heat_min_fuel_ratio):
			result.append(Vector3(float(row.x),float(row.y),radius))
	return result

static func heat(service: Node, point: Vector2) -> float:
	var result:=0.0
	for source in heat_sources(service):
		result=maxf(result,clampf(1.0-point.distance_to(Vector2(source.x,source.y))/source.z,0,1))
	return result

static func advance(service: Node, minutes: float) -> void:
	var sim=service.world.environment_view.simulation
	var f: Dictionary=Rules.data.features
	var winter: bool=sim.season_date().index==3
	for id in sim.building_snow.keys():
		if not service.builds.states.has(id):sim.building_snow.erase(id)
	for id in service.builds.states:
		var row: Dictionary=service.builds.states[id]
		var rule: Dictionary=f.buildings.get(row.kind,{})
		if rule.is_empty() or not rule.get("allowed",false):
			sim.building_snow.erase(id)
			continue
		var state: Dictionary=sim.building_snow.get(id,{"amount":0.0,"blocked":false})
		var warmth:=heat(service,Vector2(row.x,row.y))
		var gain:=maxf(float(f.winter_snow_minimum),sim.blend.y+sim.blend.z)*float(f.snow_gain_per_minute)*float(rule.gain) if winter else -float(f.snow_melt_per_minute)
		state.amount=clampf(float(state.amount)+minutes*(gain-warmth*float(f.heat_melt_per_minute)*float(rule.melt)),0,1)
		if state.amount>=float(f.blocking_on):state.blocked=bool(rule.blocks)
		elif state.amount<=float(f.blocking_off):state.blocked=false
		sim.building_snow[id]=state

static func blocked(service: Node, id: String) -> bool:
	var row: Dictionary=service.builds.states.get(id,{})
	if not Rules.data.features.buildings.get(row.get("kind",""),{}).get("allowed",false):return false
	return bool(service.world.environment_view.simulation.building_snow.get(id,{}).get("blocked",false))
