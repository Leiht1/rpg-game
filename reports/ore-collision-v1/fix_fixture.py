from pathlib import Path
p=Path('tests/ore_collision_v1.gd');s=p.read_text(encoding='utf-8-sig');s=s.replace('w.player.position=center;w.stream.update_target(center)','''for index in 64:
		var candidate: Vector2=m.at()+Vector2(600+(index%8)*160,-560+floori(index/8)*160)
		var clear:=true
		for offset in [Vector2.ZERO,Vector2(-120,0),Vector2(120,0),Vector2(0,-120),Vector2(0,120)]:
			if not w.generator.can_walk(candidate+offset,30):clear=false
		if clear:center=candidate;break
	w.player.position=center;w.stream.update_target(center)''');s=s.replace('var blocked: bool=', 'print("ORE_POSITION ",kind," ",side," ",delta)\n\t\t\tvar blocked: bool=');p.write_text(s,encoding='utf8')
