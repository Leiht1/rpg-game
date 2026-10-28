extends "res://scripts/network_game_world.gd"
var audit_apply: Array=[]
func apply_snapshot(snapshot: Dictionary) -> void:
	var began:=Time.get_ticks_usec()
	super.apply_snapshot(snapshot)
	audit_apply.append({"began_us":began,"completed_us":Time.get_ticks_usec(),"apply_ms":(Time.get_ticks_usec()-began)/1000.0})
