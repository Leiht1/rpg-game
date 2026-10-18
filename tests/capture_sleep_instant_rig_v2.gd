extends SceneTree
const OUT := "res://reports/sleep-instant-v2/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new();viewport.size=Vector2i(512,320);viewport.transparent_bg=true;viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	viewport.canvas_transform=Transform2D(0,Vector2.ZERO).scaled(Vector2(2,2))
	var rig: Node2D=load("res://assets/hero/cartoon/character.tscn").instantiate();rig.position=Vector2(64,0);viewport.add_child(rig)
	var player: AnimationPlayer=rig.get_node("AnimationPlayer")
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.add_animation_library("sleep",preload("res://scripts/sleep_rig.gd").library(player))
	var face := ShaderMaterial.new();face.shader=preload("res://scripts/sleep_face.gdshader");face.set_shader_parameter("closure",1.0)
	rig.get_node("Visual/Pelvis/Head/Sprite").material=face
	var samples: Array=[]
	for vertical in [false,true]:
		for i in 5:
			var time := i*.9
			player.play("sleep/vertical_breathe" if vertical else "sleep/breathe");player.seek(time,true)
			for j in 3: await process_frame
			await RenderingServer.frame_post_draw
			var label: String=("vertical" if vertical else "horizontal")+"-"+str(i)
			viewport.get_texture().get_image().save_png(OUT+"rig-cycle-"+label+".png")
			samples.append({"direction":"vertical" if vertical else "horizontal","phase":time,"head":str(rig.get_node("Visual/Pelvis/Head/Sprite").global_position),"chest":str(rig.get_node("Visual/Pelvis/Torso").global_position)})
	FileAccess.open(OUT+"rig-cycle-transforms.json",FileAccess.WRITE).store_string(JSON.stringify(samples,"  "))
	print("Native sleep rig captured: ",samples.size()," rendered phases")
	viewport.queue_free()
	for i in 6: await process_frame
	quit()
