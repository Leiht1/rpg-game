extends SceneTree
const OUT="res://reports/animals-art-formal-v2/"
var w: Node
var s: Node
var a: Node
var checks=[]
var origin=Vector2.ZERO
func check(ok: bool,label: String) -> void:
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func _initialize() -> void:call_deferred("run")
func frames(n=3) -> void:
 for i in n:await process_frame
func physics(n=3) -> void:
 for i in n:await physics_frame
func snap(label: String) -> void:
 await frames(3)
 root.get_texture().get_image().save_png(OUT+label+".png")
func building(id: String,kind: String,at: Vector2,vertical: bool=false) -> Node:
 var r=s.builds.candidate(kind,at,vertical,false,0);s.builds.states[id]=r
 s.builds.install(w.stream.chunk_at(Vector2(r.x,r.y)))
 return s.builds.visuals[id]
func actor(id: String, species: String, at: Vector2, tamed: bool=true, baby: bool=false) -> Node:
 a.states[id]=a.make_row(species,at,tamed,baby);a.sync_visuals()
 var n=a.visuals[id];n.set_physics_process(false);return n
func aim(n:Node,at:Vector2) -> void:
 n.goal=at;n.decision=100;n.feeding=false;n.feedback=0
func run() -> void:
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
 s=w.item_service;s.set_process(false);a=s.animals;a.set_physics_process(false)
 while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
 await physics(5)
 for n in a.visuals.values():n.free()
 a.visuals.clear();a.states.clear();a.generated.clear()
 var start=w.player.position
 # Find a naturally clear site without removing resources from the fixture.
 for y in range(-5,6):
  for x in range(-5,6):
   var base=Vector2(floor(start.x/96)*96,floor(start.y/64)*64)+Vector2(x*96,y*64)
   var clear=true
   for yy in range(-1,6):
    for xx in range(-1,6):
     var p=base+Vector2(xx*48,yy*32)
     if not a.clear_at(p,16):clear=false;break
    if not clear:break
   if clear:origin=base;break
  if origin!=Vector2.ZERO:break
 check(origin!=Vector2.ZERO,"natural dry clear pen site found")
 if origin==Vector2.ZERO:await finish();return
 w.player.position=origin+Vector2(96,110);w.player.camera.reset_smoothing()
 # 2x3 cells; existing real fence and gate geometry.
 for x in 2:
  building("top%d"%x,"wood_fence",origin+Vector2(x*96+48,0))
  building("bottom%d"%x,"fence_gate" if x==0 else "wood_fence",origin+Vector2(x*96+48,192))
 for y in 3:
  building("left%d"%y,"wood_fence",origin+Vector2(0,y*64+32),true)
  building("right%d"%y,"wood_fence",origin+Vector2(192,y*64+32),true)
 await physics(4)
 var c=actor("pen-chicken","chicken",origin+Vector2(48,145))
 var sh=actor("pen-sheep","sheep",origin+Vector2(142,74))
 var baby=actor("pen-baby","sheep",origin+Vector2(143,140),true,true)
 await physics(2)
 check(c.rig is Skeleton2D and c.bones.has_all(["Head","Body","Wing","Leg0","Leg1"]),"chicken skeleton part structure")
 check(sh.bones.has_all(["Head","Body","Leg0","Leg1","Leg2","Leg3"]),"sheep four limb skeleton")
 check(is_equal_approx(absf(baby.rig.scale.x),.48),"baby uses same art at 48 percent size")
 var gate=s.builds.visuals.bottom0
 check(not a.nearby_path(origin+Vector2(48,145),origin+Vector2(48,230)),"closed gate blocks remote breeding/birth path")
 aim(c,origin+Vector2(48,260))
 for i in 200:c._physics_process(1.0/60)
 check(c.position.y<origin.y+180,"closed gate really blocks chicken movement")
 c.position=origin+Vector2(48,145);a.states["pen-chicken"].x=c.position.x;a.states["pen-chicken"].y=c.position.y
 check(c.move_and_collide(Vector2(0,100))!=null,"swept body cannot tunnel through gate")
 c.position=origin+Vector2(48,145)
 s.builds.states.bottom0.open=true;gate.update_gate();await create_timer(.3).timeout;await physics(3)
 check(a.nearby_path(origin+Vector2(48,145),origin+Vector2(48,230)),"open gate clears passage in remote geometry")
 var hit=c.move_and_collide(Vector2(0,100))
 check(hit==null and c.position.y>origin.y+220,"open real gate allows animal out")
 c.position=origin+Vector2(48,90);a.states["pen-chicken"].x=c.position.x;a.states["pen-chicken"].y=c.position.y
 # Gate transaction checks actor collisions and closes normally when clear.
 s.builds.states.bottom0.open=false;gate.update_gate();await create_timer(.3).timeout;await physics(3)
 c.position=origin+Vector2(48,90)
 hit=c.move_and_collide(Vector2(-100,0))
 check(hit!=null and c.position.x>origin.x+7,"fence blocks lateral motion")
 c.position=origin+Vector2(48,90);aim(c,origin+Vector2(110,90));var leg=c.bones.Leg0.rotation
 for i in 20:c._physics_process(1.0/60)
 check(not is_equal_approx(c.bones.Leg0.rotation,leg) and c.travel>0,"walking moves limbs by actual travel")
 c.feedback=1.0;var head=c.bones.Head.rotation;c._physics_process(.12)
 check(c.velocity==Vector2.ZERO and not is_equal_approx(c.bones.Head.rotation,head),"feed feedback stops and nods")
 c.feedback=0;c.feeding=true;c.decision=10;c._physics_process(.1)
 check(c.bones.Head.rotation>.3,"foraging lowers head")
 c.feeding=false;c.decision=0;a.states["pen-chicken"].mode="follow";w.player.position=origin+Vector2(140,150);c._physics_process(.1)
 check(c.goal.distance_to(w.player.position)<65 and not c.feeding,"follow selects goal beside player")
 # No enclosed flag: collision alone keeps a departing wild animal inside.
 var wild=a.states["pen-chicken"];wild.tamed=false;wild.trust=0;wild.wild_age=400;wild.home_x=c.position.x;wild.home_y=c.position.y;wild.escape_angle=PI;c.decision=0;c._physics_process(.1)
 check(not wild.departed,"trapped wild animal not silently despawned")
 # Test long migration on the open route using persisted travel distance.
 c.position=origin+Vector2(90,90);wild.home_x=c.position.x-700;wild.home_y=c.position.y
 aim(c,c.position+Vector2(25,0));c._physics_process(.1)
 check(wild.departed,"unconfined wild migrant leaves after physical departure")
 a.seed_chunk(w.stream.chunk_at(c.position));var count=a.states.size();a.seed_chunk(w.stream.chunk_at(c.position));check(a.states.size()==count,"departed chunk not replenished")
 wild.departed=false;wild.tamed=true;wild.trust=3;c.show();a.states["pen-chicken"].mode="stay"
 # Real workbench and normal crafting transaction.
 var bench=building("animal-workbench","workbench",origin+Vector2(96,285))
 w.player.position=bench.position+Vector2(0,36);s.craft_station_id="animal-workbench"
 for id in ["copper_ore","silver_ore","wood"]:s.inventory.add(id,8)
 var before=[s.inventory.count_item("copper_ore"),s.inventory.count_item("silver_ore"),s.inventory.count_item("wood")]
 check(s.craft("workbench_shears",1,s.new_craft_request()).is_empty(),"normal tool bench crafts shears")
 check(s.inventory.count_item("copper_ore")==before[0]-3 and s.inventory.count_item("silver_ore")==before[1]-1 and s.inventory.count_item("wood")==before[2]-2,"craft atomically spends actual metal resources")
 var index=-1
 for i in 40:
  if s.inventory.slots[i].get("item_id","")=="shears":index=i;break
 check(index>=0 and s.inventory.equip(index),"crafted shears equip normally")
 # Native player animation, same registered held-tool policy in all four views.
 var r=a.states["pen-sheep"];r.fed_until=a.clock+10000;r.product=2880;r.wool=true
 w.player.position=sh.position+Vector2(-42,0);w.player.facing="right";w.player.input_blocked=false
 w.player.action="shear";w.player.action_target=sh;w.player.action_clock=.42;w.player.update_animation()
 var arm=w.player.character.get_node("Visual/Pelvis/ArmR")
 check(w.player.animation_player.current_animation=="camp/side_throw_right","shear reuses existing reach gesture")
 check(arm.get_node("HeldTool").visible and arm.get_node("HeldTool").get_meta("item_id")=="shears","shears shown through common tool renderer")
 await snap("shear-reach")
 w.player.action_clock=.35;w.player.action_committed=false;w.player._physics_process(.03)
 check(w.player.action_succeeded and not r.wool and s.inventory.count_item("wool")==2,"native animation commits one shearing at reach")
 sh.refresh();check(sh.body_sprite.texture.resource_path.ends_with("sheep_bare.png"),"shearing swaps actual body texture")
 w.player.cancel_action()
 for view in ["front","back","left","right"]:
  w.player.facing=view;w.player.action="shear";w.player.action_target=sh;w.player.action_clock=.42;w.player.update_animation()
  check(w.player.animation_player.current_animation.ends_with("throw_right"),"shear gesture view "+view)
 w.player.cancel_action()
 # Failed save must roll back wool, durability and products.
 r.product=2880;r.wool=true
 var original_path=s.save_path;s.save_path="res://reports/animals-art-formal-v2/no-such-directory/save.json";w.persistent_world=true
 var old=r.duplicate(true);var inv=s.inventory.slots.duplicate(true);var equipment=s.inventory.equipment.duplicate(true)
 check(not a.interact("pen-sheep",sh),"failed shear save rejects transaction")
 check(a.states["pen-sheep"]==old and s.inventory.slots==inv and s.inventory.equipment==equipment,"failed save restores wool yield and exact durability")
 w.persistent_world=false;s.save_path=original_path
 # Pause and real time/sleep routing.
 var age=a.states["pen-baby"].age;w.environment_view.simulation.paused=true;sh.set_physics_process(true);var pos=sh.position;await physics(4)
 check(sh.position==pos and a.states["pen-baby"].age==age,"paused world freezes animal movement/time")
 sh.set_physics_process(false);w.environment_view.simulation.paused=false
 var time=a.clock;var sim=w.environment_view.simulation;w.environment_view.advance_gameplay(1.0)
 check(is_equal_approx(a.clock-time,1440.0/(sim.day_length_minutes*60.0)),"animal timers use normal world game-minute conversion")
 # Restore arranged overview for visual review.
 a.states["pen-sheep"].wool=true;sh.refresh();c.position=origin+Vector2(48,60);sh.position=origin+Vector2(140,70)
 baby.position=origin+Vector2(140,145);w.player.position=origin+Vector2(80,140);w.player.facing="front";w.player.update_animation();w.player.camera.reset_smoothing()
 for id in a.visuals:
  var n=a.visuals[id];n.set_physics_process(false)
 check(DisplayServer.window_get_size()==Vector2i(1280,720),"native window uses project default 1280x720")
 await snap("overview")
 await finish()
func finish() -> void:
 var failed=checks.filter(func(c):return not c.pass)
 var f=FileAccess.open(OUT+"native.json",FileAccess.WRITE);f.store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"));f.close()
 print("ANIMALS NATIVE: ",checks.size()," checks, ",failed.size()," failed")
 w.persistent_world=false;w.free();await process_frame;quit(0 if failed.is_empty() else 1)

