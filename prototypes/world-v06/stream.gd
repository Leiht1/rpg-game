extends "res://scripts/chunk_stream.gd"
const Candidate=preload("res://prototypes/world-v06/generator.gd")
func _generate(coord:Vector2i)->void:
	var local_gen=Candidate.new(generator.world_seed,generator.map_cells,generator.plan_snapshot())
	var packet:Dictionary=local_gen.build_chunk(coord)
	var stamps:Array[Dictionary]=[]
	packet["ground_stamps"]=stamps
	mutex.lock();ready_data.append(packet);mutex.unlock()
