from pathlib import Path
s=Path('tests/test_sleep_instant_v2.gd').read_text(encoding='utf8').replace('res://reports/sleep-instant-v2/','res://reports/sleep-still-v3/')
a=s.index('\t\tvar head: Node2D=');b=s.index('\t\troot.size=Vector2i(1280,720)',a)
s=s[:a]+'''		var still: Sprite2D=w.player.get_node("SleepStill")
		var fixed: Vector2=w.player.position;var pose: Transform2D=still.transform
		check(still.visible and not w.player.character.visible and still.texture.resource_path.ends_with("sleep-vertical.png" if vertical else "sleep-horizontal.png"),"whole painted still replaces ALL original character parts "+label)
		check(not w.player.animation_player.has_animation_library("sleep"),"no skeletal sleep library registered "+label)
		var material: ShaderMaterial=still.material
		var breath: float=material.get_shader_parameter("breath")
		v.advance_gameplay(.9)
		check(w.player.position==fixed and still.transform.is_equal_approx(pose) and absf(float(material.get_shader_parameter("breath"))-breath)>.9,"chest shader breathes without moving head/root or rotating sprite "+label)
'''+s[b:]
s=s.replace('await shot(label+"-detail");await rig_shot(label)','await shot(label+"-detail")')
a=s.index('\t\tcheck(head.material==null');b=s.index('\n',a)
s=s[:a]+'''		check(w.player.character.visible and not still.visible and w.player.character.get_node("Visual/Pelvis").transform.is_equal_approx(standing_pelvis),"standing rig restored instantly and sleeping still hidden "+label)'''+s[b:]
s=s.replace('SLEEP INSTANT','SLEEP STILL V3')
Path('tests/test_sleep_still_v3.gd').write_text(s,encoding='utf8')
