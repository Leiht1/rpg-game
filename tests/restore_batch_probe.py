import sys,copy,tempfile,time,json,statistics,os
os.environ["WINDREST_PROFILE_NETWORK"]="1"
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools/network'))
from game_host import GameHost
with tempfile.TemporaryDirectory(prefix='restore-batch-') as tmp:
 with GameHost({'data_dir':tmp,'project':str(ROOT),'godot':'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'},{'id':'batch','seed':271828,'map_cells':128}) as h:
  base=h.execute()['snapshot'];at=base['player_position'];gx=int(at['x']//96);gy=int(at['y']//64)
  base['buildings']['objects']={}
  for x in range(-5,6):
   for y in range(-5,6):
    xx=gx+x;yy=gy+y
    base['buildings']['objects'][f'test:{x}:{y}']={'kind':'wood_floor','layer':'ground','gx':xx,'gy':yy,'x':xx*96+48,'y':yy*64+32,'vertical':False,'open':False,'inward':False,'facing':0,'hits':0,'contents':[{} for _ in range(12)]}
  rows=[]
  for i in range(24):
   for row in base['buildings']['objects'].values():row['hits']=i%2
   t=time.perf_counter();r=h.execute(base,operation='snapshot');ms=(time.perf_counter()-t)*1000
   assert r['ok'],r.get('error')
   assert r['snapshot']['buildings']['objects']==base['buildings']['objects']
   rows.append(ms);print(i,round(ms,2),flush=True)
  Path(sys.argv[1]).write_text(json.dumps(rows))
  Path(sys.argv[1]+'.host.log').write_bytes((h.folder/'host.log').read_bytes())
