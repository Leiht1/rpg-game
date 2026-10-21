extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var script=load("res://scripts/network_game_world.gd")
	print("NETWORK_GAME_COMPILE ",script.can_instantiate())
	quit(0 if script.can_instantiate() else 1)
