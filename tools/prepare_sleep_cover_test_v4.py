from pathlib import Path
s=Path('tests/test_sleep_still_v3.gd').read_text(encoding='utf8').replace('res://reports/sleep-still-v3/','res://reports/sleep-cover-v4/')
a=s.index('\t\tvar still: Sprite2D=');b=s.index('\t\troot.size=Vector2i(1280,720)',a)
s=s[:a]+'''		var resting: Node2D=w.player.get_node("SleepHeadCover")
		var pivot: Node2D=resting.get_node("HeadPivot")
		var head: Sprite2D=pivot.get_node("CurrentHead/Sprite")
		var quilt: Sprite2D=resting.get_node("Quilt")
		check(resting.visible and not w.player.character.visible and quilt.visible,"body fully hidden and only current head plus quilt displayed "+label)
		check(head.texture==w.player.character.get_node("Visual/Pelvis/Head/Sprite").texture and head.material.get_shader_parameter("closure")==1.0,"current side head texture reused with closed eye "+label)
		check(is_equal_approx(pivot.rotation,0 if vertical else -PI/2),"horizontal face points upward; vertical uses side profile "+label)
		var fixed: Vector2=w.player.position;var pose: Transform2D=pivot.transform
		var material: ShaderMaterial=quilt.material;var breath: float=material.get_shader_parameter("breath")
		v.advance_gameplay(.9)
		check(w.player.position==fixed and pivot.transform.is_equal_approx(pose) and absf(float(material.get_shader_parameter("breath"))-breath)>.9,"quilt breathes while head/root stay still "+label)
'''+s[b:]
s=s.replace('not still.visible','not resting.visible').replace('sleeping still hidden','sleeping head/quilt hidden').replace('SLEEP STILL V3 V2','SLEEP HEAD COVER V4')
Path('tests/test_sleep_cover_v4.gd').write_text(s,encoding='utf8')
