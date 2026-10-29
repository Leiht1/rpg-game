extends "res://scripts/network_game_world.gd"
var audit_apply: Array=[]
func apply_snapshot(snapshot: Dictionary) -> void:
	var before: Dictionary={}
	for node in object_root.get_children():before[node.get_instance_id()]=true
	var began:=Time.get_ticks_usec()
	super.apply_snapshot(snapshot)
	var completed:=Time.get_ticks_usec()
	var added:=0;var removed:=0;var body_added:=0;var collision_objects_added:=0
	for node in object_root.get_children():
		if node.is_queued_for_deletion():removed+=1
		if not before.has(node.get_instance_id()):
			added+=1
			if node is CollisionObject2D:body_added+=1
			collision_objects_added+=node.find_children("*","CollisionObject2D",true,false).size()+(1 if node is CollisionObject2D else 0)
	audit_apply.append({"began_us":began,"completed_us":completed,"apply_ms":(completed-began)/1000.0,"created_roots":added,"removed_roots":removed,"created_collision_roots":body_added,"created_collision_objects":collision_objects_added,"restore_parts":Engine.get_meta("sync_trace").restore_parts.duplicate(true)})
