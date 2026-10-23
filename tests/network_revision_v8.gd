extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var world=load("res://scripts/network_game_world.gd").new()
 world.players_sample_time=20.0
 world.actors={"existing":null}
 world.update_players([],19.0)
 assert(world.actors.has("existing"))
 world.free()
 var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.player.set_physics_process(false);w.set_process(false);w.item_service.set_process(false)
 var p=w.player;var service=w.item_service
 service.combat.personal.phase="alive"
 p.character_look=preload("res://scripts/character_catalog.gd").default_look()
 p.facing="front"
 service.inventory.equipment={}
 for skin in preload("res://scripts/character_catalog.gd").rules().skin:
  p.character_look.skin_id=skin
  service.combat.personal.attack={"elapsed":.2,"weapon":service.combat.rules.weapons.unarmed,"direction":{"x":0,"y":1},"targets":{}}
  p.combat_render_state=service.combat.personal.duplicate(true)
  p.update_animation()
  assert(p.held_tool.front_free_hand.material==p.character.get_node("Visual/ArmLBehind").material)
  assert(p.held_tool.front_free_hand.material.get_shader_parameter("skin_color")==Color(preload("res://scripts/character_catalog.gd").rules().skin[skin].color))
 var recipes=JSON.parse_string(FileAccess.get_file_as_string("res://data/recipes.json"))
 for recipe in recipes:
  if recipe.recipe_id=="hand_field_lantern":assert(not recipe.materials.has("relic_fragment"))
 assert(w.item_service.combat_view.get("duel_toggle")==null)
 print("NETWORK_REVISION_V8_PASS stale roster, six skin attack arms, lantern recipe, removed duel UI")
 w.queue_free();await process_frame;quit()
