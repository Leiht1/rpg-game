extends "res://tests/test_campfire_drag_v1.gd"
var a:Node
var animal:Node2D
var feed_id="drag-feed"
const FEED_OUT="res://reports/animal-drag-feed-v1/"
func drag(index:int,target:Vector2,_bag_drag:bool=false)->void:
 var source:Vector2=ui.cells[index].get_global_rect().get_center()
 await motion(source);await button(source,true);await motion(source+Vector2(30,0),true)
 check(root.gui_is_dragging(),"native drag begins from slot "+str(index))
 await motion(target,true);await button(target,false)
func payload(index:int)->Dictionary:
 var row:Dictionary=service.inventory.slots[index]
 return {"inventory":service.inventory,"slot":index,"item_id":row.item_id,"count":row.count,"snapshot":row.duplicate(true)}
func shot(label:String)->void:
 await frames();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(FEED_OUT+label+".png")
func run()->void:
 Engine.max_fps=60;Engine.set_meta("integration_seed",271828)
 world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
 while not world.started:await process_frame
 world.set_process(false);world.environment_view.set_process(false);world.player.set_physics_process(false)
 service=world.item_service;service.set_process(false);ui=world.item_ui;a=service.animals;a.set_physics_process(false)
 service.notice.connect(func(message):notices.append(message))
 while not world.stream.viewport_ready(world.player.position,Vector2(640,360)):await process_frame
 for v in a.visuals.values():v.free()
 a.visuals.clear();a.states.clear();a.spawning.next_at=1e12
 at=a.find_near(world.player.position,35,55)
 check(at!=Vector2.INF,"safe nearby real animal site")
 a.states[feed_id]=a.make_row("sheep",at);a.sync_visuals();animal=a.visuals[feed_id];animal.set_physics_process(false)
 world.player.camera.position_smoothing_enabled=false;world.player.camera.force_update_scroll();await frames(5)
 for i in 40:service.inventory.slots[i]={}
 service.inventory.slots[0]={"item_id":"broad_leaf","count":8};service.inventory.selected=0;service.inventory.changed.emit()
 check(not a.interact(feed_id,animal) and service.inventory.slots[0].count==8 and a.states[feed_id].trust==0,"E no longer feeds selected food")
 check(a.caption(feed_id).is_empty(),"feeding remains discoverable without approach tutorial")
 var target:Vector2=root.get_canvas_transform()*(animal.position+Vector2(0,-32))
 check(a.target_at(animal.position+Vector2(0,-32))==feed_id,"drop target uses actual rendered body")
 await drag(0,target)
 check(world.player.action=="feed" and world.player.animal_feed.hand=="right","native hotbar drag starts feed reach")
 check(service.inventory.slots[0].count==8 and a.states[feed_id].trust==0 and not ui.item_modal_open(),"stack feed one without quantity dialog or early debit")
 world.player._physics_process(.40);await shot("reach-right")
 check(str(world.player.animation_player.current_animation).begins_with("camp/") and is_instance_valid(world.player.animal_feed.food),"food visible in hand during native reach")
 world.player._physics_process(.16)
 check(service.inventory.slots[0].count==7 and a.states[feed_id].trust==1 and animal.feedback>0,"contact commits exactly one food, trust and animal nod")
 world.player._physics_process(.1);check(service.inventory.slots[0].count==7,"contact cannot commit twice")
 world.player._physics_process(.4)
 check(world.player.action.is_empty() and world.player.animal_feed.food==null,"recovery clears temporary food")
 var loose_before=service.loose.duplicate(true)
 ui.drop_on_ground(payload(0),target)
 check(world.player.action.is_empty() and service.inventory.slots[0].count==7,"cooldown rejects repeat without eating")
 service.inventory.slots[1]={"item_id":"wild_berry","count":3};service.inventory.changed.emit()
 await drag(1,target);await shot("wrong-food")
 check(ui.message.text=="羊不喜欢你的食物" and service.inventory.slots[1].count==3 and service.loose==loose_before,"wrong sheep food gives exact notice without discard")
 a.states[feed_id].feed_at=a.clock-30
 service.inventory.slots[8]={"item_id":"wild_carrot","count":4};service.inventory.changed.emit();ui.toggle_bag();await frames()
 await drag(8,target,true)
 check(world.player.action=="feed" and ui.bag.visible,"native bag drag restores bag while feeding")
 world.player._physics_process(.56);world.player._physics_process(.4)
 check(service.inventory.slots[8].count==3 and a.states[feed_id].trust==2,"bag source feeds exactly one")
 ui.close_panels();a.states[feed_id].feed_at=a.clock-30
 ui.drop_on_ground(payload(0),target);world.player.cancel_action()
 check(service.inventory.slots[0].count==7 and a.states[feed_id].trust==2,"cancel before contact has no debit")
 ui.drop_on_ground(payload(0),target);service.inventory.slots[0].count=6;world.player._physics_process(.56);world.player.cancel_action()
 check(service.inventory.slots[0].count==6 and a.states[feed_id].trust==2,"changed source snapshot refuses contact")
 ui.drop_on_ground(payload(0),target);var original:Vector2=animal.position;animal.position+=Vector2(220,0);world.player._physics_process(.56);world.player.cancel_action();animal.position=original
 check(service.inventory.slots[0].count==6 and a.states[feed_id].trust==2,"animal out of reach cancels contact")
 var prior=a.states[feed_id].duplicate(true);service.save_path=FEED_OUT+"missing/fail.json";world.persistent_world=true
 ui.drop_on_ground(payload(0),target);world.player._physics_process(.56);world.player.cancel_action();world.persistent_world=false
 check(service.inventory.slots[0].count==6 and a.states[feed_id]==prior,"failed atomic save restores food and all animal fields")
 service.inventory.slots[2]=service.inventory.instance("stone_pickaxe");service.inventory.equip(2)
 ui.drop_on_ground(payload(0),target)
 check(world.player.action=="feed" and world.player.animal_feed.hand=="left","equipped tool leaves feeding to free left hand")
 world.player._physics_process(.40);await shot("reach-left")
 world.player._physics_process(.16);world.player._physics_process(.4)
 check(service.inventory.slots[0].count==5 and a.states[feed_id].trust==3,"left hand commits normal feed")
 for n in 2:
  a.states[feed_id].feed_at=a.clock-30;ui.drop_on_ground(payload(0),target);world.player._physics_process(.56);world.player._physics_process(.4)
 check(a.states[feed_id].tamed and a.states[feed_id].trust==5,"five spaced drag feeds tame sheep")
 check(a.interact(feed_id,animal) and a.states[feed_id].mode=="follow" and service.inventory.slots[0].count==3,"E switches follow even with food selected, without consuming")
 check(a.interact(feed_id,animal) and a.states[feed_id].mode=="stay","E still switches stay")
 var saved=a.serialize();check(a.valid(saved),"trust and feeding fields keep existing save schema")
 a.restore(saved);a.sync_visuals();animal=a.visuals[feed_id];animal.set_physics_process(false);await frames(3);check(a.states[feed_id].trust==5 and a.states[feed_id].fed_until>a.clock,"snapshot restore retains feeding and tame progress")
 # Food checks are independent of selected hotbar, including juvenile chickens.
 a.states[feed_id].species="chicken";a.states[feed_id].trust=0;a.states[feed_id].tamed=false;a.states[feed_id].feed_at=a.clock-30
 check(a.feed_check(feed_id,0,service.inventory.slots[0])=="鸡不喜欢你的食物","chicken wrong food has species-specific notice")
 var chicken_reason:String=a.feed(feed_id,1,service.inventory.slots[1].duplicate(true))
 check(chicken_reason.is_empty() and service.inventory.slots[1].count==2,"chicken accepts dragged berries regardless of selected slot")
 for facing in ["front","back","left","right"]:
  a.states[feed_id].feed_at=a.clock-30
  var start_reason:String=world.player.animal_feed.start(world.player,feed_id,1,service.inventory.slots[1].duplicate(true))
  world.player.facing=facing;world.player.action_clock=.40;world.player.update_animation()
  check(start_reason.is_empty() and str(world.player.animation_player.current_animation)=="camp/%s_throw_left"%("side" if facing in ["left","right"] else facing),"native directional free-hand feed pose "+facing)
  world.player.cancel_action()
 check(service.inventory.slots[1].count==2,"four directional cancelled poses do not consume")
 service.save_path=FEED_OUT+"isolated-items.json";world.persistent_world=true
 check(a.feed(feed_id,1,service.inventory.slots[1].duplicate(true)).is_empty(),"feed commits to isolated atomic file")
 var disk=JSON.parse_string(FileAccess.get_file_as_string(service.save_path))
 check(disk.animals.objects[feed_id].trust==2 and disk.slots[1].count==1,"disk snapshot stores food debit and trust together")
 world.persistent_world=false;DirAccess.remove_absolute(service.save_path)
 var result={"count":checks.size(),"failed":checks.filter(func(c):return not c.pass).size(),"checks":checks}
 var f=FileAccess.open(FEED_OUT+"results.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
 print("ANIMAL DRAG FEED: ",result.count," checks, ",result.failed," failed")
 world.persistent_world=false;world.free();await process_frame;quit(0 if result.failed==0 else 1)
