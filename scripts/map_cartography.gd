extends RefCounted
## Procedural cartographic colour from the live terrain; no generated image assets.
static func color_at(gen: WildGenerator, p: Vector2, detailed: bool) -> Color:
	if not detailed:return gen.overview_color(p)
	var water: float=gen.sample(p).z
	var coast: float=gen.coast_distance(p)
	var weights: Color=gen.ecology_weights(p)
	var cloud: float=gen.moisture.get_noise_2dv(p)*.035+gen.elevation.get_noise_2dv(p)*.022
	var land: Color=Color('75966e')*weights.r+Color('b5aa8e')*weights.g+Color('acc68d')*weights.b+Color('a1a59b')*weights.a
	land+=Color(cloud,cloud,cloud*.7,0)
	if water<.025:return land
	var depth: float=smoothstep(0.,1.,water)
	var sea: Color=Color('83b4b5').lerp(Color('568c9a'),(1.0-smoothstep(-2200.,-650.,coast))) if coast<0 else Color('82b4b6').lerp(Color('649ba8'),depth)
	sea+=Color(cloud*.35,cloud*.5,cloud*.5,0)
	return land.lerp(sea,smoothstep(.02,.85,water))
