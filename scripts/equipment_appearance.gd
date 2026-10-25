extends RefCounted
## Native rig parts, sampled after animation and hair, before held-tool copies.
var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment_visuals.json"))
var signature := ""
var textures: Dictionary={}
var clipped_hair: Array=[]
var clothing_arm: Sprite2D
var clothing_source: Sprite2D
var clothing_source_visible := true

func release_layers() -> void:
	if is_instance_valid(clothing_source): clothing_source.visible=clothing_source_visible
	if is_instance_valid(clothing_arm): clothing_arm.hide()
	clothing_source=null

func apply_layers(character: Node2D, inventory: ItemInventory, facing: String) -> void:
	if inventory==null or facing!="front":return
	var item: Dictionary=inventory.database.item(str(inventory.equipment.get("outfit",{}).get("item_id","")))
	if not registry.get(item.get("visual_id",""),{}).get("foreground_arms",false):return
	var pelvis: Node2D=character.get_node("Visual/Pelvis")
	var right: Node2D=pelvis.get_node("ArmR")
	right.show_behind_parent=false
	# Existing tool poses already expose the empty arm; keep exactly one visible copy.
	var tool_arm: Sprite2D=pelvis.get_node_or_null("FrontFreeArm")
	if tool_arm!=null and tool_arm.visible:return
	var source: Sprite2D=character.get_node("Visual/ArmLBehind")
	if not is_instance_valid(clothing_arm):
		clothing_arm=Sprite2D.new();clothing_arm.name="ClothingFrontArm";pelvis.add_child(clothing_arm)
	clothing_arm.texture=source.texture;clothing_arm.material=source.material
	clothing_arm.centered=source.centered;clothing_arm.offset=source.offset
	clothing_arm.flip_h=source.flip_h;clothing_arm.flip_v=source.flip_v
	clothing_arm.modulate=source.modulate;clothing_arm.texture_filter=source.texture_filter
	clothing_arm.global_transform=pelvis.get_node("ArmL/RearVisualDrive").global_transform
	pelvis.move_child(clothing_arm,right.get_index());clothing_arm.show()
	clothing_source=source;clothing_source_visible=source.visible;source.hide()

func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path]=load(path)
	return textures[path]

func fit_hat(head: Sprite2D, hat: Sprite2D, row: Dictionary) -> void:
	# Fixed per-view registration. Hair never participates in size or position.
	var scale_value: float=float(row.display_width)/hat.texture.get_width()
	hat.scale=Vector2.ONE*scale_value
	hat.position.y=float(row.get("band_y",0))-hat.texture.get_height()*scale_value*.5
	if hat.get_parent()==head:head.move_child(hat,head.get_child_count()-1)

func clear_hat_clip() -> void:
	for entry in clipped_hair:
		var node: Sprite2D=entry.node
		if is_instance_valid(node) and node.material==entry.clip:node.material=entry.original
	clipped_hair.clear()

func clip_hair(head: Sprite2D, hat: Sprite2D, row: Dictionary) -> void:
	var sources: Array[Sprite2D]=[]
	for child in head.get_children():
		if str(child.name).begins_with("CharacterHair") and child is Sprite2D and child.visible and child.texture!=null:sources.append(child)
	if sources.is_empty():sources.append(head)
	for source in sources:
		var mat: ShaderMaterial=source.get_meta("season_hat_clip") if source.has_meta("season_hat_clip") else null
		if mat==null:
			mat=ShaderMaterial.new();mat.shader=preload("res://scripts/hat_hair_clip.gdshader");source.set_meta("season_hat_clip",mat)
		mat.set_shader_parameter("hair_size",Vector2(source.texture.get_size()))
		mat.set_shader_parameter("hat_mask",texture(row.mask_texture))
		mat.set_shader_parameter("hat_join",texture(row.join_texture))
		mat.set_shader_parameter("hat_size",Vector2(hat.texture.get_size())*hat.scale)
		mat.set_shader_parameter("hat_position",hat.position)
		mat.set_shader_parameter("clip_below",float(row.get("clip_below",0)))
		mat.set_shader_parameter("join_overlap",float(row.get("join_overlap",3.0)))
		clipped_hair.append({"node":source,"original":source.material,"clip":mat});source.material=mat

func apply(character: Node2D, inventory: ItemInventory, facing: String) -> void:
	clear_hat_clip()
	if inventory==null: return
	var view := "side" if facing in ["left","right"] else facing
	# Tool durability / main-hand changes do not change a hat or garment.
	var key := view
	for slot in ["head","outfit"]:key+="|"+str(inventory.equipment.get(slot,{}).get("item_id",""))
	if key!=signature:
		signature=key
		for node in character.find_children("EquipmentVisual*","Sprite2D",true,false):
			node.get_parent().remove_child(node);node.queue_free()
	for slot in ["head","outfit"]:
		var instance: Dictionary=inventory.equipment.get(slot,{})
		if instance.is_empty(): continue
		var definition := inventory.database.item(str(instance.item_id))
		var rows: Array=registry.get(definition.get("visual_id",""),{}).get(view,[])
		for i in rows.size():
			var row: Dictionary=rows[i]
			var parent := character.get_node_or_null(NodePath(str(row.get("parent",""))))
			var path := str(row.get("texture",""))
			if parent==null or not path.begins_with("res://assets/") or not ResourceLoader.exists(path): continue
			if row.get("replace",false):
				parent.texture=texture(path)
				if row.has("skin_region") and parent.material is ShaderMaterial:
					parent.material.set_shader_parameter("skin_region",Vector2(row.skin_region[0],row.skin_region[1]))
				continue
			var name_value: String= "EquipmentVisual_"+slot+"_"+str(i)
			var sprite: Sprite2D=parent.get_node_or_null(name_value)
			if sprite==null:
				sprite=Sprite2D.new();sprite.name=name_value;sprite.texture=texture(path)
				var point: Array=row.get("position",[0,0])
				sprite.position=Vector2(point[0],point[1]);sprite.scale=Vector2.ONE*float(row.get("scale",1.0))
				sprite.show_behind_parent=bool(row.get("behind",false))
				# Establish the final local transform BEFORE entering the interpolated rig.
				if row.has("display_width"):fit_hat(parent,sprite,row)
				parent.add_child(sprite)
				sprite.reset_physics_interpolation()
			if row.has("display_width"):fit_hat(parent,sprite,row)
			if row.has("mask_texture"):clip_hair(parent,sprite,row)

