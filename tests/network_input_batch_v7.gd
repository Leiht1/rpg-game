extends SceneTree
func _initialize() -> void:
 var player=load("res://scripts/network_game_player.gd").new()
 for i in 60:player.record_input(Vector2.RIGHT,1.0/60,false)
 assert(player.pending_inputs.size()<=30)
 var total:=0.0
 for item in player.pending_inputs:
  assert(item.dt<=.05);total+=item.dt
 assert(abs(total-1.0)<.00001)
 player.sent_input_id=player.input_id
 var before: Array=player.pending_inputs.duplicate(true)
 player.record_input(Vector2.RIGHT,1.0/60,false)
 assert(player.pending_inputs.size()==before.size()+1)
 assert(player.pending_inputs[before.size()-1]==before[-1])
 player.record_input(Vector2.LEFT,1.0/60,false)
 assert(player.pending_inputs[-1].dx==-1)
 player.record_input(Vector2.LEFT,1.0/60,true)
 assert(player.pending_inputs[-1].run)
 player.acknowledge({"x":0,"y":0},player.sent_input_id)
 assert(player.pending_inputs.size()==3)
 for i in 180:player.record_input(Vector2.RIGHT,1.0/60,false)
 var batch: Array=player.movement_batch()
 var batch_time:=0.0
 for item in batch:batch_time+=item.dt
 assert(batch_time<=1.0 and batch_time>.9)
 assert(player.sent_input_id==batch[-1].id)
 var frozen: Array=batch.duplicate(true)
 player.record_input(Vector2.RIGHT,1.0/60,false)
 assert(batch==frozen)
 player.free()
 print("INPUT_BATCH_V7_PASS duration/order/inflight/direction/run/ack")
 quit(0)
