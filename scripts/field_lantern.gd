extends Node2D
## Session-only light switch. Environment grading supplies the local warm illumination.
var service: Node
func _ready() -> void:
	visible=false
	call_deferred("connect_inventory")

func connect_inventory() -> void:
	if is_instance_valid(service): service.inventory.changed.connect(check_owned)

func check_owned() -> void:
	if service.lamp_slot().is_empty(): visible=false
