extends SceneTree
var stage: Node2D
var rigs: Array=[]
var selected := 0
var previous: Dictionary={}
var ready_to_view := false
var title: Label
func _initialize() -> void:call_deferred("run")
func run() -> void:
	stage=Node2D.new();root.add_child(stage);current_scene=stage
	var backdrop:=Sprite2D.new();backdrop.texture=load("res://assets/exploration/final-v2/ground.png");backdrop.position=Vector2(640,390);backdrop.scale=Vector2.ONE*1280/backdrop.texture.get_width();stage.add_child(backdrop)
	var layer:=CanvasLayer.new();stage.add_child(layer)
	var paper:=ColorRect.new();paper.color=Color(.12,.15,.16,.94);paper.size=Vector2(1280,86);layer.add_child(paper)
	title=Label.new();title.position=Vector2(24,12);title.text="远古领主 · 三视角基础体态 V2 · 站姿修订候选\n1 站姿   2 接地   3 承重   4 摆动   L 正常/放大   |   离散骨骼姿态";title.add_theme_font_size_override("font_size",20);layer.add_child(title)
	for i in 3:
		var rig=load("res://scripts/ancient_lord_posture.gd").new();rig.position=Vector2(230+i*405,435);rig.scale=Vector2.ONE*(1.4 if "--large" in OS.get_cmdline_user_args() else .8);stage.add_child(rig);rig.set_view(["front","back","right"][i]);rigs.append(rig)
		var caption:=Label.new();caption.text=["正面","背面","右侧面"][i];caption.position=Vector2(200+i*405,462);caption.add_theme_font_size_override("font_size",18);layer.add_child(caption)
		var hero=load("res://assets/hero/cartoon/character.tscn").instantiate();stage.add_child(hero);hero.position=Vector2(420+i*405,435)-Vector2(64,112)
		var anim: AnimationPlayer=hero.get_node_or_null("AnimationPlayer")
		if anim:anim.stop()
	DisplayServer.window_set_title("远古领主 · 三视角站姿与关键姿态 V2 · 隔离预览")
	ready_to_view=true
	if "--capture-all" in OS.get_cmdline_user_args():
		for pose in ["neutral","contact","down","passing"]:
			for rig in rigs:rig.set_posture(pose)
			title.text="远古领主 · 骨骼姿态修订候选 · "+pose+"\n1 站姿   2 接地   3 承重   4 摆动   L 正常/放大   |   离散姿态，无完整循环"
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/boss-posture-v2/"+pose+("-large" if "--large" in OS.get_cmdline_user_args() else "-normal")+".png")
		quit();return
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/boss-posture-v2/standing-large.png" if "--large" in OS.get_cmdline_user_args() else "res://reports/boss-posture-v2/standing.png")
		print("POSTURE STATIC CAPTURED")
		if "--quit-after-capture" in OS.get_cmdline_user_args():quit()
func _process(_delta: float) -> bool:
	if not ready_to_view:return false
	for key in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_L]:
		var down:=Input.is_physical_key_pressed(key)
		if down and not previous.get(key,false):
			if key==KEY_L:
				for rig in rigs:rig.scale=Vector2.ONE*(1.4 if absf(rig.scale.x)<1.0 else .8)
			else:
				selected=key-KEY_1
				for rig in rigs:rig.set_posture(["neutral","contact","down","passing"][selected])
				title.text="远古领主 · 三视角体态修订候选 · "+["站姿","接地","承重","摆动"][selected]+"\n1 站姿   2 接地   3 承重   4 摆动   L 正常/放大   |   离散骨骼姿态"
		previous[key]=down
	return false
