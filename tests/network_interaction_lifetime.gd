extends SceneTree
class Stream extends Node:
	var drops:Array=[]
	var items:Node
	func clear_reach(_at:Vector2,_point:Vector2,_target:Node)->bool:return true
func _initialize()->void:run.call_deferred()
func run()->void:
	var stream:=Stream.new();root.add_child(stream)
	var removed:=Node2D.new();stream.add_child(removed)
	stream.drops.append(removed);removed.free()
	var drop:=Node2D.new();stream.add_child(drop);drop.add_to_group("drops");drop.position=Vector2(10,0)
	stream.drops.append(drop)
	var target=load("res://scripts/world_interaction.gd").target(stream,Vector2.ZERO,"right",Vector2.INF)
	if target!=drop:
		print("INTERACTION_LIFETIME_FAIL stale drop blocks next target");quit(1);return
	assert(load("res://scripts/world_interaction.gd").caption(target,null)=="E 拾取")
	print("INTERACTION_LIFETIME_PASS stale drop ignored and next pickup hint available")
	stream.queue_free();await process_frame;quit()
