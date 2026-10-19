extends SceneTree
const OUT="res://reports/scissors-exploration-v1/"
var checks=[]
func check(ok:bool,label:String)->void:
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var expected=JSON.parse_string(FileAccess.get_file_as_string(OUT+"restart-expected.json"))
 Engine.set_meta("integration_seed",int(expected.seed))
 var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.set_process(false);w.player.set_physics_process(false);w.environment_view.set_process(false)
 var s=w.item_service;s.set_process(false);s.animals.set_physics_process(false)
 s.save_path=OUT+"restart-items.json";w.persistent_world=true
 s.load_state();w.restore_player_entry()
 check(s.writable and s.restored_player_position,"fresh process reads optional player position")
 check(w.player.position==Vector2(expected.position.x,expected.position.y) and s.body.hunger==73,"restart resumes exact exit position and body state")
 check(str(w.generator.sample(Vector2(expected.site.x,expected.site.y)))==expected.sample,"same Seed terrain unchanged across process restart")
 check(s.animals.states.has("fixture-sheep") and not s.animals.states["fixture-sheep"].wool,"saved animal retained without replacing world")
 check(s.builds.states.has("fixture-bench") and s.builds.states["fixture-bench"].kind=="workbench","saved construction retained across restart")
 var old=s.snapshot();old.erase("player_position")
 FileAccess.open(OUT+"legacy-items.json",FileAccess.WRITE).store_string(JSON.stringify(old))
 s.load_state(OUT+"legacy-items.json")
 check(s.writable and not s.restored_player_position,"older saves without position remain compatible")
 var invalid=old.duplicate(true);invalid.player_position={"x":"invalid","y":0}
 FileAccess.open(OUT+"invalid-items.json",FileAccess.WRITE).store_string(JSON.stringify(invalid))
 var before=w.player.position;s.load_state(OUT+"invalid-items.json")
 check(not s.writable and w.player.position==before,"invalid position protects original state")
 w.persistent_world=false
 for name in ["restart-items.json","restart-expected.json","legacy-items.json","invalid-items.json"]:DirAccess.remove_absolute(OUT+name)
 var result={"count":checks.size(),"failed":checks.filter(func(c):return not c.pass).size(),"checks":checks}
 FileAccess.open(OUT+"restart-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("SCISSORS RESTART: ",result.count," checks, ",result.failed," failed")
 w.free();await process_frame;quit(0 if result.failed==0 else 1)
