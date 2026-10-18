extends SceneTree
const OUT := "res://reports/harvest-v05/"
var rigs: Array=[]
var viewport: SubViewport
func _initialize() -> void: call_deferred("run")
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(800,350);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var bg := ColorRect.new();bg.color=Color("e8e1c7");bg.size=Vector2(800,350);viewport.add_child(bg)
	var db := ItemDatabase.new()
	for row in 2:
		var action: String="mine" if row==0 else "dig"
		var inv := ItemInventory.new(db);inv.add("stone_pickaxe" if row==0 else "simple_shovel",1);inv.equip(8)
		for col in 4:
			var facing: String=["front","back","right","left"][col]
			var view: String="side" if col>=2 else facing
			var rig: Node2D=load("res://assets/hero/cartoon/character.tscn").instantiate();viewport.add_child(rig)
			rig.position=Vector2(35+200*col,28+155*row)
			var player: AnimationPlayer=rig.get_node("AnimationPlayer");player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			player.add_animation_library("harvest",load("res://assets/hero/cartoon/harvest_actions.tres"));player.play("harvest/"+view+"_"+action)
			var held := preload("res://scripts/held_tool.gd").new()
			rigs.append({"rig":rig,"player":player,"held":held,"inventory":inv,"facing":facing,"action":action})
			var label := Label.new();label.text=("采矿" if row==0 else "挖掘")+" · "+["正面","背面","右侧","左侧"][col];label.position=Vector2(35+200*col,8+155*row);label.add_theme_color_override("font_color",Color("493d30"));viewport.add_child(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"action-frames"))
	for frame in 70:
		var clock := float(frame)/50.0
		for entry in rigs:
			entry.player.seek(minf(clock,1.12 if entry.action=="mine" else 1.25),true)
			entry.held.apply(entry.rig,entry.inventory,entry.facing,entry.action)
			if entry.facing=="left":entry.rig.get_node("Visual").scale.x=-1;entry.rig.get_node("Visual").position.x=128
		await process_frame;await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(OUT+"action-frames/%03d.png"%frame)
	viewport.free();quit()

