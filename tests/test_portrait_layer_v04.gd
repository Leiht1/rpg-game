extends SceneTree
const OUT := "res://reports/portrait-layer-fix-v04/"
var world: Node
var ui: Control
var checks: Array=[]
var diffs: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func equip(id: String) -> void:
	for i in 40:
		if world.item_service.inventory.slots[i].get("item_id","")==id:
			world.item_service.inventory.equip(i);return
func run() -> void:
	Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	world.player.automated=true;world.player.set_physics_process(false)
	ui=world.item_ui;ui.toggle_bag()
	for id in ["stone_axe","stone_pickaxe","simple_shovel"]:world.item_service.inventory.add(id,1)
	var golden_view := SubViewport.new();golden_view.size=ui.preview_view.size;golden_view.transparent_bg=true
	golden_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(golden_view)
	ui.preview_actor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	var board := Image.create(156*4,228*4,false,Image.FORMAT_RGBA8);board.fill(Color("f3ead4"))
	for id in ["stone_axe","stone_pickaxe","simple_shovel"]:
		equip(id)
		for facing in ["front","right","left","back"]:
			for moving in [false,true]:
				world.player.facing=facing;world.player.action="";world.player.moving=moving
				world.player.idle_clock=.2;world.player.gait_distance=32;world.player.update_animation()
				var source: Node2D=world.player.character
				var golden: Node2D=source.duplicate()
				golden.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
				golden.position=ui.preview_actor.position;golden.scale=ui.preview_actor.scale
				golden_view.add_child(golden);golden.get_node("AnimationPlayer").active=false
				await frames(3);await RenderingServer.frame_post_draw
				var actual: Image= ui.preview_view.get_texture().get_image()
				var expected := golden_view.get_texture().get_image()
				var diff := 0
				for y in actual.get_height():
					for x in actual.get_width():
						if actual.get_pixel(x,y)!=expected.get_pixel(x,y):diff+=1
				var label: String= id+" "+facing+(" walk" if moving else " idle")
				diffs.append({"case":label,"different_pixels":diff})
				check(diff==0,"portrait pixels match live native pose "+label)
				for path in ["Visual/ArmLBehind","Visual/Pelvis/ArmR","Visual/Pelvis/ArmR/HeldTool"]:
					var live: CanvasItem=source.get_node(path)
					var twin: CanvasItem=ui.preview_actor.get_node(path)
					check(live.show_behind_parent==twin.show_behind_parent and live.z_index==twin.z_index,"draw order matches "+label+" "+path)
				if id=="simple_shovel":
					var row: int=["front","right","left","back"].find(facing)
					var col := 0 if not moving else 2
					board.blend_rect(expected,Rect2i(Vector2i.ZERO,expected.get_size()),Vector2i(156*col,228*row))
					board.blend_rect(actual,Rect2i(Vector2i.ZERO,actual.get_size()),Vector2i(156*(col+1),228*row))
				golden.queue_free();await frames(2)
	board.save_png(OUT+"native-and-portrait.png")
	world.player.facing="right";world.player.moving=false;world.player.update_animation();await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"bag-side-shovel.png")
	var failures := 0
	for row in checks:
		if not row.pass:failures+=1
	var file := FileAccess.open(OUT+"tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"count":checks.size(),"failures":failures,"checks":checks,"pixel_comparisons":diffs},"  "));file.close()
	print("PORTRAIT_LAYER ",checks.size()," checks; ",failures," failures")
	golden_view.queue_free();world.queue_free();await frames(6)
	quit(0 if failures==0 else 1)
