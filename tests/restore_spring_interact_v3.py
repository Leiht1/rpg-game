import sys,tempfile,time,json,statistics
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools/network'))
from game_host import GameHost
with tempfile.TemporaryDirectory(prefix='spring-interact-v3-') as tmp:
 with GameHost({'data_dir':tmp,'project':str(ROOT),'godot':'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'},{'id':'spring','seed':271828,'map_cells':128}) as h:
  state=h.execute()['snapshot'];state['combat_personal']['phase']='alive';samples=[]
  for i in range(24):
   at=state['player_position'];key=f'round3-drop:{i}'
   state['loose'][key]={'id':key,'item_id':'wood','count':1,'x':at['x']+6,'y':at['y']+20,'mode':'pickup'}
   start=time.perf_counter_ns();r=h.execute(state,operation='interact',args=[{'drop_id':key}]);samples.append((time.perf_counter_ns()-start)/1e6)
   assert r['ok'],r.get('error');state=r['snapshot'];assert key in state['consumed'] and key not in state['loose']
   assert sum(x.get('count',0) for x in state['slots'] if x.get('item_id')=='wood')==i+1
  Path('reports/interaction-latency-audit/round3-spring-pickup.json').write_text(json.dumps({'samples_ms':samples,'environment':state['body_environment'],'assertions':48}))
  print('pickup',statistics.median(samples),sorted(samples)[22],max(samples))
