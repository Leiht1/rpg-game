extends SceneTree
var w: Node
var checks=[]
func check(ok: bool,label: String):
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func _initialize():call_deferred("run")
func frames(n=3):
 for i in n:await process_frame
func shot():
 await frames();await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run():
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.environment_view.set_process(false);w.set_process(false);w.player.set_physics_process(false)
 while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
 var s=w.item_service;var e=w.environment_view;s.set_process(false)
 s.body.hunger=50;s.body.eat({"hallucination":true});e.simulation.paused=true
 var at=w.player.position+Vector2(0,50)
 s.camps.states.test={"x":at.x,"y":at.y,"fuel":500.0,"lit":true,"recipe":"","elapsed":0.0,"ready":false};s.camps.rebuild()
 w.camp_ui.open("test");w.camp_ui.selected="roast_potato";w.camp_ui.refresh()
 e._process(.3);check(e.hallucination_visual>0 and e.hallucination_visual<float(s.body.rules.hallucination_strength),"smooth visual onset")
 e._process(2.0)
 var distorted=await shot();distorted.save_png("res://reports/food-v2/hallucination-book.png")
 e.material_effect.set_shader_parameter("hallucination",0.0)
 var normal=await shot();normal.save_png("res://reports/food-v2/normal-book.png")
 check(distorted.get_region(Rect2i(150,95,975,505)).get_data()==normal.get_region(Rect2i(150,95,975,505)).get_data(),"GPU book labels and panel pixel identical")
 check(distorted.get_region(Rect2i(0,220,120,300)).get_data()!=normal.get_region(Rect2i(0,220,120,300)).get_data(),"GPU world distortion visible")
 w.camp_ui.close_panel();s.body.hallucination_remaining=0;e._process(.3)
 check(e.hallucination_visual>0,"smooth visual exit")
 e._process(3.0);check(e.hallucination_visual==0,"effect clears")
 check(e.layer<w.ui.layer,"world effect below all inventory HUD layers")
 var fail=checks.filter(func(c):return not c.pass)
 var f=FileAccess.open("res://reports/food-v2/visual.json",FileAccess.WRITE);f.store_string(JSON.stringify({"count":checks.size(),"failed":fail.size(),"checks":checks},"\t"));f.close()
 print("FOOD VISUAL ",checks.size()," checks, ",fail.size()," failed")
 w.free();await process_frame;quit(0 if fail.is_empty() else 1)
