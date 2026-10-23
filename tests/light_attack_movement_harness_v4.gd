extends "res://scripts/network_game_worker.gd"
var result: Dictionary
func _ready() -> void:pass
func write_result(value: Dictionary) -> void:result=value
func movement_clear(_at: Vector2,_request: Dictionary) -> bool:return true
