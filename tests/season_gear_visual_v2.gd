extends "res://tests/season_gear_v1.gd"
class DataOnly extends Node:
	var database=ItemDatabase.new()
func run() -> void:
	s=DataOnly.new();root.add_child(s)
	root.size=default_size();root.content_scale_size=root.size
	await visual_tests()
	print("VISUAL CHECKS ",checks.size()," failed ",checks.filter(func(c):return not c.pass).size())
	s.queue_free();await frames();quit()
