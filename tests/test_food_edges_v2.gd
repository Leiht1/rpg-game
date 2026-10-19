extends SceneTree
var w: Node
var checks=[]
func check(ok,label):
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func _initialize():call_deferred("run")
func run():
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.environment_view.set_process(false);w.set_process(false);w.player.set_physics_process(false)
 var s=w.item_service;s.set_process(false);var e=w.environment_view;var c=s.camps
 s.body.hunger=50;s.body.energy=20;s.body.health=100;s.body.eat({"hallucination":true})
 check(s.body.start_sleep(480,true),"forced sleep uses existing body state")
 e.simulation.paused=false;e.advance_gameplay(150)
 check(s.body.hallucination_remaining==0 and is_equal_approx(s.body.health,80),"actual sleeping gameplay advances full twenty damage")
 check(s.body.sleeping,"hallucination end does not force wake")
 s.body.sleeping=false;s.body.sleep_forced=false;s.body.sleep_elapsed=0;s.body.sleep_duration=0
 var at=w.player.position+Vector2(0,50)
 c.states.test={"x":at.x,"y":at.y,"fuel":500.0,"lit":true,"recipe":"","elapsed":0.0,"ready":false};c.rebuild()
 w.persistent_world=true;s.save_path="user://missing-food-v2-directory/save.json"
 s.inventory.add("potato",1);var before=s.inventory.slots.duplicate(true)
 check(not c.act("test","cook","roast_potato").is_empty() and s.inventory.slots==before and c.states.test.recipe.is_empty(),"new recipe disk failure restores materials and job")
 s.save_path="res://reports/food-v2/edge-save.json"
 check(c.act("test","cook","roast_potato").is_empty(),"new recipe can start after failed save")
 c.advance(12)
 for i in 40:s.inventory.slots[i]={"item_id":"stone","count":99}
 check(not c.act("test","claim").is_empty() and c.states.test.ready,"full bag preserves new cooked output")
 s.inventory.slots[8]={};check(c.act("test","claim").is_empty(),"new cooked output claim after space freed")
 var plot=s.builds.candidate("tilled_soil",w.player.position+Vector2(192,128),false,true,0)
 plot.crop="carrot";plot.growth_minutes=2880.0;s.builds.states.plot=plot
 s.planting.advance(14400)
 check(s.planting.stage(plot)==2 and not plot.roots,"mature crop does not wither after ten days")
 var snapshot=s.snapshot();snapshot.planting_cycle_version=2.5
 var f=FileAccess.open(s.save_path,FileAccess.WRITE);f.store_string(JSON.stringify(snapshot));f.close()
 s.load_state();check(not s.writable and s.builds.states.plot.growth_minutes==2880,"fractional cycle version protects source and state")
 var fail=checks.filter(func(v):return not v.pass)
 var report=FileAccess.open("res://reports/food-v2/edges.json",FileAccess.WRITE);report.store_string(JSON.stringify({"count":checks.size(),"failed":fail.size(),"checks":checks},"\t"));report.close()
 print("FOOD EDGES ",checks.size()," checks, ",fail.size()," failed")
 w.persistent_world=false;w.free();await process_frame;quit(0 if fail.is_empty() else 1)
