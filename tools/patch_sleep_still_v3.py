from pathlib import Path
p=Path('scripts/player.gd')
s=p.read_text(encoding='utf8')
s=s.replace('\tanimation_player.add_animation_library("sleep",preload("res://scripts/sleep_rig.gd").library(animation_player))\n','')
a=s.index('\tif body!=null and not body.sleep_session.is_empty():',s.index('func update_animation'))
b=s.index('\tcharacter.position=-ANCHOR',s.index('\tvar cover :=',a))
s=s[:a]+'''\tif body!=null and not body.sleep_session.is_empty():
		# Sleep is a dedicated whole painted still. Never bend the standing rig.
		var still := get_node_or_null("SleepStill")
		character.visible=not is_instance_valid(still) or not still.visible
		held_tool.apply(character,null,"right","pickup");carried_wood.hide()
		return
	character.show()
	for name_value in ["SleepCover","SleepStill"]:
		var resting := get_node_or_null(name_value)
		if resting: resting.hide()
'''+s[b:]
p.write_text(s,encoding='utf8')
p=Path('scripts/sleep_controller.gd');s=p.read_text(encoding='utf8')
s=s.replace('var face_material: ShaderMaterial','var still_material: ShaderMaterial')
s=s.replace('\tp.animation_player.play("sleep/reset");p.animation_player.seek(0,true)\n\tp.character.get_node("Visual/Pelvis/Head/Sprite").material=null\n','')
a=s.index('\tp.update_animation()\n',s.index('func render()'))
b=s.index('\tif not is_instance_valid(symbols):',a)
s=s[:a]+'''	var vertical: bool=s.get("vertical",false)
	var still: Sprite2D=p.get_node_or_null("SleepStill")
	if still==null:
		still=Sprite2D.new();still.name="SleepStill";still.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;p.add_child(still)
	var pose_path := still_path(vertical)
	still.visible=not pose_path.is_empty()
	if still.visible:
		still.texture=load(pose_path);still.scale=Vector2.ONE*.25
		still.position=Vector2(0,(-36 if vertical else -8)+float(Rules.facility(s.source).surface_y)+2)
		if still_material==null:
			still_material=ShaderMaterial.new();still_material.shader=preload("res://scripts/sleep_still.gdshader")
		still.material=still_material
		still_material.set_shader_parameter("breath",sin(float(s.clock)*TAU/float(Rules.data().breath_seconds)))
		still_material.set_shader_parameter("chest",Vector2(.50,.55) if vertical else Vector2(.48,.53))
		still_material.set_shader_parameter("envelope",Vector2(.23,.13) if vertical else Vector2(.14,.25))
	p.update_animation()
'''+s[b:]
a=s.index('\tvar head: Node2D=',s.index('func render()'));b=s.index('\tvar canvas:',a)
s=s[:a]+'''	var head_offset := Vector2(0,-32) if vertical else Vector2(-35,-4)
	symbols.position=still.position+head_offset+Vector2(-12,-32+sin(float(s.clock)*1.5)*2)
'''+s[b:]
s=s.replace('\t\tvar vertical: bool=s.get("vertical",false)\n\t\tvar path :=','\t\tvar path :=')
s+='''
static func still_path(vertical: bool) -> String:
	var name_value := "sleep-vertical" if vertical else "sleep-horizontal"
	var formal := "res://assets/sleep/still-v3/"+name_value+".png"
	if ResourceLoader.exists(formal): return formal
	return "res://prototypes/sleep-still-v3/final/"+name_value+".png" if Engine.get_meta("sleep_preview",false) else ""
'''
p.write_text(s,encoding='utf8')
