extends "res://tests/sleep_v8_fixture.gd"
const OUT_FORMAL="res://reports/weather-formal-v1/"
func capture_formal(label: String) -> void:
 if DisplayServer.get_name()=="headless":return
 w.player.reset_physics_interpolation();w.player.character.reset_physics_interpolation()
 await frames(4);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT_FORMAL+label+".png")
func run() -> void:
 Engine.set_meta("weather_preview",false);Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 s=w.item_service;v=w.environment_view;b=s.builds
 w.set_process(false);w.player.set_physics_process(false);s.set_process(false);v.set_process(false);s.combat_view.set_process(false)
 root.size=default_size();root.content_scale_size=root.size
 while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
 check(not w.persistent_world and not Engine.get_meta("weather_preview"),"normal rules with isolated saves")
 b.states.clear();b.refresh_all();stock();s.inventory.add("broad_leaf",30)
 for id in ["rain_umbrella","rain_shelter"]:
  var path: String=s.database.item(id).icon
  check(path.begins_with("res://assets/weather/v1/") and s.texture(id,"icon")!=null,"formal icon "+id)
  var source: String="res://prototypes/weather-v1/"+("umbrella" if id=="rain_umbrella" else "shelter")+".png"
  check(FileAccess.get_sha256(path)==FileAccess.get_sha256(source),"approved bytes retained "+id)
 w.item_ui.toggle_craft();await frames()
 check(w.item_ui.craft_panel.recipe_buttons.has("hand_rain_umbrella"),"normal C crafting list shows umbrella")
 w.item_ui.craft_panel.select_recipe("hand_rain_umbrella");await capture_formal("craft-list")
 w.item_ui.toggle_build();await frames()
 check(w.item_ui.craft_panel.recipe_buttons.has("build_rain_shelter"),"normal V build list shows shelter")
 w.item_ui.craft_panel.select_recipe("build_rain_shelter");await capture_formal("build-list")
 w.item_ui.close_panels()
 check(s.craft("hand_rain_umbrella",1,s.new_craft_request()).is_empty() and s.inventory.count_item("rain_umbrella")==1,"normal actual umbrella craft")
 s.inventory.equipment.main_hand=s.inventory.instance("rain_umbrella");s.inventory.changed.emit()
 w.player.position=w.generator.spawn+Vector2(-240,0)
 v.simulation.blend=Vector3(0,0,1)
 var p=w.player
 for facing in ["front","back","left","right"]:
  p.facing=facing;p.action="pickup";p.harvesting=false;p.action_succeeded=true;p.carried_wood.texture=s.texture("wood","icon")
  p.carried_wood.scale=Vector2.ONE*.25
  var angles: Array=[]
  for time in [0.0,.18,.36,.52,.68]:
   p.action_clock=time;p.update_animation()
   var right: Node2D=p.character.get_node("Visual/Pelvis/ArmR")
   var left: Node2D=p.character.get_node("Visual/Pelvis/ArmL")
   var tool: Sprite2D=left.get_node("HeldTool")
   var visible_tool: Sprite2D=p.held_tool.canopy
   check(is_instance_valid(visible_tool) and visible_tool.visible and visible_tool.texture.resource_path.begins_with("res://assets/weather/v1/"),"umbrella persists "+facing+str(time))
   check(p.character.get_node("Visual/ArmLBehind").visible and (not is_instance_valid(p.held_tool.front_free_hand) or not p.held_tool.front_free_hand.visible),"one visible free pickup arm "+facing+str(time))
   check(p.carried_wood.get_parent()==right.get_node("Grip"),"item follows original right palm "+facing+str(time))
   check(preload("res://scripts/weather_exposure.gd").sample(s).umbrella,"rain protection through pickup "+facing+str(time))
   angles.append(right.rotation)
   if is_equal_approx(time,.36):await capture_formal("pickup-"+facing)
  check(absf(float(angles[0])-float(angles[2]))>.2,"original right arm actually reaches "+facing)
  p.cancel_action();p.update_animation()
  check(p.carried_wood.get_parent()==p.character.get_node("Visual/Pelvis/ArmR/Grip") and (not is_instance_valid(p.held_tool.front_free_hand) or not p.held_tool.front_free_hand.visible),"pickup completes and releases left arm "+facing)
 # Run original pickup physics/transaction, not just posed frames.
 w.item_ui.update_input_block();p.input_blocked=false;p.automated=true;p.facing="right"
 var id:="formal-weather:drop";var at: Vector2=p.position+Vector2(16,0)
 var row: Dictionary={"id":id,"item_id":"wood","count":1,"x":at.x,"y":at.y,"mode":"pickup"}
 s.loose[id]=row;var drop: Node2D=w.stream.create_item_drop(row);await frames()
 var old: int=s.inventory.count_item("wood")
 p.action="pickup";p.action_target=drop;p.action_clock=0;p.action_committed=false;p.action_succeeded=false;p.harvesting=false
 for i in 6:p._physics_process(.13)
 check(s.inventory.count_item("wood")==old+1 and s.consumed.has(id),"real pickup yields exactly one item")
 check(p.action.is_empty() and s.inventory.equipment.main_hand.item_id=="rain_umbrella","real pickup finishes with umbrella equipped")
 s.inventory.equipment.main_hand=s.inventory.instance("stone_axe");p.action="pickup";p.action_clock=.3;p.update_animation()
 check(not p.character.get_node("Visual/Pelvis/ArmR/HeldTool").visible and not p.held_tool.canopy.visible,"ordinary tool pickup unchanged")
 p.cancel_action();p.update_animation()
 var site: Dictionary={}
 for yy in range(-3,4):
  for xx in range(-3,4):
   var spot: Vector2=w.generator.spawn+Vector2(xx*96,yy*64);p.position=spot+Vector2(0,120)
   var candidate: Dictionary=b.candidate("rain_shelter",spot,false,true,0)
   if b.reason(candidate).is_empty():site=candidate;break
  if not site.is_empty():break
 check(not site.is_empty() and b.place(site,s.inventory.slots.duplicate(true)).is_empty(),"normal actual formal shelter build")
 await frames();await capture_formal("formal-shelter")
 var failed: int=checks.filter(func(c):return not c.pass).size()
 FileAccess.open(OUT_FORMAL+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
 print("WEATHER FORMAL ",checks.size()," checks ",failed," failures")
 w.queue_free();await frames(4);quit(1 if failed else 0)
