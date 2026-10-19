extends SceneTree
const OUT="res://reports/scissors-exploration-v1/"
var checks=[]
var w:Node
func check(ok:bool,label:String)->void:
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func _initialize()->void:call_deferred("run")
func frames(n=3)->void:
 for i in n:await process_frame
func snap(label:String)->void:
 await frames();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+label+".png")
func run()->void:
 DirAccess.make_dir_recursive_absolute(OUT)
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.set_process(false);w.environment_view.set_process(false);w.player.set_physics_process(false)
 var s=w.item_service;var a=s.animals;var p=w.player;var ui=w.item_ui
 s.set_process(false);a.set_physics_process(false)
 for id in a.visuals.keys():a.visuals[id].free()
 a.visuals.clear();a.states.clear()
 var site=a.find_near(p.position,35,52)
 check(site!=Vector2.INF,"safe nearby sheep location")
 a.states["fixture-sheep"]=a.make_row("sheep",site,true,false);a.sync_visuals()
 var sh=a.visuals["fixture-sheep"];sh.set_physics_process(false)
 var r=a.states["fixture-sheep"];r.fed_until=a.clock+10000;r.wool=true;r.product=0
 s.inventory.equipment.clear();p.update_animation()
 check(a.caption("fixture-sheep").is_empty(),"no animal approach hint without scissors")
 ui.update_target_tip(sh,.1);check(not ui.target_tip.visible,"blank animal caption creates no paper hint")
 s.inventory.equipment.main_hand=s.inventory.instance("shears");p.update_animation()
 check(s.database.item("shears").name=="剪刀","formal item renamed scissors")
 var tex=s.texture("shears","icon")
 check(tex is AtlasTexture and tex.region.size.y<140 and tex.region.size.x<90,"inventory and crafting share tight transparent-padding crop")
 check(a.action("fixture-sheep")=="shear" and a.caption("fixture-sheep")=="E 剪毛","equipped scissors expose E even while wool not ready")
 ui.update_target_tip(sh,.1);check(ui.target_tip.visible and ui.target_caption.text.contains("E 剪毛"),"actual approach hint appears after equipping without leaving animal")
 var old=s.inventory.equipment.main_hand.duplicate(true)
 check(not a.interact("fixture-sheep",sh) and s.inventory.equipment.main_hand==old and r.wool,"unready sheep cannot award wool or wear scissors")
 await snap("sheep-prompt")
 sh.hide();ui.target_tip.hide()
 s.inventory.hotbar_equipment["2"]=s.inventory.equipment.main_hand.instance_id;s.inventory.changed.emit()
 r.product=a.rules.wool_minutes
 for facing in ["front","back","left","right"]:
  for work in [false,true]:
   p.cancel_action();p.facing=facing;p.action="shear" if work else "";p.action_target=sh;p.action_clock=.42;p.update_animation()
   var tool=p.character.get_node("Visual/Pelvis/ArmR/HeldTool")
   var arm=tool.get_parent()
   check(is_equal_approx(tool.scale.x,.25) and tool.offset==Vector2(-128,-161),"larger scissors registered at actual handle "+facing+str(work))
   if facing=="front":check(not arm.show_behind_parent and tool.get_index()==0,"front hand and scissors before clothing; palm grips handle "+str(work))
   elif facing=="back":check(p.held_tool.rear_tool.visible and not tool.visible,"back scissors use shared layer behind legs "+str(work))
   else:check(tool.visible and not p.held_tool.rear_tool.visible,"side scissors restore native mirrored layer "+facing+str(work))
   await snap(facing+("-shear" if work else "-idle"))
 p.cancel_action();p.action="shear";p.action_target=sh;p.action_clock=.35;p.action_committed=false;p.input_blocked=false;p._physics_process(.03)
 check(p.action_succeeded and not r.wool and s.inventory.count_item("wool")==2,"real reach contact shears exactly once")
 check(s.inventory.equipment.main_hand.durability==old.durability-1,"shearing retains durability cost")
 var bench=s.builds.candidate("workbench",p.position+Vector2(96,120),false,false,0)
 s.builds.states["fixture-bench"]=bench;s.builds.install(w.stream.chunk_at(Vector2(bench.x,bench.y)))
 p.position=Vector2(bench.x,bench.y)+Vector2(0,36);p.camera.position_smoothing_enabled=false;p.camera.force_update_scroll()
 ui.toggle_craft("fixture-bench")
 var panel=ui.craft_panel
 check(panel.recipe_buttons.has("workbench_shears"),"normal workbench lists scissors recipe")
 if panel.recipe_buttons.has("workbench_shears"):
  panel.select_recipe("workbench_shears")
  var entry=panel.recipe_buttons.workbench_shears
  check(entry.icon==tex and entry.text.begins_with("剪刀 ×1"),"actual crafting option uses enlarged shared icon and new name")
  await snap("crafting-icon")
 ui.close_panels()
 p.position=site+Vector2(-30,0)
 p.cancel_action();s.inventory.equipment.clear();p.update_animation();ui.update_target_tip(sh,.1)
 check(not ui.target_tip.visible,"unequipping removes animal approach hint")
 s.inventory.slots[0]={"item_id":"broad_leaf","count":3};r.feed_at=a.clock
 check(a.feed_check("fixture-sheep",0,s.inventory.slots[0])=="它刚吃过，过一会儿再喂","cooldown notice hides game minutes")
 s.inventory.slots[1]={"item_id":"wild_berry","count":1}
 check(a.feed_check("fixture-sheep",1,s.inventory.slots[1])=="羊不喜欢你的食物","explicit wrong-food feedback retained")
 # Existing save identity is read only; test persistence uses an isolated report path.
 var identity=load("res://scripts/world.gd").new();identity.load_world_identity()
 var saved_seed=identity.world_seed;identity.load_world_identity()
 check(identity.world_seed==saved_seed and identity.persistent_world,"ordinary world identity reused on repeated startup reads")
 for n in [identity.object_root,identity.ui,identity.title,identity.hint,identity.debug_label,identity.loading_cover,identity.loading_label]:n.free()
 identity.free()
 s.save_path=OUT+"restart-items.json";w.persistent_world=true
 p.position=site+Vector2(-30,0);s.body.hunger=73
 check(s.save_state(),"isolated atomic save stores current player position")
 var disk=JSON.parse_string(FileAccess.get_file_as_string(s.save_path))
 check(Vector2(disk.player_position.x,disk.player_position.y)==p.position and disk.body.hunger==73,"position and player state share existing atomic snapshot")
 FileAccess.open(OUT+"restart-expected.json",FileAccess.WRITE).store_string(JSON.stringify({"seed":w.world_seed,"position":disk.player_position,"sample":str(w.generator.sample(site)),"site":{"x":site.x,"y":site.y}}))
 w.persistent_world=false
 var result={"count":checks.size(),"failed":checks.filter(func(c):return not c.pass).size(),"checks":checks}
 FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("SCISSORS EXPLORATION: ",result.count," checks, ",result.failed," failed")
 w.free();await process_frame;quit(0 if result.failed==0 else 1)
