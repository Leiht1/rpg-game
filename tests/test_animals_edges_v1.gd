extends SceneTree
const OUT="res://reports/animals-v1/"
var w:Node
var s:Node
var a:Node
var checks=[]
func check(ok:bool,label:String)->void:
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func _initialize()->void:call_deferred("run")
func frames(n=3)->void:
 for i in n:await process_frame
func run()->void:
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 s=w.item_service;a=s.animals;w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false);s.set_process(false);a.set_physics_process(false)
 while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
 await frames(5)
 s.save_path=OUT+"isolated-save.json";w.persistent_world=true;s.load_state()
 check(s.writable,"new process loads animal save")
 check(a.serial==1 and a.states.has("born:1"),"exact single birth persists in new process")
 check(a.stage(a.states["born:1"])==2,"growth persists without offline time")
 check(a.egg_count("c")==3,"uncollected eggs persist exactly once")
 check(a.states.c.eggs==4,"monotonic egg identity survives new process")
 check(a.states.s.tamed and not a.states.s.wool and a.states.s.product==0,"hungry shorn state persists")
 var initial=JSON.stringify(a.serialize());await frames(20)
 check(JSON.stringify(a.serialize())==initial,"no automatic offline advance or duplicate birth/regrowth")
 # Exercise the actual stream unload/install path, not just serialization.
 a.sync_visuals();await frames(3)
 var coord=w.stream.chunk_at(a.point(a.states.c));var animal_before=JSON.stringify(a.serialize());var eggs_before=a.egg_count("c")
 check(w.stream.loaded.has(coord),"persisted chicken chunk is actually loaded")
 w.stream.unload_chunk(coord);a.sync_visuals()
 check(not a.visuals.has("c"),"actual chunk unload releases animal visual")
 await frames(3)
 var packet=w.generator.build_chunk(coord);var stamps:Array[Dictionary]=[];packet["ground_stamps"]=stamps
 w.stream.install_chunk(packet);a.seed_chunk(coord);a.sync_visuals();await frames(3)
 check(a.visuals.has("c"),"actual chunk reinstall rebuilds same animal visual")
 check(JSON.stringify(a.serialize())==animal_before,"chunk roundtrip preserves IDs trust production growth and pair progress")
 check(a.egg_count("c")==eggs_before and a.serial==1,"chunk roundtrip does not duplicate eggs or babies")
 # Old saves missing animals migrate without touching unrelated fields.
 var snapshot=s.snapshot();snapshot.erase("animals");var path=OUT+"legacy-no-animals.json";var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(snapshot));f.close()
 a.states.clear();a.generated.clear();a.clock=0;a.serial=0;s.load_state(path)
 check(s.writable and a.states.is_empty(),"old save without animals loads with empty additive state")
 # Restore full and ensure unknown/corrupt animal schema protects the entire source save.
 s.load_state();var before=s.inventory.slots.duplicate(true);var old=a.serialize()
 snapshot=s.snapshot();snapshot.animals.version=99;path=OUT+"future-invalid.json";f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(snapshot));f.close();s.load_state(path)
 check(not s.writable and s.inventory.slots==before and JSON.stringify(a.serialize())==JSON.stringify(old),"future animal version protects source and leaves live state intact")
 s.writable=true;w.persistent_world=false
 # Remote unloaded timers + births use persistent barriers, not loaded physics.
 for n in a.visuals.values():n.free()
 a.visuals.clear();a.states.clear();a.generated.clear();a.serial=0
 var p=w.player.position+Vector2(3000,0)
 for y in range(20):
  for x in range(20):
   var test=p+Vector2(x*48,y*48)
   if a.clear_at(test,14) and a.clear_at(test+Vector2(40,0),14) and a.nearby_path(test,test+Vector2(40,0)):p=test;break
  if not w.stream.loaded.has(w.stream.chunk_at(p)) and a.clear_at(p,14) and a.nearby_path(p,p+Vector2(40,0)):break
 check(not w.stream.loaded.has(w.stream.chunk_at(p)),"remote test is actually unloaded")
 a.states["remote-a"]=a.make_row("chicken",p,true);a.states["remote-b"]=a.make_row("chicken",p+Vector2(40,0),true)
 a.advance(180);check(a.serial==1,"unloaded pair reproduces with same game-time rules")
 a.states["remote-a"].cooldown=10000;a.states["remote-b"].cooldown=10000
 a.advance(540);check(a.egg_count("remote-a")==1 and a.egg_count("remote-b")==1,"unloaded chickens produce persistent ground eggs")
 var counts=[a.serial,s.loose.size()];a.sync_visuals();a.sync_visuals()
 check(a.serial==counts[0] and s.loose.size()==counts[1] and a.visuals.is_empty(),"visual streaming never simulates duplicate products or births")
 # Pair cap and cooldown: no hidden births beyond nearby cap.
 a.states.clear();a.serial=0
 for i in 8:
  a.states["cap:%d"%i]=a.make_row("chicken",p+Vector2(i*5,0),true)
  a.states["cap:%d"%i].mode="follow"
 a.advance(180);check(a.serial==0,"eight nearby same-species blocks reproduction")
 a.states.erase("cap:7");a.advance(180);check(a.serial==1 and a.states.size()==8,"first birth immediately consumes last population slot")
 a.advance(180);check(a.serial==1,"cooldown and population cap prevent extra birth")
 # Wrong species, babies, starvation, separation and barriers all reject breeding.
 a.states.clear();a.serial=0
 a.states["one"]=a.make_row("chicken",p,true);a.states["two"]=a.make_row("sheep",p+Vector2(40,0),true)
 a.advance(180);check(a.serial==0,"cross species never breeds")
 a.states.two=a.make_row("chicken",p+Vector2(40,0),true,true);a.advance(180);check(a.serial==0,"baby never breeds")
 a.states.two=a.make_row("chicken",p+Vector2(40,0),true);a.states.two.fed_until=0;a.advance(180);check(a.serial==0,"starved parent never breeds")
 a.states.two=a.make_row("chicken",p+Vector2(200,0),true);a.advance(180);check(a.serial==0,"distant parents never breed")
 # Real sleep uses same game-time increment, and debug preview remains separate.
 a.states.clear();a.states["sleep-baby"]=a.make_row("sheep",p,true,true)
 s.body.energy=40;s.body.start_sleep(180)
 var elapsed=s.body.sleep_elapsed;var time=a.clock;var age=a.states["sleep-baby"].age
 w.environment_view.advance_gameplay(1)
 check(a.clock>time and is_equal_approx(a.states["sleep-baby"].age-age,s.body.sleep_elapsed-elapsed),"sleep advances animal age at actual body game-time rate")
 check(a.stage(a.states["sleep-baby"])==0,"sleep adds no extra growth multiplier")
 # Feed failure rollback and full-inventory shear protection.
 var at=a.find_near(w.player.position,35,60);a.states["feed-fail"]=a.make_row("chicken",at);a.sync_visuals();await frames(3)
 var target=a.visuals["feed-fail"];target.set_physics_process(false);s.body.sleeping=false;s.body.sleep_session={};s.body.energy=100
 s.inventory.selected=0;s.inventory.slots[0]={"item_id":"wild_berry","count":2}
 var r=a.states["feed-fail"].duplicate(true);s.save_path=OUT+"no-directory/fail.json";w.persistent_world=true
 check(not a.feed("feed-fail",0,s.inventory.slots[0].duplicate(true)).is_empty(),"failed feed save rejects")
 check(a.states["feed-fail"]==r and s.inventory.slots[0].count==2,"failed feed restores food trust and feeding timer")
 w.persistent_world=false
 # Full inventory must not consume wool readiness or wear shears.
 a.states["full-sheep"]=a.make_row("sheep",at,true);a.states["full-sheep"].product=2880
 a.sync_visuals();await frames(3)
 var sheep=a.visuals["full-sheep"];sheep.set_physics_process(false)
 target.position=at+Vector2(0,50)
 s.inventory.equipment.main_hand=s.inventory.instance("shears")
 for i in 40:s.inventory.slots[i]={"item_id":"stone","count":50}
 check(not a.interact("full-sheep",sheep) and a.states["full-sheep"].wool and s.inventory.equipment.main_hand.durability==100,"full bag refuses sheep yield without wear/state loss")
 # A remote wild animal walks away; a remote enclosed wild animal hits persisted fence geometry.
 var remote=p+Vector2(400,100)
 for n in 30:
  if a.clear_at(remote,14) and a.nearby_path(remote,remote+Vector2(30,0)):break
  remote+=Vector2(48,0)
 var wild=a.make_row("chicken",remote);wild.wild_age=360;wild.escape_angle=0
 var previous=a.point(wild);a.migrate_remote(wild,10)
 check(a.point(wild).distance_to(previous)>0,"unloaded unconfined wild animal migrates physically")
 var base=Vector2(floor(remote.x/96)*96,floor(remote.y/64)*64)
 for xx in 2:
  for yy in [0,2]:
   var key="remote-pen-h:%d:%d"%[xx,yy];s.builds.states[key]=s.builds.candidate("wood_fence",base+Vector2(xx*96+48,yy*64),false,false,0)
 for yy in 2:
  for xx in [0,2]:
   var key="remote-pen-v:%d:%d"%[xx,yy];s.builds.states[key]=s.builds.candidate("wood_fence",base+Vector2(xx*96,yy*64+32),true,false,0)
 wild=a.make_row("chicken",base+Vector2(96,64));wild.wild_age=360
 for n in 15:a.migrate_remote(wild,10)
 check(Rect2(base+Vector2(8,8),Vector2(176,112)).has_point(a.point(wild)) and not wild.departed,"unloaded real fence ring retains migrating wild animal")
 var tame=a.make_row("chicken",remote,true);tame.wild_age=360;tame.escape_angle=PI
 previous=a.point(tame);a.migrate_remote(tame,10)
 check(a.point(tame).distance_to(previous)>0 and not tame.departed,"unfenced tame animal can drift away but never disappears")
 var failed=checks.filter(func(c):return not c.pass);f=FileAccess.open(OUT+"restart-edges.json",FileAccess.WRITE);f.store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"));f.close()
 print("ANIMALS RESTART/EDGES: ",checks.size()," checks, ",failed.size()," failed")
 w.free();await process_frame;quit(0 if failed.is_empty() else 1)
