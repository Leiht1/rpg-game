extends "res://prototypes/camp-floor-square-v1/tile.gd"
# Only the surface artwork changes. Geometry and the original front lip are locked.
func candidate_texture(path: String) -> Texture2D:
	return super.candidate_texture(path.replace("camp-floor-square-v1/final/","camp-floor-seams-v2/final/"))
