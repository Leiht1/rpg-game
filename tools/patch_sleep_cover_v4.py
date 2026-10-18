from pathlib import Path
p=Path('scripts/sleep_controller.gd');s=p.read_text(encoding='utf8')
s=s.replace('var still_material: ShaderMaterial','var head_cover := preload("res://scripts/sleep_head_cover.gd").new()')
a=s.index('\tvar vertical: bool=',s.index('func render()'));b=s.index('\tif not is_instance_valid(symbols):',a)
s=s[:a]+'''	var head_anchor: Vector2=head_cover.render(p,s)
	p.update_animation()
'''+s[b:]
a=s.index('\tvar head_offset :=',s.index('func render()'));b=s.index('\tvar canvas:',a)
s=s[:a]+'''	symbols.position=head_anchor+Vector2(-12,-38+sin(float(s.clock)*1.5)*2)
'''+s[b:]
a=s.index('\t# Foreground lives',s.index('func render()'));b=s.index('\nstatic func art_path',a)
s=s[:a]+s[b:]
a=s.index('\nstatic func still_path');s=s[:a]+'\n'
p.write_text(s,encoding='utf8')
p=Path('scripts/sleep_head_cover.gd');s=p.read_text(encoding='utf8')
s=s.replace('var path: String=preload("res://scripts/sleep_controller.gd").art_path(kind+("-vertical" if vertical else ""))','''var name_value := kind+("-vertical" if vertical else "")
	var path := "res://assets/sleep/v1/"+name_value+".png"
	if not ResourceLoader.exists(path): path="res://prototypes/sleep-v1/final/"+name_value+".png" if Engine.get_meta("sleep_preview",false) else ""''')
s=s.replace('Vector2(.5,.32) if vertical else Vector2(.3,.5)','Vector2(.5,.46) if vertical else Vector2(.55,.46)').replace('Vector2(.48,.30) if vertical else Vector2(.3,.48)','Vector2(.30,.13) if vertical else Vector2(.14,.23)')
p.write_text(s,encoding='utf8')
p=Path('scripts/player.gd');s=p.read_text(encoding='utf8').replace('# Sleep is a dedicated whole painted still. Never bend the standing rig.','# Sleeping body is concealed; the current side head is displayed separately.')
s=s.replace('get_node_or_null("SleepStill")','get_node_or_null("SleepHeadCover")').replace('["SleepCover","SleepStill"]','["SleepCover","SleepStill","SleepHeadCover"]')
p.write_text(s,encoding='utf8')
