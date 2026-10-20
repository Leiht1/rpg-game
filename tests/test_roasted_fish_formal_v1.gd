extends SceneTree
var checks=[]
func check(ok,label):
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func _initialize():call_deferred("run")
func run():
 Engine.set_meta("integration_seed",271828)
 var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
 var s=w.item_service;s.set_process(false)
 var names=["roasted_fish"]
 var provenance=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cooking/fish-v1/provenance.json"))
 for id in names:
  var path="res://assets/cooking/fish-v1/"+id+".png"
  var d=s.database.item(id)
  check(d.icon==path and d.world_visual==path,"formal icon and world reference "+id)
  check(FileAccess.get_sha256(path)==provenance.candidate_sha256,"approved hash "+id)
  check(s.texture(id,"icon")!=null and s.texture(id,"world")!=null and s.texture(id,"loose")!=null,"inventory world and loose texture load "+id)
 check(not s.preview,"ordinary formal mode without art switch")
 var at=w.player.position+Vector2(0,50)
 s.camps.states.test={"x":at.x,"y":at.y,"fuel":500.0,"lit":true,"recipe":"","elapsed":0.0,"ready":false};s.camps.rebuild()
 w.camp_ui.open("test")
 for recipe in ["roast_fish"]:
  s.camps.discovered[recipe]=true;w.camp_ui.selected=recipe;w.camp_ui.last_detail="";w.camp_ui.refresh()
  check(w.camp_ui.recipes[w.camp_ui.recipe_keys.find(recipe)].icon!=null,"formal recipe card icon "+recipe)
 var failed=checks.filter(func(v):return not v.pass)
 var f=FileAccess.open("res://reports/roasted-fish-formal-v1/checks.json",FileAccess.WRITE);f.store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"));f.close()
 print("FORMAL FOOD: ",checks.size()," checks, ",failed.size()," failed")
 w.free();await process_frame;quit(0 if failed.is_empty() else 1)
