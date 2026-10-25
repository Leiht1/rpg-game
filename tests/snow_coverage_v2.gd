extends SceneTree
const Snow=preload("res://scripts/season_features_visual.gd")
class StreamStub extends RefCounted:
 var loaded: Dictionary={}
class BuildsStub extends RefCounted:
 var states: Dictionary={}
 var visuals: Dictionary={}
class ServiceStub extends RefCounted:
 var builds=BuildsStub.new()
class EnvStub extends RefCounted:
 var simulation: Node
class WorldStub extends Node2D:
 var world_seed:=271828
 var started:=true
 var stream=StreamStub.new()
 var item_service=ServiceStub.new()
 var environment_view=EnvStub.new()
class Grid extends Node2D:
 func _draw() -> void:
  draw_rect(Rect2(15000,15000,10000,10000),Color("57794c"))
  for x in range(15000,25000,96):draw_line(Vector2(x,15000),Vector2(x,25000),Color("78966a"),1)
  for y in range(15000,25000,64):draw_line(Vector2(15000,y),Vector2(25000,y),Color("78966a"),1)
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func frames(n: int=2) -> void:
 for i in n:await process_frame
func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://reports/local-polish-v1/snow")
 root.size=Vector2i(int(ProjectSettings.get_setting("display/window/size/window_width_override",1280)),int(ProjectSettings.get_setting("display/window/size/window_height_override",720)))
 root.content_scale_size=root.size
 var w=WorldStub.new();root.add_child(w)
 var sim=preload("res://scripts/world_environment.gd").new();sim.day=23;w.add_child(sim);w.environment_view.simulation=sim
 w.add_child(Grid.new())
 var camera:=Camera2D.new();camera.process_callback=Camera2D.CAMERA2D_PROCESS_PHYSICS;camera.position=Vector2(20000,20000);w.add_child(camera);camera.make_current();camera.force_update_scroll()
 var rig: Node2D=load("res://assets/hero/cartoon/character.tscn").instantiate();rig.position=camera.position-Vector2(64,112);w.add_child(rig)
 var snow=Snow.new();snow.world=w;w.add_child(snow);snow.set_process(false)
 snow._process(0);await frames()
 check(snow.flakes.size()==115 and snow.snow_positions.size()==115,"original snow count retained")
 var samples:=0;var min_fall:=100.0;var max_fall:=0.0
 var directions=[Vector2.ZERO,Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(-1,-1).normalized()]
 for speed in [200.0,310.0]:
  for direction in directions:
   for step in 12:
    var previous: Array[Vector2]=snow.snow_positions.duplicate();var old_transform: Transform2D=root.get_canvas_transform()
    camera.position+=direction*speed*.05;rig.position=camera.position-Vector2(64,112);camera.reset_physics_interpolation();camera.force_update_scroll();await create_timer(.05).timeout
    var transform: Transform2D=root.get_canvas_transform()
    snow._process(.05)
    var bounds: Rect2=snow.snow_bounds(transform,Vector2(root.size))
    var tested:=0;var falling:=true;var projection:=true
    for i in previous.size():
     if not bounds.grow(-8).has_point(previous[i]):continue
     var delta: Vector2=snow.snow_positions[i]-previous[i]
     if absf(delta.x)>10 or absf(delta.y)>10:continue
     tested+=1;samples+=1;min_fall=minf(min_fall,delta.y);max_fall=maxf(max_fall,delta.y)
     falling=falling and delta.y>=.94 and delta.y<=2.36
     var residual: Vector2=(transform*snow.snow_positions[i])-(old_transform*previous[i])-((transform*previous[i])-(old_transform*previous[i]))
     projection=projection and residual.y>0
    check(tested>50 and falling and projection,"world fall and camera-relative drift %s speed%s frame%s"%[direction,speed,step])
    if speed==200 and direction==Vector2.RIGHT and step in [0,6,11] and DisplayServer.get_name()!="headless":
     await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/local-polish-v1/snow/move-%02d.png"%step)
 var previous: Array[Vector2]=snow.snow_positions.duplicate();var old_transform: Transform2D=root.get_canvas_transform();var clock: float=snow.clock
 sim.paused=true;camera.position.x+=10;camera.reset_physics_interpolation();camera.force_update_scroll();await frames(3);snow._process(.5)
 check(is_equal_approx(snow.clock,clock),"paused snowfall clock stops")
 var stable:=0;var tracks:=0
 for i in previous.size():
  if previous[i].distance_to(snow.snow_positions[i])<.001:
   stable+=1
   if ((root.get_canvas_transform()*snow.snow_positions[i]-(old_transform*previous[i]))-(root.get_canvas_transform().origin-old_transform.origin)).length()<.001:tracks+=1
 check(stable>100 and stable==tracks and absf(root.get_canvas_transform().origin.x-old_transform.origin.x)>1,"paused particles remain world anchored while camera moves")
 sim.paused=false
 for zoom in [.65,1.65,1.0]:
  camera.zoom=Vector2.ONE*zoom;camera.force_update_scroll();snow._process(.05)
  var bounds: Rect2=snow.snow_bounds(root.get_canvas_transform(),Vector2(root.size))
  check(snow.snow_positions.all(func(p):return bounds.has_point(p)),"zoom recycle stays within visible world "+str(zoom))
  var bins:=PackedInt32Array();bins.resize(12)
  for point in snow.snow_positions:
   var screen: Vector2=root.get_canvas_transform()*point
   if Rect2(Vector2.ZERO,Vector2(root.size)).has_point(screen):
    var cell:=Vector2i(screen/Vector2(root.size)*Vector2(4,3));bins[cell.y*4+cell.x]+=1
  check(Array(bins).all(func(count):return count>=2),"all twelve screen regions filled after zoom "+str(zoom)+" "+str(bins))
 camera.position+=Vector2(10000,-8000);camera.force_update_scroll();snow._process(.05)
 var bounds: Rect2=snow.snow_bounds(root.get_canvas_transform(),Vector2(root.size))
 check(snow.snow_positions.size()==115 and snow.snow_positions.all(func(p):return bounds.has_point(p)),"large camera jump recycles fixed population")
 sim.day=2;snow._process(.05);check(not snow.snow_active,"nonwinter stops snow")
 sim.day=23;snow._process(.05);check(snow.snow_active and snow.snow_positions.size()==115,"winter reentry seeds current view")
 var failed: Array=checks.filter(func(c):return not c.pass)
 var f=FileAccess.open("res://reports/local-polish-v1/snow/results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failed":failed.size(),"tracked_samples":samples,"min_vertical_step":min_fall,"max_vertical_step":max_fall},"\t"));f.close()
 print("SNOW_MOTION ",checks.size()," checks ",failed.size()," failed; world samples ",samples)
 w.queue_free();await frames(3);quit(1 if not failed.is_empty() else 0)
