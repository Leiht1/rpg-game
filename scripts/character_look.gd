extends RefCounted
## Runs AFTER native animation texture tracks and BEFORE held-tool copies.
const Catalog=preload("res://scripts/character_catalog.gd")
const ROOT="res://prototypes/character-creation-v1/"
const PARTS={"torso":"Visual/Pelvis/Torso","arm_l":"Visual/ArmLBehind","arm_r":"Visual/Pelvis/ArmR/Sprite","leg_l":"Visual/LegL/Sprite","leg_r":"Visual/LegR/Sprite","head":"Visual/Pelvis/Head/Sprite"}
var textures: Dictionary={}
var materials: Dictionary={}
func tex(path: String) -> Texture2D:
	if not textures.has(path): textures[path]=ImageTexture.create_from_image(Image.load_from_file(path if path.begins_with("res://") else ROOT+path))
	return textures[path]
func apply(rig: Node2D, look: Dictionary, inventory: ItemInventory, facing: String) -> void:
	if look.is_empty(): return
	var rules=Catalog.rules()
	var view: String="side" if facing in ["left","right"] else facing
	var outfit_id: String=inventory.equipment.get("outfit",{}).get("item_id","") if inventory!=null else ""
	var outfit: Dictionary=rules.outfits.get(outfit_id,{})
	var modern: bool=not outfit.is_empty()
	var heads: Dictionary=rules.get("gender_heads",{}).get(look.gender,rules.get("heads",{}))
	for part in PARTS:
		var sprite: Sprite2D=rig.get_node(PARTS[part])
		if part=="head": sprite.texture=tex(heads.get(view,"heads/"+view+".png"))
		elif modern: sprite.texture=tex(outfit.parts[view][part])
		if part=="torso" and not modern: sprite.material=null;continue
		if not materials.has(part):
			var material_value=ShaderMaterial.new();material_value.shader=preload("res://scripts/character_skin.gdshader");materials[part]=material_value
		var mat: ShaderMaterial=materials[part]
		mat.set_shader_parameter("blue_outfit",outfit_id=="modern_outfit" and part in ["torso","arm_l","arm_r"])
		mat.set_shader_parameter("skin_color",Color(rules.skin[look.skin_id].color))
		var skin_region: Array=outfit.get("skin_regions",{}).get(part,[0,1]) if modern else [0,1]
		mat.set_shader_parameter("skin_enabled",not modern or part=="head" or outfit.skin_regions.has(part))
		mat.set_shader_parameter("skin_region",Vector2(skin_region[0],skin_region[1]))
		sprite.material=mat
	var head: Sprite2D=rig.get_node(PARTS.head)
	var eye: Array=rules.get("sleep_side_eye_center",[.79,.57])
	rig.get_node("Visual/Pelvis/Head").set_meta("sleep_eye_center",Vector2(eye[0],eye[1]))
	var hair: Dictionary=rules.hair[look.hair_id][view]
	for layer in ["rear","front"]:
		var node: Sprite2D=rig.get_node_or_null("Visual/Pelvis/Head/Sprite/CharacterHair"+layer)
		if node==null:
			node=Sprite2D.new();node.name="CharacterHair"+layer;head.add_child(node)
		# Back layer is under face; front layer is over scalp. The entire subtree
		# follows the SAME original head transform, including body width changes.
		node.show_behind_parent=layer=="rear"
		var path: String=hair.get(layer,"")
		node.visible=not path.is_empty()
		node.texture=tex(path) if not path.is_empty() else null;node.position=Vector2.ZERO
		node.material=null
	rig.set_meta("character_look",look.duplicate())
