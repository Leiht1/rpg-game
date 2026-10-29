extends SceneTree
class Channel extends RefCounted:
 var delay:=0.0
 var calls:=0
 func exchange(tree:SceneTree,_host:String,_port:int,_tls:TLSOptions,_identity:String,_path:String,_headers:PackedStringArray,_body:String,_timeout:float)->Array:
  calls+=1
  await tree.create_timer(delay).timeout
  return [HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify({"ok":true,"snapshot":{"marker":calls}}).to_utf8_buffer()]
class Service extends Node:
 var inventory={"selected":0}
 var craft_station_id:=""
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var net=root.get_node("Network")
 var slow=Channel.new();slow.delay=.25
 var fast=Channel.new();fast.delay=.001
 net.http_channels.game_snapshot=slow;net.http_channels.game=fast
 var w=load("res://tests/network_priority_world_v1.gd").new()
 w.item_service=Service.new();root.add_child(w)
 w.refresh_snapshot()
 await create_timer(.02).timeout
 var started:=Time.get_ticks_msec()
 w.enqueue("organize",[])
 while not w.commands.is_empty():await process_frame
 assert(Time.get_ticks_msec()-started<100,"Command blocked by snapshot")
 assert(w.received.size()==1,"Command result not applied")
 print("COMMAND_CONFIRM_MS ",Time.get_ticks_msec()-started)
 await create_timer(.3).timeout
 assert(w.received.size()==1,"Stale snapshot overwrote command")
 w.refresh_snapshot()
 await create_timer(.3).timeout
 assert(w.received.size()==2,"Fresh snapshot missing")
 w.refresh_snapshot();w.stopping=true
 await create_timer(.3).timeout
 assert(w.received.size()==2,"Snapshot applied during close")
 print("PRIORITY_PASS independent command, stale discard, fresh apply, close guard")
 w.item_service.free();w.queue_free();quit()
