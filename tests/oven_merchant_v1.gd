extends SceneTree
var w
func _initialize():call_deferred("run")
func run():
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 var s=w.item_service
 s.save_path="res://reports/oven-merchant-v1/isolated.json"
 w.player.set_physics_process(false);w.environment_view.set_process(false)
 var at=w.player.position+Vector2(60,0)
 s.builds.states.oven=s.builds.candidate("copper_oven",at,false,false,0);s.builds.install(w.stream.chunk_at(at))
 s.inventory.add("wild_carrot",20);s.industry_ui.open("oven");s.industry_ui.select_slot(0)
 var ui=s.industry_ui
 assert(ui.oven_recipe_ids.size()>0)
 ui.set_oven_mode("free")
 ui.ingredient_choices[0].select(ui.ingredient_ids.find("wild_carrot")+1)
 ui.ingredient_choices[0].show_popup()
 for i in 10:s.inventory.changed.emit();await process_frame
 assert(ui.ingredient_choices[0].get_popup().visible,"snapshot closed ingredient selector")
 assert(ui.selected_slot==0,"slot lost")
 ui.ingredient_choices[0].get_popup().hide();ui.submit()
 assert(not s.builds.states.oven.machine.jobs[0].is_empty())
 ui.select_slot(1);ui.set_oven_mode("book")
 ui.oven_recipe_choice.select(ui.oven_recipe_ids.find("roast_carrot"))
 ui.submit();assert(not s.builds.states.oven.machine.jobs[1].is_empty())
 ui.select_slot(2);ui.set_oven_mode("book")
 for i in 20:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://reports/oven-merchant-v1/book.png")
 ui.set_oven_mode("free")
 for i in 20:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://reports/oven-merchant-v1/free.png")
 var m=s.merchant
 var point=m.choose_point()
 assert(point!=Vector2.INF)
 assert(m.safe_point(point))
 s.ore_nodes.test_collision={"x":point.x,"y":point.y}
 assert(not m.safe_point(point),"persistent unstreamed mineral was ignored")
 s.ore_nodes.erase("test_collision")
 var coord=w.stream.chunk_at(point)
 var packet=s.chunk_distribution(coord)
 var previous=packet.get("harvest",[])
 packet.harvest=[{"id":"unstreamed_test_rock","x":point.x,"y":point.y}]
 assert(not m.safe_point(point),"generated unstreamed mineral was ignored")
 packet.harvest=previous
 print("MERCHANT_COLLISION_PASS generated/persistent")
 print("OVEN_WINDOW_PASS snapshots/book/free/queue")
 quit()

