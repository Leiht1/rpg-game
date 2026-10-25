extends SceneTree
func _initialize() -> void:
 var gen=preload("res://scripts/world_generator.gd").new(271828,1536)
 var best:=Vector2.INF
 for lake in gen.lakes:
  var at:=Vector2(lake.x,lake.y)
  var safe:=true
  for offset in [Vector2.ZERO,Vector2(500,0),Vector2(-500,0),Vector2(0,500),Vector2(0,-500)]:
   if gen.lake_weight(at+offset)<.8:safe=false;break
  if safe:best=at;break
 assert(best.is_finite(),"existing large lake for actual dual ice movement")
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify({"x":best.x,"y":best.y}))
 quit()
