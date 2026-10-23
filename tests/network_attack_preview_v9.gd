extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	world.player.set_physics_process(false);world.set_process(false);world.item_service.set_process(false)
	var service=world.item_service;var combat=service.combat
	service.inventory.equipment={};combat.personal=combat.initial_personal()
	service.body.down=false;service.body.sleeping=false;service.body.sleep_session={};service.body.health=100;service.body.energy=100
	var stamina: float=service.body.stamina
	combat.begin_attack_preview(Vector2.DOWN)
	assert(combat.personal.attack.is_empty() and service.body.stamina==stamina)
	assert(not combat.attack_state().is_empty())
	world.item_service.combat_view._process(.016)
	assert(not world.player.combat_render_state.attack.is_empty())
	assert(combat.attack(Vector2.UP)=="" and combat.attack_preview.direction.y==1)
	combat.attack_preview_started-=120
	var predicted: float=combat.attack_state().elapsed
	combat.personal.attack=combat.attack_state().duplicate(true);combat.personal.attack.elapsed=0
	combat.confirm_attack_preview(true)
	assert(combat.attack_state().elapsed>=predicted)
	combat.personal.attack={}
	assert(combat.attack_state().is_empty() and combat.attack_preview.is_empty())
	combat.begin_attack_preview(Vector2.DOWN);combat.confirm_attack_preview(false)
	assert(combat.attack_state().is_empty())
	combat.begin_attack_preview(Vector2.DOWN);combat.personal.hit_serial+=1
	assert(combat.attack_state().is_empty() and combat.attack_preview.is_empty())
	assert(service.body.stamina==stamina)
	print("ATTACK_PREVIEW_PASS immediate pose, authoritative stamina, no duplicate, continuous confirmation, end/rejection/hit cancellation")
	world.queue_free();await process_frame;quit()
