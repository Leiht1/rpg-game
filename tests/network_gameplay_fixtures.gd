extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var arguments:=OS.get_cmdline_user_args()
 var world=load("res://scripts/network_game_host_world.gd").new()
 world.bootstrap={"id":"isolated-gameplay-v5","seed":271828,"map_cells":128}
 root.add_child(world);current_scene=world
 while not world.started:await process_frame
 for unused in 200:
  await process_frame
  if world.stream.viewport_ready(world.player.position,Vector2(1280,720)):break
 var result: Dictionary={"spots":[],"targets":{}}
 for spot in world.item_service.fishing_population.spots:
  result.spots.append({"id":spot.id,"stand":{"x":spot.stand.x,"y":spot.stand.y},"water":{"x":spot.water.x,"y":spot.water.y}})
 for node in world.object_root.get_children():
  var action: String=preload("res://scripts/world_interaction.gd").action_for(node)
  if action not in ["chop","mine","dig","pickup"] or result.targets.has(action):continue
  for offset in [Vector2(0,28),Vector2(28,0),Vector2(-28,0),Vector2(0,-28),Vector2(0,45)]:
   var at: Vector2=node.position+offset
   if not world.generator.can_walk(at) or not preload("res://scripts/world_interaction.gd").in_reach(world.stream,at,node):continue
   var identity: Dictionary=preload("res://scripts/network_game_route.gd").encode(node)
   if not identity.is_empty():result.targets[action]={"target":identity,"position":{"x":at.x,"y":at.y}};break
 var file:=FileAccess.open(arguments[0],FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
 print("FIXTURE_POSITIONS_READY")
 quit()
