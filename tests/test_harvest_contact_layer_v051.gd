extends SceneTree
var checks: Array=[]
var world: Node
const OUT := "res://reports/harvest-fix-v051/"
func _initialize() -> void:call_deferred("run")
func frames(n: int=3) -> void:
	for i in n:await process_frame
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	world.player.automated=true;world.player.set_physics_process(false)
	world.environment_view.simulation.set_time(10);world.environment_view.simulation.paused=true
	var p: Vector2=world.generator.spawn
	for node in get_nodes_in_group("world_interactables"):node.queue_free()
	await frames()
	for action in ["mine","dig"]:
		var target: Node2D=world.item_service.create_harvest("layer:"+action,{"kind":"stone_outcrop" if action=="mine" else "buried_bone","x":p.x+34,"y":p.y+12})
		world.item_service.inventory.equipment.main_hand=world.item_service.inventory.instance("stone_pickaxe" if action=="mine" else "simple_shovel");world.item_service.inventory.changed.emit()
		for facing in ["right","left"]:
			world.player.position=target.position+Vector2(-38 if facing=="right" else 38,0)
			world.player.facing=facing;world.player.action=action;world.player.action_target=target;world.player.action_clock=.55 if action=="mine" else .43
			world.player.update_animation();world.player.reset_physics_interpolation();world.player.camera.reset_smoothing()
			await frames(6)
			var held: RefCounted=world.player.held_tool
			var native: Sprite2D=world.player.character.get_node("Visual/Pelvis/ArmR/HeldTool")
			check(held.strike_layer.visible and held.strike_tool.visible and not native.visible,"one visible tool contact rendering "+action+facing)
			check(held.strike_layer.get_parent()==world.object_root and held.strike_layer.position.y>target.position.y and held.strike_layer.z_index==0,"tool sorts in front of target with local world Y "+action+facing)
			check(held.strike_tool.global_transform.is_equal_approx(native.global_transform),"contact tool preserves exact native pose/mirror "+action+facing)
			check(held.strike_hand.get_index()>held.strike_tool.get_index() and not held.native_hand.visible,"original hand covers shaft once "+action+facing)
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"contact-"+action+"-"+facing+".png")
			world.player.cancel_action();world.player.update_animation()
			check(not held.strike_layer.visible and world.player.character.get_node("Visual/Pelvis/ArmR/Sprite").visible,"cancel restores original body render "+action+facing)
		target.queue_free();await frames()
	# Recheck live contact fitting for each stage on the unmodified real ground.
	world.player.position=p;world.player.reset_physics_interpolation();world.player.camera.reset_smoothing()
	var col := 0
	for kind in preload("res://scripts/harvest_node.gd").configuration().resources:
		for phase in 3:
			var id: String="final-gallery:"+str(kind)+str(phase)
			var target: Node2D=world.item_service.create_harvest(id,{"kind":kind,"x":p.x-240+col*115,"y":p.y-85+phase*80})
			world.item_service.resource_hits[id]=roundi(float(phase)*float(target.definition.hits)/2);target.refresh_stage()
		col+=1
	await frames(8);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"grounded-stages.png")
	var failed := checks.filter(func(c):return not c.pass)
	var f := FileAccess.open(OUT+"layer-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"count":checks.size(),"failures":failed,"checks":checks},"  "));f.close()
	print("CONTACT_LAYER ",checks.size()," checks; ",failed.size()," failures")
	world.queue_free();await frames(8);quit(0 if failed.is_empty() else 1)
