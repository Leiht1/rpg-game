extends RefCounted
## Only the explicitly registered live player objects route to the server.
## Staged inventories and single-player instances retain their original rules.
static func send(owner: Object, operation: String, args: Array=[]) -> bool:
	if not Engine.has_meta("network_game_controller"):return false
	var controller=Engine.get_meta("network_game_controller")
	if not is_instance_valid(controller) or not controller.routes.has(owner.get_instance_id()):return false
	controller.enqueue(operation,encode(args))
	return true
static func encode(value: Variant) -> Variant:
	if value is Vector2:return {"x":value.x,"y":value.y}
	if value is Node2D:
		for key in ["animal_id","building_id","camp_id","drop_id","prop_id","ore_id","tree_id"]:
			if value.has_meta(key):return {key:str(value.get_meta(key))}
		return {}
	if value is Array:
		var result: Array=[]
		for item in value:result.append(encode(item))
		return result
	return value.duplicate(true) if value is Dictionary else value
