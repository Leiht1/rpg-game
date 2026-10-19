extends RefCounted
## Session-only reach gesture; debit/trust share the existing atomic animal snapshot.
var player:Node2D
var manager:Node
var animal_id=""
var slot=-1
var snapshot:Dictionary={}
var hand="right"
var equipped=""
var attempted=false
var committed=false
var food:Sprite2D
var layer:Node2D
func equipment_id()->String:
 return str(player.equipment_inventory.equipment.get("main_hand",{}).get("instance_id",""))
func start(owner_player:Node2D,id:String,index:int,data:Dictionary)->String:
 if not owner_player.action.is_empty():return "请等待当前动作结束"
 player=owner_player;manager=player.stream.items.animals
 var reason:String=manager.feed_check(id,index,data)
 if not reason.is_empty():return reason
 animal_id=id;slot=index;snapshot=data.duplicate(true);equipped=equipment_id()
 hand="left" if not equipped.is_empty() else "right"
 var offset:Vector2=manager.visuals[id].position-player.position
 player.facing=("right" if offset.x>0 else "left") if absf(offset.x)>=absf(offset.y) else ("front" if offset.y>0 else "back")
 attempted=false;committed=false;player.action="feed";player.action_clock=0.0
 player.action_target=manager.visuals[id];player.action_committed=false;player.action_succeeded=false
 player.moving=false;player.running=false
 food=Sprite2D.new();food.name="AnimalFeedFood";food.texture=manager.service.texture(str(data.item_id),"icon")
 if food.texture:food.scale=Vector2.ONE*16.0/maxf(1,food.texture.get_width())
 layer=Node2D.new();layer.name="AnimalFeedHandLayer";layer.position=Vector2(0,maxf(player.position.y,player.action_target.position.y)+.5)
 player.get_parent().add_child(layer);layer.add_child(food)
 player.update_animation()
 return ""
func advance(delta:float)->void:
 if equipment_id()!=equipped or not manager.visuals.has(animal_id) or not is_instance_valid(player.action_target) or manager.visuals[animal_id]!=player.action_target or manager.service.body.down or manager.service.body.sleep_active():
  player.cancel_action();return
 player.action_clock+=delta
 if not attempted and player.action_clock>=.55:
  attempted=true
  var reason:String=manager.feed(animal_id,slot,snapshot)
  committed=reason.is_empty();player.action_committed=true;player.action_succeeded=committed
  if not committed:manager.service.notice.emit(reason)
  if is_instance_valid(food):food.hide()
 if player.action_clock>=.95:player.cancel_action()
func render()->void:
 if not is_instance_valid(food) or attempted:return
 var arm:Node2D=player.character.get_node("Visual/Pelvis/ArmL" if hand=="left" else "Visual/Pelvis/ArmR")
 food.global_position=arm.to_global(Vector2(0,18.25))
func cancel()->void:
 if is_instance_valid(layer):layer.queue_free()
 food=null;layer=null
