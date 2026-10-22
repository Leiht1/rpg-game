extends "res://scripts/launcher.gd"
var lobby_calls:=0
var login_calls:=0
func _ready() -> void:
	add_child(layer);layer.add_child(root);root.add_child(content)
func lobby() -> void:lobby_calls+=1
func login(_activation:bool=false) -> void:login_calls+=1
