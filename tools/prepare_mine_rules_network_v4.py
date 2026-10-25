from pathlib import Path
p=Path('tests/run_mine_scene_network_v2.py').read_text(encoding='utf-8')
p=p.replace('mine-scene-v2/network','mine-collision-clues-v4/network').replace('tests/mine_scene_network_v2.gd','tests/mine_rules_network_v4.gd')
p=p.replace("point={'x':saved['player_position']['x']-190,'y':4096+130}","cfg=json.loads((ROOT/'data/mine_puzzle.json').read_text(encoding='utf-8'));point={'x':saved['player_position']['x']+cfg['lamps'][0][0],'y':4096+cfg['lamps'][0][1]}")
Path('tests/run_mine_rules_network_v4.py').write_text(p,encoding='utf-8')
g=Path('tests/mine_scene_network_v2.gd').read_text(encoding='utf-8').replace('mine-scene-v2/network','mine-collision-clues-v4/network')
g=g.replace('verify(p.state.progress==0,"simultaneous same lamp produces one shared reset")','verify(p.state.progress==1 and p.state.order==[0],"simultaneous same lamp recorded once without reset")\n\tif int(fixture.index)==0:\n\t\tfor id in [2,1]:\n\t\t\tawait walk_to(p.point("lamps",id)+Vector2(0,52));m.interact("lamp:"+str(id));await settled()\n\tawait barrier("wrong-three");await create_timer(1).timeout\n\tverify(p.state.progress==3 and p.state.order==[0,2,1] and not p.state.solved,"shared wrong prefix stays lit without early feedback")\n\tif int(fixture.index)==0:\n\t\tawait walk_to(p.point("lamps",3)+Vector2(0,52));m.interact("lamp:3");await settled()\n\tawait barrier("wrong-four");await create_timer(1).timeout\n\tverify(p.state.progress==0 and p.state.order.is_empty() and not p.state.solved,"only fourth wrong lamp resets shared attempt")')
g=g.replace('for i in 3:','for i in 3:')
# The correct sequence now starts from the empty state after the full wrong attempt.
g=g.replace('verify(p.state.progress==3,"both clients see three matching persistent lamps")','verify(p.state.progress==3 and p.state.order==[0,1,2],"both clients see correct three persistent lamps")')
Path('tests/mine_rules_network_v4.gd').write_text(g,encoding='utf-8')
