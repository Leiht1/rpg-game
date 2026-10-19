extends SceneTree
const OUT="res://reports/shear-sign-map-v1/"
var checks=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func frames(n=3)->void:
 for i in n:await process_frame
func capture()->Image:
 await frames();await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run()->void:
 DirAccess.make_dir_recursive_absolute(OUT)
 Engine.set_meta("integration_seed",271828)
 var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.set_process(false);w.environment_view.set_process(false);w.player.set_physics_process(false)
 var s=w.item_service;var p=w.player;s.set_process(false);s.animals.set_physics_process(false)
 for n in s.animals.visuals.values():n.hide();n.set_physics_process(false)
 s.inventory.equipment.main_hand=s.inventory.instance("shears");s.inventory.hotbar_equipment["0"]=s.inventory.equipment.main_hand.instance_id;s.inventory.changed.emit()
 var arm=p.character.get_node("Visual/Pelvis/ArmR")
 var visual=p.character.get_node("Visual")
 var before=s.inventory.equipment.main_hand.duplicate(true)
 # All gesture phases, including an immediate facing change before first sampling.
 for facing in ["front","back","left","right"]:
  for time in [.10,.36,.42,.65]:
   p.facing=facing;p.action="shear";p.action_clock=time;p.update_animation()
   var tool:Sprite2D=arm.get_node("HeldTool")
   var source:Sprite2D=p.held_tool.rear_tool if facing=="back" else tool
   var tip:Vector2=source.to_global(source.offset+Vector2(128,75))
   var handle:Vector2=source.to_global(source.offset+Vector2(128,161))
   var wanted:Vector2={"front":Vector2.DOWN,"back":Vector2.UP,"left":Vector2.LEFT,"right":Vector2.RIGHT}[facing]
   check(handle.direction_to(tip).dot(wanted)>.999,"blade points forward after actual arm and mirror transforms %s %.2f"%[facing,time])
   if is_equal_approx(time,.42):(await capture()).save_png(OUT+facing+"-shear.png")
  p.cancel_action();p.facing=facing;p.update_animation()
  var tool:Sprite2D=arm.get_node("HeldTool")
  check(is_equal_approx(tool.rotation,deg_to_rad(40)-p.held_tool.stance_offset),"idle angle restored "+facing)
 check(s.inventory.equipment.main_hand==before,"pose previews do not consume durability")
 # Other registered tools retain their sampled rotation policy.
 s.inventory.equipment.main_hand=s.inventory.instance("stone_pickaxe");p.action="mine";p.action_clock=.4;p.facing="right";p.update_animation()
 var tool:Sprite2D=arm.get_node("HeldTool")
 check(is_equal_approx(tool.rotation,arm.get_node("Grip").rotation),"existing pickaxe pose unchanged")
 p.cancel_action();p.update_animation()
 var ui=w.camp_ui;var field=ui.sign_input
 var inventory=s.inventory.slots.duplicate(true);var buildings=s.builds.serialize()
 ui.sign_dialog.popup_centered();field.grab_focus();field.text="原野";field.select_all()
 check(["normal","focus","read_only"].all(func(state):return field.get_theme_stylebox(state) is StyleBoxEmpty),"sign input has no normal/focus/read-only fill")
 check(field.get_theme_color("selection_color").a==0,"selected sign text has no green backing")
 (await capture()).save_png(OUT+"sign-selected.png")
 var event=InputEventKey.new();event.pressed=true;event.unicode="营".unicode_at(0)
 ui.sign_dialog.push_input(event);await frames()
 check(field.text=="营" and not ui.sign_dialog.get_ok_button().disabled,"native text input replaces selection and retains validation")
 (await capture()).save_png(OUT+"sign-typing.png")
 event=InputEventKey.new();event.pressed=true;event.keycode=KEY_BACKSPACE;event.physical_keycode=KEY_BACKSPACE
 ui.sign_dialog.push_input(event);await frames()
 check(field.text.is_empty() and ui.sign_dialog.get_ok_button().disabled,"empty name still cannot submit")
 field.text="1234567";check(field.text.length()==6,"six-character limit unchanged")
 ui.cancel_sign();await frames()
 check(s.inventory.slots==inventory and s.builds.serialize()==buildings,"cancel typing does not consume or build")
 var sign=s.builds.candidate("signpost",p.position+Vector2(80,50),false,false,0);sign.text="原野"
 s.builds.states["fixture-sign"]=sign
 var map=w.map_view
 map.open_map()
 while map.row<map.resolution:await process_frame
 map.set_process(false);map.queue_redraw()
 var a:Image=await capture();a.save_png(OUT+"map.png")
 var original_spawn=w.generator.spawn
 w.generator.spawn=Vector2(w.generator.extent*.25,w.generator.extent*.75);map.queue_redraw()
 var b:Image=await capture()
 check(a.get_data()==b.get_data(),"GPU map is identical when hidden spawn changes; no marker or label remains")
 w.generator.spawn=original_spawn
 check(s.builds.map_signposts().size()==1 and s.builds.map_signposts()[0].text=="原野","player-created signposts remain on map")
 event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_WHEEL_UP;event.pressed=true;event.position=map.map_rect.get_center();map._input(event)
 check(is_equal_approx(map.zoom,1.25),"map zoom unchanged")
 map.close_map();check(not map.visible,"map closes normally")
 var result={"count":checks.size(),"failed":checks.filter(func(c):return not c.pass).size(),"checks":checks}
 FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("SHEAR SIGN MAP: ",result.count," checks, ",result.failed," failed")
 w.persistent_world=false;w.free();await process_frame;quit(0 if result.failed==0 else 1)
