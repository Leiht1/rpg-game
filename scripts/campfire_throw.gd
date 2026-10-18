extends RefCounted
## A session-only one-shot gesture. Inventory and fuel commit together at impact.
var player: Node2D
var manager: RefCounted
var camp_id := ""
var slot := -1
var snapshot: Dictionary={}
var count := 0
var hand := "right"
var equipped := ""
var projectile: Sprite2D
var flight_layer: Node2D
var release_at := Vector2.ZERO
var attempted := false
var committed := false

func equipment_id() -> String:
	return str(player.equipment_inventory.equipment.get("main_hand",{}).get("instance_id",""))

func start(owner_player: Node2D, id: String, index: int, data: Dictionary, requested_count: int = -1) -> String:
	player=owner_player;manager=player.stream.items.camps
	if not player.action.is_empty(): return "请等待当前动作结束"
	if player.body!=null and player.body.down: return "正在休养，暂时无法投掷"
	var reason: String=manager.feed_check(id,index,data)
	if not reason.is_empty(): return reason
	camp_id=id;slot=index;snapshot=data.duplicate(true);count=manager.feed_amount(id,data)
	if requested_count!=-1:
		if requested_count<1 or requested_count>count: return "投放数量或篝火容量已变化，请重新选择"
		count=requested_count
	equipped=equipment_id();hand="left" if not equipped.is_empty() else "right"
	var offset: Vector2=Vector2(manager.states[id].x,manager.states[id].y)-player.position
	player.facing=("right" if offset.x>0 else "left") if absf(offset.x)>=absf(offset.y) else ("front" if offset.y>0 else "back")
	attempted=false;committed=false;player.action="throw";player.action_clock=0.0
	player.action_target=manager.visuals[id];player.moving=false;player.running=false
	projectile=Sprite2D.new();projectile.name="ThrownCampFuel"
	projectile.texture=manager.service.texture(str(snapshot.item_id),"icon")
	if projectile.texture: projectile.scale=Vector2.ONE*18.0/maxf(1,projectile.texture.get_width())
	flight_layer=Node2D.new();flight_layer.name="CampFuelFlightLayer"
	flight_layer.position=Vector2(0,maxf(player.position.y,float(manager.states[id].y))+.5)
	player.get_parent().add_child(flight_layer);flight_layer.add_child(projectile);player.update_animation()
	return ""

func advance(delta: float) -> void:
	if equipment_id()!=equipped or not manager.states.has(camp_id) or not manager.visuals.has(camp_id) or (player.body!=null and player.body.down): player.cancel_action();return
	player.action_clock+=delta
	if player.action_clock>=.70 and not attempted:
		attempted=true
		var reason: String=manager.feed(camp_id,slot,snapshot,count)
		committed=reason.is_empty()
		if not committed: manager.service.notice.emit(reason)
		if is_instance_valid(projectile): projectile.hide()
	if player.action_clock>=.95: player.cancel_action()

func render() -> void:
	if not is_instance_valid(projectile) or attempted: return
	var arm: Node2D=player.character.get_node("Visual/Pelvis/ArmL" if hand=="left" else "Visual/Pelvis/ArmR")
	var palm: Vector2=arm.to_global(Vector2(0,18.25))
	if player.action_clock<.42:
		projectile.global_position=palm;release_at=palm
	else:
		var t: float=clampf((player.action_clock-.42)/.28,0,1)
		var target := Vector2(float(manager.states[camp_id].x),float(manager.states[camp_id].y))-Vector2(0,24)
		projectile.global_position=release_at.lerp(target,t)+Vector2(0,-sin(PI*t)*26)
		projectile.rotation=t*1.5

func cancel() -> void:
	if is_instance_valid(flight_layer): flight_layer.queue_free()
	elif is_instance_valid(projectile): projectile.queue_free()
	projectile=null
	flight_layer=null
