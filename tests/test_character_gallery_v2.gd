extends SceneTree
const OUT="res://reports/character-hair-v2/"
const Catalog=preload("res://scripts/character_catalog.gd")
var objects: Array=[]
var renders: Array=[]
func _initialize():call_deferred("run")
func label(text_value: String, at: Vector2, size_value: int=20):
	var l=Label.new();l.text=text_value;l.position=at;l.add_theme_color_override("font_color",Color("473828"));l.add_theme_font_size_override("font_size",size_value);root.add_child(l);objects.append(l)
func actor(look: Dictionary,at: Vector2,facing: String,outfit: bool=false,clip: String="breathe",phase: float=0):
	var rig=load("res://assets/hero/cartoon/character.tscn").instantiate();rig.position=at;rig.scale=Vector2.ONE*1.6;root.add_child(rig);objects.append(rig)
	var inv=ItemInventory.new(ItemDatabase.new());Catalog.enable_candidate(inv.database)
	if outfit:inv.equipment.outfit=inv.instance("modern_outfit")
	if clip in ["chop","mine","dig"]:inv.equipment.main_hand=inv.instance({"chop":"stone_axe","mine":"stone_pickaxe","dig":"simple_shovel"}[clip])
	var ap: AnimationPlayer=rig.get_node("AnimationPlayer");ap.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ap.add_animation_library("harvest",load("res://assets/hero/cartoon/harvest_actions.tres"))
	var view="side" if facing in ["left","right"] else facing
	var name_value=("harvest/" if clip in ["mine","dig"] else "")+view+"_"+clip
	ap.play(name_value);ap.seek(ap.get_animation(name_value).length*phase,true)
	var v=rig.get_node("Visual");v.scale.x=-1 if facing=="left" else 1;v.position.x=128 if facing=="left" else 0
	var renderer=load("res://scripts/character_look.gd").new();renderer.apply(rig,look,inv,facing);renders.append(renderer)
	var held=load("res://scripts/held_tool.gd").new();held.apply(rig,inv,facing,clip if clip in ["chop","mine","dig","pickup"] else "");renders.append(held)
	return rig
func snap(name_value: String):
	for i in 5:await process_frame
	root.get_texture().get_image().save_png(OUT+name_value+".png")
func clear():
	for node in objects:node.queue_free()
	objects.clear();renders.clear()
	await process_frame
func run():
	Engine.max_fps=60
	var bg=ColorRect.new();bg.color=Color("e5e6d8");bg.size=Vector2(1280,720);root.add_child(bg)
	for sex in ["male","female"]:
		label("发型候选 · "+("男性" if sex=="male" else "女性")+" · 正 / 背 / 侧",Vector2(22,12),24)
		var ids=Catalog.rules().hair.keys().filter(func(id):return Catalog.rules().hair[id].gender==sex)
		for col in 4:
			label(Catalog.rules().hair[ids[col]].name,Vector2(90+col*310,48))
			for row in 3:
				actor({"gender":sex,"hair_id":ids[col],"skin_id":"skin_2"},Vector2(44+col*310,70+row*205),["front","back","right"][row])
		await snap(sex+"-hair-gallery");await clear()
	label("六种肤色 · 默认 / 时髦服装 · 实际角色部件",Vector2(22,12),24)
	for col in 6:
		var id=Catalog.rules().skin.keys()[col];label(Catalog.rules().skin[id].name,Vector2(52+col*210,48))
		for row in 2:actor({"gender":"female","hair_id":"female_bob","skin_id":id},Vector2(2+col*210,100+row*280),"front",row==1)
	await snap("skin-outfit-gallery");await clear()
	for row in 4:
		for col in 7:
			var clip=["breathe","walk","run","pickup","chop","mine","dig"][col];label(["正","背","右","左"][row]+" "+clip,Vector2(10+col*181,8+row*178),14)
			var rig=actor({"gender":"female","hair_id":"female_straight","skin_id":"skin_4"},Vector2(10+col*181,25+row*178),["front","back","right","left"][row],true,clip,.45);rig.scale=Vector2.ONE*1.2
	await snap("four-way-actions");quit()
