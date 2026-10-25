extends "res://scripts/harvest_node.gd"
func _ready() -> void:
	super._ready()
	var footprint:=ConvexPolygonShape2D.new();footprint.points=preload("res://scripts/mine_puzzle_geometry.gd").polygon("ore")
	collision.get_child(0).shape=footprint
	collision.set_meta("mine_volume","ore")
func refresh_stage() -> void:
	var index: int=get_meta("crystal_index",0)
	var hits: int=service.chapter.puzzle.state.ores[index].hits
	hit_material.set_shader_parameter("damage_texture",load("res://assets/ores/v06/frame-10.png"))
	hit_material.set_shader_parameter("damage_amount",float(hits)/float(service.chapter.puzzle.config.hits))
	hit_material.set_shader_parameter("crack_overlay",true)
	set_meta("progress",str(hits)+"/"+str(service.chapter.puzzle.config.hits))
