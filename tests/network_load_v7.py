"""Private 1/2/4-player original-rules load probe, no production accounts/data."""
import argparse, copy, json, os, statistics, sys, tempfile, threading, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/network'))
from game_host import GameHost
from gameplay import Gameplay, PERSONAL
from server import Service
def percentile(values,q):return sorted(values)[min(len(values)-1,int(len(values)*q))]
def main():
 p=argparse.ArgumentParser();p.add_argument('--label',default='baseline');p.add_argument('--seconds',type=float,default=6);a=p.parse_args()
 out=ROOT/'reports/network-performance-v7';out.mkdir(exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='windrest-load-v7-') as tmp:
  config={'data_dir':tmp,'godot':os.environ.get('WINDREST_GODOT','D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'),'project':str(ROOT),'gameplay_preview':True,'world_cells':1536}
  host=GameHost(config,{'id':'load','seed':271828,'map_cells':1536})
  try:
   base=host.execute()['snapshot'];s=Service(config);s.gameplay=Gameplay(config);s.gameplay.hosts['load']=host;s.gameplay.defaults['load']=base
   world={'id':'load','seed':271828,'map_cells':1536,'generator':base['generator'],'storage':{},'drops':{},'legacies':{},'exploration':[],'gameplay':{k:copy.deepcopy(v) for k,v in base.items() if k not in PERSONAL}}
   s.terrain(world)
   s.state['worlds']['load']=world
   for i in range(4):
    aid=f'a{i}';cid=f'p{i}';now=time.monotonic()
    s.state['accounts'][aid]={'id':aid,'player_id':cid,'world_id':'load','enabled':True,'avatar':'','nickname':cid,'role':'player'}
    c={'id':cid,'world_id':'load','facing':'front','moving':False,'running':False,'x':base['player_position']['x'],'y':base['player_position']['y'],'appearance':{'gender':'male','hair_id':'male_natural','skin_id':'skin_2'},'slots':copy.deepcopy(base['slots']),'equipment':{},'hotbar_equipment':{},'gameplay':{k:copy.deepcopy(v) for k,v in base.items() if k in PERSONAL}}
    c['gameplay']['combat_personal']['phase']='alive';s.state['characters'][cid]=c
    s.sessions[aid]={'account':aid,'expires':now+1000,'seen':now,'entered':False,'move_at':now,'seq':-1}
   all_results={}
   for count in (1,2,4):
    for i in range(4):
     s.sessions[f'a{i}'].update(entered=i<count,seq=-1,input_ack=0,move_at=time.monotonic(),move_credit=.15)
    samples={'move':[],'snapshot':[]};sizes={'move':[],'snapshot':[]};errors=[];start=time.monotonic();barrier=threading.Barrier(count)
    def client(i):
     token=f'a{i}';seq=0;next_sync=0;barrier.wait();deadline=time.monotonic()+a.seconds
     while time.monotonic()<deadline:
      lap=time.monotonic();seq+=1
      for op,data,label in [('move',{'seq':seq,'dx':0,'dy':0,'inputs':[]},'move')]+([('game_snapshot',{},'snapshot')] if lap>=next_sync else []):
       begin=time.monotonic()
       try:
        r=s.handle(op,{'protocol':1,'version':'0.1.0',**data},token);sizes[label].append(len(json.dumps(r)));samples[label].append((time.monotonic()-begin)*1000)
       except Exception as exc:errors.append(type(exc).__name__+':'+str(exc))
      if lap>=next_sync:next_sync=lap+.4
      time.sleep(max(0,.1-(time.monotonic()-lap)))
    threads=[threading.Thread(target=client,args=(i,)) for i in range(count)]
    for t in threads:t.start()
    for t in threads:t.join()
    result={k:{'count':len(v),'median_ms':round(statistics.median(v),2),'p95_ms':round(percentile(v,.95),2),'max_ms':round(max(v),2),'median_bytes':int(statistics.median(sizes[k]))} for k,v in samples.items() if v}
    result['errors']=errors;all_results[str(count)]=result;print(count,json.dumps(result),flush=True)
   (out/(a.label+'.json')).write_text(json.dumps(all_results,indent=2),encoding='utf-8');s.db.close()
  finally:
   (out/(a.label+'-host.log')).write_bytes((host.folder/'host.log').read_bytes())
   host.close()
   if 's' in locals():s.db.close()
if __name__=='__main__':main()
