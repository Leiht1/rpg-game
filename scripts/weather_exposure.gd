extends RefCounted
## Derived from authoritative world state; never from rain particles or lamp light.
const CONFIG = preload("res://scripts/weather_body_rules.gd")
static func covered(service: Node, point: Vector2) -> bool:
	if preload("res://scripts/mine_rules.gd").pocket(point,service.world.generator.extent):return true
	for row in service.builds.states.values():
		var definition: Dictionary=service.builds.definitions.get(row.kind,{})
		if not definition.get("rain_cover",false): continue
		var r: Array=cover_rect(row) if row.kind=="rain_shelter" else definition.get("rain_cover_rect",CONFIG.data.shelter_rect)
		if Rect2(Vector2(row.x+r[0],row.y+r[1]),Vector2(r[2],r[3])).has_point(point): return true
	return false

static func sleep_point(row: Dictionary) -> Vector2:
	# The occupied body/bed centre, not a canopy-image intersection or head sprite bounds.
	return Vector2(row.x,row.y)+Vector2(0,1) # sleep_controller.render's actual root position

static func sample(service: Node) -> Dictionary:
	var sim=service.world.environment_view.simulation
	var p: Vector2=service.world.player.position
	if service.body.sleeping and not service.body.sleep_session.is_empty() and service.body.sleep_session.source!="forced":
		p=sleep_point(service.body.sleep_session)
	var heat := 0.0
	for id in service.camps.states:
		var row: Dictionary=service.camps.states[id]
		if row.get("lit",false) and float(row.get("fuel",0))>0:
			heat=maxf(heat,clampf(1.0-p.distance_to(Vector2(row.x,row.y))/float(CONFIG.data.heat_sources.simple_campfire),0,1))
	for row in service.builds.states.values():
		var radius: float=float(CONFIG.data.heat_sources.get(row.kind,0))
		if radius>0 and row.get("lit",false) and float(row.get("fuel",0))>0:
			heat=maxf(heat,clampf(1.0-p.distance_to(Vector2(row.x,row.y))/radius,0,1))
	var warmth := 0.0
	var rain_remaining := 1.0
	var sun_shade := 0.0
	for instance in service.inventory.equipment.values():
		if instance.is_empty():continue
		var stats: Dictionary=service.database.item(str(instance.item_id)).get("stats",{})
		warmth+=float(stats.get("warmth",0))
		rain_remaining*=1.0-clampf(float(stats.get("rain_resistance",0)),0,1)
		sun_shade+=maxf(0,float(stats.get("sun_shade",0)))
	warmth+=float(CONFIG.data.base_clothing_warmth)
	var umbrella: bool=service.inventory.equipment.get("main_hand",{}).get("item_id","")=="rain_umbrella" and not service.body.sleeping
	var hour: float=sim.minute/60.0
	var night: float=1.0-sim.daylight()
	var rain: float=clampf(sim.blend.y+sim.blend.z,0,1)
	return {"rain":rain,"rain_resistance":1.0-rain_remaining,"sun_shade":sun_shade*(1.0-night)*clampf(sim.blend.x,0,1),"storm":sim.blend.y,"night":night,"warmth":warmth,"heat":heat,"umbrella":umbrella,"shelter":covered(service,p),"weather":sim.weather_name(),"ambient":float(CONFIG.data.base_celsius)+sim.season_temperature()-night*float(CONFIG.data.night_drop)-rain*float(CONFIG.data.rain_drop)-sim.blend.y*float(CONFIG.data.storm_drop)}

static func pole_blocks(row: Dictionary, a: Vector2, b: Vector2, radius: float) -> bool:
	for post in posts(row):
		var p := Vector2(row.x+post[0],row.y+post[1])
		if Geometry2D.get_closest_point_to_segment(p,a,b).distance_to(p)<radius+float(CONFIG.data.post_radius):return true
	return false

static func soil_under_pole(soil: Dictionary, shelter: Dictionary) -> bool:
	var bounds := Rect2(Vector2(soil.x-48,soil.y-32),Vector2(96,64))
	for post in posts(shelter):
		var p := Vector2(shelter.x+post[0],shelter.y+post[1])
		var nearest: Vector2=p.clamp(bounds.position,bounds.end)
		if p.distance_to(nearest)<=float(CONFIG.data.post_radius):return true
	return false

static func posts(row: Dictionary) -> Array:
	return CONFIG.data.get("shelter_vertical_posts",CONFIG.data.shelter_posts) if row.get("vertical",false) else CONFIG.data.shelter_posts

static func cover_rect(row: Dictionary) -> Array:
	return CONFIG.data.shelter_vertical_rect if row.get("vertical",false) else CONFIG.data.shelter_rect
