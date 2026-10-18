extends RefCounted
## Approved rig-compatible overlays only. Registry is intentionally empty until art approval.
## visual_id -> {front/back/side: [{parent, texture, position:[x,y], scale}]}.
var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment_visuals.json"))
var signature := ""

func apply(character: Node2D, inventory: ItemInventory, facing: String) -> void:
	if inventory==null: return
	var view := "side" if facing in ["left","right"] else facing
	var key := JSON.stringify(inventory.equipment)+view
	if key==signature: return
	signature=key
	for node in character.find_children("EquipmentVisual*","Sprite2D",true,false):
		node.get_parent().remove_child(node)
		node.queue_free()
	for slot in ["head","outfit"]:
		var instance: Dictionary=inventory.equipment.get(slot,{})
		if instance.is_empty(): continue
		var definition := inventory.database.item(str(instance.item_id))
		for row in registry.get(definition.get("visual_id",""),{}).get(view,[]):
			var parent := character.get_node_or_null(NodePath(str(row.get("parent",""))))
			var texture_path := str(row.get("texture",""))
			if parent==null or not texture_path.begins_with("res://assets/") or not ResourceLoader.exists(texture_path): continue
			var sprite := Sprite2D.new()
			sprite.name="EquipmentVisual_"+slot+"_"+str(parent.get_child_count())
			sprite.texture=load(texture_path)
			var point: Array=row.get("position",[0,0])
			sprite.position=Vector2(point[0],point[1])
			sprite.scale=Vector2.ONE*float(row.get("scale",.25))
			parent.add_child(sprite)
