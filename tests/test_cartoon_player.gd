extends SceneTree
var failures: Array[String]=[]
func check(ok: bool,message: String) -> void:
 if not ok: failures.append(message); push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var world=load("res://scenes/world.tscn").instantiate()
 root.add_child(world)
 world.player.automated=true
 var deadline=Time.get_ticks_msec()+20000
 while not world.started and Time.get_ticks_msec()<deadline: await process_frame
 check(world.started,"World startup")
 if not world.started: quit(1); return
 var p: WildPlayer=world.player
 p.set_physics_process(false)
 var origin=p.position
 check(p.animation_player.get_animation_list().size()==6,"Only six locomotion clips")
 check(p.character.find_children("*","Sprite2D",true,false).size()==6,"Six body parts; no props")
 check(p.character.position+WildPlayer.ANCHOR==Vector2.ZERO,"Foot anchor")
 check(p.find_children("*","CollisionShape2D",true,false)[0].shape.radius==10,"Collision radius")
 var sheet=Image.create(512,256,false,Image.FORMAT_RGBA8)
 for a in 2:
  for d in 4:
   p.facing=["front","right","back","left"][d]
   p.moving=a==1
   p.gait_distance=32.0
   p.idle_clock=.45
   p.update_animation()
   var expected=("side" if d in [1,3] else p.facing)+("_walk" if a==1 else "_breathe")
   check(p.animation_player.current_animation==expected,"Direction/action: "+expected)
   check(p.character.get_node("Visual").scale.x==(-1.0 if d==3 else 1.0),"Mirror")
   await process_frame
   await RenderingServer.frame_post_draw
   if DisplayServer.get_name()!="headless":
    var shot=root.get_texture().get_image()
    var screen=p.get_global_transform_with_canvas().origin
    sheet.blit_rect(shot,Rect2i(Vector2i(screen)-Vector2i(64,112),Vector2i(128,128)),Vector2i(d*128,a*128))
 for dir in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
  p.position=origin
  p.input_override=dir
  p.gait_distance=0
  for i in 12: p._physics_process(1.0/60.0)
  check(absf(p.position.distance_to(origin)-40.0)<.1,"Normalized movement "+str(dir))
  check(absf(p.gait_distance-40.0)<.1,"Distance clock")
  p.input_override=Vector2.ZERO
  p._physics_process(1.0/60.0)
  check(not p.moving and str(p.animation_player.current_animation).ends_with("breathe"),"Stop breathing")
 p.position=origin
 p.facing="front"
 p.update_animation()
 await process_frame
 await RenderingServer.frame_post_draw
 if DisplayServer.get_name()!="headless":
  sheet.save_png("res://reports/cartoon-player-world-poses.png")
  root.get_texture().get_image().save_png("res://reports/cartoon-player-world.png")
 var f=FileAccess.open("res://reports/cartoon-player-tests.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"failures":failures,"speed":WildPlayer.WALK_SPEED,"clips":6,"parts":6,"scope":"world startup, eight-direction movement, actual-distance clock, stop, four views, mirror, anchor, unchanged collision radius"},"\t"))
 print("CARTOON PLAYER: ","PASS" if failures.is_empty() else failures)
 quit(0 if failures.is_empty() else 1)

