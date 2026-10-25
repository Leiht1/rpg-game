extends SceneTree
var world: Node
func _initialize() -> void:run.call_deferred()
func run() -> void:
	Engine.set_meta("season_features_preview",true)
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world);current_scene=world
	while not world.started:await process_frame
	var service=world.item_service
	var panel:=HBoxContainer.new();panel.position=Vector2(285,20)
	var hud:=CanvasLayer.new();hud.layer=4;root.add_child(hud);hud.add_child(panel)
	for i in 4:
		var button:=Button.new();button.text=["春","夏","秋","冬"][i];panel.add_child(button)
		button.pressed.connect(func():
			world.environment_view.simulation.day=i*7+3;world.environment_view.simulation.minute=720
			world.environment_view.simulation.snow=.95 if i==3 else .0
			if i==3:preload("res://scripts/season_surface.gd").advance(service,1500))
	var lake_button:=Button.new();lake_button.text="湖泊";panel.add_child(lake_button)
	lake_button.pressed.connect(func():
		var lake: Vector4=world.generator.lakes[0]
		world.player.position=Vector2(lake.x,lake.y);world.stream.update_target(world.player.position))
	var camp_button:=Button.new();camp_button.text="样例营地";panel.add_child(camp_button)
	camp_button.pressed.connect(func():world.player.position=world.generator.spawn;world.stream.update_target(world.player.position))
	service.builds.states.clear();service.builds.refresh_all()
	var count:=0
	for kind in service.builds.definitions:
		var row: Dictionary=service.builds.candidate(kind,world.generator.spawn+Vector2((count%7-3)*122,(count/7-2)*95),false,true,0)
		if kind=="signpost":row.text="候选雪景"
		service.builds.states["preview-"+kind]=row;count+=1
	service.builds.refresh_all()
	world.environment_view.simulation.day=24;world.environment_view.simulation.minute=720;world.environment_view.simulation.snow=.95
	preload("res://scripts/season_surface.gd").advance(service,1500)
