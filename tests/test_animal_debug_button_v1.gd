extends SceneTree
const OUT="res://reports/animal-debug-button-v1/"
var checks=[]
func check(ok:bool,label:String)->void:
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func _initialize()->void:call_deferred("run")
func frames(n=3)->void:
 for i in n:await process_frame
func click(button:Control)->void:
 var p=button.get_global_rect().get_center()
 var motion=InputEventMouseMotion.new();motion.position=p;root.push_input(motion)
 var event=InputEventMouseButton.new();event.position=p;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;root.push_input(event)
 await frames(2)
 event=InputEventMouseButton.new();event.position=p;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false;root.push_input(event)
 await frames(3)
func run()->void:
 Engine.set_meta("integration_seed",271828)
 var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 var s=w.item_service;var a=s.animals
 w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false);s.set_process(false);a.set_physics_process(false)
 while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
 for n in a.visuals.values():n.free()
 a.visuals.clear();a.states.clear()
 a.ensure_population()
 var scheduler=a.spawning.duplicate(true);var before=a.states.size()
 var event=InputEventKey.new();event.physical_keycode=KEY_F6;event.pressed=true;root.push_input(event)
 await frames(4)
 var button=w.item_ui.catalog.find_child("SpawnAnimal",true,false)
 check(w.item_ui.catalog.visible and button!=null and button.is_visible_in_tree(),"F6 exposes nearby animal +1 button")
 check(Rect2(Vector2.ZERO,Vector2(1280,720)).encloses(w.item_ui.catalog.get_global_rect()),"existing debug panel fits default window")
 await click(button)
 check(a.states.size()==before+1 and a.states.has("debug:animal:1"),"real GUI click adds exactly one animal")
 check(a.states["debug:animal:1"].species=="chicken" and not a.states["debug:animal:1"].tamed,"first debug animal is wild chicken")
 var first=a.visuals.get("debug:animal:1")
 if first:first.set_physics_process(false)
 check(first!=null and first.position.distance_to(w.player.position)<=128,"spawned animal visible near player")
 await click(button)
 check(a.states.size()==before+2 and a.states["debug:animal:2"].species=="sheep","second click adds one sheep")
 if a.visuals.has("debug:animal:2"):a.visuals["debug:animal:2"].set_physics_process(false)
 check(a.spawning==scheduler,"debug clicks preserve initial quota natural sequence and seven-day deadline")
 for id in ["debug:animal:1","debug:animal:2"]:
  var r=a.states[id]
  check(a.nearby_path(w.player.position,a.point(r)) and w.stream.has_ground(a.point(r)),"safe reachable ground "+id)
 root.get_texture().get_image().save_png(OUT+"button.png")
 w.item_ui.close_panels();await frames(3)
 check(not w.item_ui.catalog.visible and not w.player.input_blocked,"closing debug panel restores input")
 root.get_texture().get_image().save_png(OUT+"nearby.png")
 var saved_count=a.states.size();s.writable=false
 check(not a.debug_spawn_near() and a.states.size()==saved_count,"protected save refuses debug spawning")
 s.writable=true;var p=w.player.position;w.player.position=Vector2(-1000,-1000)
 check(not a.debug_spawn_near() and a.states.size()==saved_count,"unsafe unloaded ground refuses without additions")
 w.player.position=p;w.persistent_world=true;s.save_path=OUT+"missing/fail.json"
 check(not a.debug_spawn_near() and a.states.size()==saved_count and not a.states.has("debug:animal:3"),"failed atomic save removes tentative animal")
 s.save_path=OUT+"isolated.json"
 check(a.debug_spawn_near() and a.states.size()==saved_count+1,"successful debug spawn saves one animal")
 s.load_state()
 check(s.writable and a.states.size()==saved_count+1 and a.states.has("debug:animal:3") and JSON.parse_string(JSON.stringify(a.spawning))==JSON.parse_string(JSON.stringify(scheduler)),"reload preserves debug animal and natural scheduler")
 var failed=checks.filter(func(c):return not c.pass)
 var f=FileAccess.open(OUT+"native.json",FileAccess.WRITE);f.store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"));f.close()
 print("ANIMAL DEBUG BUTTON: ",checks.size()," checks, ",failed.size()," failed")
 w.free();await process_frame;quit(0 if failed.is_empty() else 1)
