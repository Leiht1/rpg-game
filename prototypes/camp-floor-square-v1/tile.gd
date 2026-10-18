extends "res://scripts/camp_building.gd"
# Candidate-only renderer. Never referenced by the formal building installer.
func candidate_texture(path: String) -> Texture2D:
	if not manager.textures.has(path): manager.textures[path]=ImageTexture.create_from_image(Image.load_from_file(path))
	return manager.textures[path]
func _draw() -> void:
	if not manager.states.has(building_id): return
	var row: Dictionary=manager.states[building_id]
	if row.layer!="ground": super._draw();return
	var material := "wood" if row.kind=="wood_floor" else "stone"
	var base := "res://prototypes/camp-floor-square-v1/final/"+material
	var top := candidate_texture(base+"-top.png")
	var front := candidate_texture(base+"-front.png")
	draw_texture_rect(top,Rect2(-48,-32,96,64),false)
	var south_filled := false
	for other in manager.states.values():
		if other.layer=="ground" and is_equal_approx(float(other.x),float(row.x)) and is_equal_approx(float(other.y),float(row.y)+64): south_filled=true;break
	# Real thin material edge on exposed south perimeter only, never a filled underlay.
	if not south_filled: draw_texture_rect(front,Rect2(-48,32,96,21.0*96/636),false)
