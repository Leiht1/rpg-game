extends "res://scripts/network_game_world.gd"
var received: Array=[]
func _ready() -> void:pass
func _process(_delta: float) -> void:pass
func apply_snapshot(snapshot: Dictionary) -> void:received.append(snapshot)
func _exit_tree() -> void:pass
