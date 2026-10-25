extends "res://tests/sleep_v8_fixture.gd"
func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://reports/cooking-season-ui-v1")
 Engine.set_meta("integration_seed",271828);w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 s=w.item_service;v=w.environment_view;b=s.camps
 w.set_process(false);w.player.set_physics_process(false);s.set_process(false);v.set_process(false);s.combat_view.set_process(false)
 root.size=default_size();root.content_scale_size=root.size
 var ui=w.camp_ui
 check(not w.persistent_world,"isolated world no player writes")
 var body: Dictionary=s.body.serialize();var hour: float=v.simulation.minute;var initial: int=v.simulation.season_date().index
 for i in 4:
  v.debug_next_season();check(v.simulation.season_date().index==(initial+i+1)%4,"F4 next season "+str(i))
 check(v.simulation.minute==hour and s.body.serialize()==body,"debug season jump no body time or hour advancement")
 check(v.panel.find_children("*","Button",true,false).any(func(n):return n.text.contains("切换四季")),"actual F4 button exists")
 for i in 40:s.inventory.slots[i]={}
 for id in ["brown_mushroom","cabbage","wild_berry","wildflower","wild_carrot","broad_leaf"]:s.inventory.add(id,10)
 s.inventory.add("roasted_carrot",2)
 var at: Vector2=w.player.position+Vector2(0,50)
 b.states.clear();b.states["test"]={"x":at.x,"y":at.y,"fuel":1000.0,"lit":true,"recipe":"","elapsed":0.0,"ready":false};b.rebuild();b.install(w.stream.chunk_at(at))
 var combo={"brown_mushroom":1,"cabbage":1,"wild_berry":1,"wildflower":1}
 check(b.experiment_recipe(combo)=="camp_large_hodgepodge","screenshot ingredients resolve large hodgepodge")
 check(b.experiment_recipe({"wildflower":1})=="camp_small_hodgepodge","small arbitrary combination fallback")
 check(b.experiment_recipe({"wild_carrot":1})=="roast_carrot","exact known recipe retains priority")
 check(b.experiment_recipe({"broad_leaf":2,"brown_mushroom":1})=="herb_mushroom","exact herb recipe unchanged")
 for invalid in [{},{"stone":1},{"wildflower":0},{"wildflower":1.5},{"wildflower":100}]:check(b.experiment_recipe(invalid)=="","reject invalid experiment "+str(invalid))
 check(s.industry.recipe("copper_oven","camp_small_hodgepodge").is_empty(),"camp fallback cannot become free oven recipe")
 check(b.experiment_recipe({"wildflower":1.0})=="camp_small_hodgepodge","integral JSON float accepted")
 ui.open("test");ui.mode="free";ui.ingredient_ids.assign(["brown_mushroom","cabbage","wild_berry","wildflower"]);ui.ingredient_counts.assign([1,1,1,1]);ui.last_detail="";ui.refresh()
 check(not ui.cook_button.disabled,"real free cook button enabled")
 check(not v.dial.is_visible_in_tree() and not v.season_dial.is_visible_in_tree(),"cooking hides both clock and season")
 var choice: OptionButton=ui.ingredient_choices[0];var popup: PopupMenu=choice.get_popup();popup.popup(Rect2i(140,250,240,300));await frames(3);popup.set_focused_item(1)
 var sig: String=ui.last_detail
 var passive_before: String=JSON.stringify(s.inventory.slots)
 for i in 80:
  for slot in s.inventory.slots:
   if not slot.is_empty() and slot.has("spoilage"):slot.spoilage+=.000001
  ui.refresh()
  check(ui.last_detail==sig and popup.get_focused_item()==1 and popup.visible,"popup hover stable despite freshness tick "+str(i))
  await process_frame
 check(JSON.stringify(s.inventory.slots)!=passive_before,"passive cooked-food freshness actually changed during hover")
 popup.hide()
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/cooking-season-ui-v1/free-ready.png")
 var before: Array=s.inventory.slots.duplicate(true)
 w.persistent_world=true;var old_path: String=s.save_path;s.save_path="res://reports/cooking-season-ui-v1/missing/save.json"
 check(not b.act("test","experiment","",combo).is_empty() and before==s.inventory.slots and b.states.test.recipe.is_empty(),"failed start save rolls ingredients and task back")
 w.persistent_world=false;s.save_path=old_path
 ui.command("cook");check(b.states.test.recipe=="camp_large_hodgepodge","actual UI starts fallback")
 for id in combo:check(s.inventory.count_item(id)==9,"actual selected ingredient deducted "+id)
 before=s.inventory.slots.duplicate(true);check(not b.act("test","experiment","",combo).is_empty() and before==s.inventory.slots,"double start cannot double consume")
 b.states.test.lit=false;b.burning.clear();b.advance(30);check(b.states.test.elapsed==0,"unlit fallback pauses")
 b.states.test.lit=true;b.rebuild();b.advance(18);check(b.states.test.ready and b.validate(JSON.parse_string(JSON.stringify(b.serialize()))),"fallback ready and saved task validates")
 check(not b.discovered.has("camp_large_hodgepodge"),"fallback not recorded as invented recipe")
 check(b.act("test","claim").is_empty() and s.inventory.count_item("large_hodgepodge")==1,"fixed fallback output claim")
 check(not b.act("test","claim").is_empty() and s.inventory.count_item("large_hodgepodge")==1,"repeat claim rejected")
 ui.close_panel();check(v.dial.is_visible_in_tree() and v.season_dial.is_visible_in_tree(),"both dials restore on close")
 v.dial.hide();check(not v.season_dial.is_visible_in_tree(),"season inherits clock visibility for every UI")
 v.dial.show();check(v.season_dial.get_parent()==v.dial,"same canvas and visibility subtree")
 var failed: Array=checks.filter(func(c):return not c.pass)
 var f=FileAccess.open("res://reports/cooking-season-ui-v1/results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"\t"));f.close()
 print("COOKING_SEASON_UI ",checks.size()," checks ",failed.size()," failed")
 w.queue_free();await frames();quit(1 if not failed.is_empty() else 0)
