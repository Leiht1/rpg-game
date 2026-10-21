extends "res://tests/world_v06_formal_fixture.gd"
## Explicit empty-camp setup for tests authored before abandoned camps existed.
func _ready() -> void:
	super._ready()
	item_service.builds.states.clear()
	item_service.builds.refresh_all()
