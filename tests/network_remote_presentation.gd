extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	var actor=load("res://scripts/network_actor.gd").new()
	actor.character=Node2D.new()
	var row:Dictionary={"x":100.0,"y":100.0,"sample_time":10.0,"facing":"right","moving":true,"running":false,"appearance":{},"equipment":{}}
	actor.position=Vector2(100,100);actor.receive(row)
	row.x=120.0;row.sample_time=10.1;actor.receive(row)
	var original:Vector2=actor.target_position
	row.x=105.0;row.sample_time=10.05;actor.receive(row)
	assert(actor.target_position==original)
	var furthest:=0.0
	for i in 30:
		var previous:Vector2=actor.position;actor._physics_process(1.0/60.0)
		assert(actor.position.distance_to(previous)<=5.001)
		furthest=maxf(furthest,actor.position.x)
	assert(furthest<=160.1)
	row.x=140.0;row.sample_time=10.3;row.moving=false;actor.receive(row)
	for i in 60:actor._physics_process(1.0/60.0)
	assert(actor.position.distance_to(Vector2(140,100))<.1)
	actor.character.free()
	actor.free()
	print("REMOTE_PRESENTATION_PASS stale packet rejected, bounded motion/extrapolation, stable stop")
	quit()
