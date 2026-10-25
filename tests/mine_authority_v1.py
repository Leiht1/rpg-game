"""Real Godot authority, process restart, seed placement and SQLite atomicity."""
import copy, json, sys, tempfile, time, importlib.util, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/network'))
from game_host import GameHost
from gameplay import Gameplay, PERSONAL
spec=importlib.util.spec_from_file_location('mine_server',ROOT/'tools/network/server.py');server=importlib.util.module_from_spec(spec);spec.loader.exec_module(server)
OUT=ROOT/'reports/mine-v1/authority';OUT.mkdir(parents=True,exist_ok=True)
checks=[]
def check(ok,label):
 checks.append({'name':label,'pass':bool(ok)});print('CHECK',bool(ok),label,flush=True);assert ok,label
def same_json(a,b):
 if isinstance(a,dict) and isinstance(b,dict):return a.keys()==b.keys() and all(same_json(a[k],b[k]) for k in a)
 if isinstance(a,list) and isinstance(b,list):return len(a)==len(b) and all(same_json(x,y) for x,y in zip(a,b))
 if type(a) in (int,float) and type(b) in (int,float):return math.isclose(a,b,rel_tol=0,abs_tol=1e-12)
 return a==b
def clock(state,minute):state['body_environment'].update(day=int(minute//1440)+1,minute=minute%1440)
def packs(state):return sum(x.get('count',0) for x in state['slots'] if x.get('item_id')=='miner_blast_pack')
ready=json.loads((ROOT/'reports/.tmp/mine-ready.json').read_text(encoding='utf-8'))
with tempfile.TemporaryDirectory(prefix='mine-authority-',dir=OUT) as directory:
 config={'data_dir':directory,'godot':'D:/Godot/Godot_v4.7.2-stable_win64.exe','project':str(ROOT)}
 identity={'id':'mine-authority','seed':271828,'map_cells':1024}
 host=GameHost(config,identity)
 try:
  base=host.execute()['snapshot'];state=copy.deepcopy(base)
  state['exploration_chapter']=copy.deepcopy(ready['exploration_chapter']);state['body_environment']=copy.deepcopy(ready['body_environment'])
  q=state['exploration_chapter'];m=q['mine'];m.update(phase='sealed',entered=False,opened_at=-1,fuse_due=-1)
  state['mine_travel']={'inside':False,'serial':0};state['combat_personal']['phase']='alive';state['combat_world']['boars']={}
  site=m['site'];state['player_position']={'x':site['x'],'y':site['y']+115}
  state['slots'][8]={'item_id':'miner_blast_pack','count':2}
  check(host.execute(state)['ok'],'current save schema including mine')
  bad=copy.deepcopy(state);bad['mine_travel']['inside']=True
  check(not host.execute(bad)['ok'],'inconsistent inside region cannot load')
  far=copy.deepcopy(state);far['player_position']=copy.deepcopy(base['player_position'])
  rejected=host.execute(far,operation='mine',args=['place'])
  check(not rejected['ok'] and packs(rejected['snapshot'])==2,'forged remote placement no cost')
  check(not host.execute(state,operation='mine',args=['wrong-target'])['ok'],'invalid target refused')
  armed=host.execute(state,operation='mine',args=['place'])
  check(armed['ok'] and armed['snapshot']['exploration_chapter']['mine']['phase']=='armed' and packs(armed['snapshot'])==1,'server placement atomic one cost and durable fuse')
  armed=armed['snapshot'];deadline=armed['exploration_chapter']['mine']['fuse_due']
  replay=host.execute(armed,operation='mine',args=['place'])
  check(not replay['ok'] and packs(replay['snapshot'])==1,'concurrent second intent cannot charge')
  clock(armed,deadline-.01);pending=host.execute(armed)['snapshot']
  check(pending['exploration_chapter']['mine']['phase']=='armed','no early opening')
  personal=host.execute(pending,elapsed=2,shared=False)['snapshot']
  check(personal['exploration_chapter']['mine']['fuse_remaining_seconds']==5,'personal-only tick cannot double-advance shared fuse')
  pending=host.execute(pending,elapsed=2)['snapshot']
  check(abs(pending['exploration_chapter']['mine']['fuse_remaining_seconds']-3)<1e-6,'one shared elapsed tick advances fuse exactly once')
 finally:host.close()
 host=GameHost(config,identity)
 try:
  pending=host.execute(pending)['snapshot'];check(pending['exploration_chapter']['mine']['fuse_due']==deadline,'new Godot process restores pending fuse deadline')
  clock(pending,deadline+.01);almost=host.execute(pending,elapsed=2.99)['snapshot']
  check(almost['exploration_chapter']['mine']['phase']=='armed','new process keeps final fraction before five seconds')
  opened=host.execute(almost,elapsed=.01)['snapshot']
  check(opened['exploration_chapter']['mine']['phase']=='open' and packs(opened)==1,'restart finishes seal without extra consumption')
  again=host.execute(opened)['snapshot'];check(again['exploration_chapter']['mine']==opened['exploration_chapter']['mine'],'settled snapshot no repeated finalization')
  entered=host.execute(opened,operation='mine',args=['enter'])
  check(entered['ok'] and entered['snapshot']['mine_travel']['inside'],'authority enters actual region')
  inside=entered['snapshot']
  check(inside['slots']==opened['slots'] and inside['equipment']==opened['equipment'] and same_json(inside['body'],opened['body']),'entry preserves personal inventory equipment body')
  check('mine_travel' in PERSONAL and 'exploration_chapter' not in PERSONAL,'travel personal chapter shared')
  inside['player_position']['y']=4096+340
  exited=host.execute(inside,operation='mine',args=['exit'])
  check(exited['ok'] and not exited['snapshot']['mine_travel']['inside'],'authority returns to same surface mine')
  # Real SQLite commit boundary, fail placement and opening separately.
  with tempfile.TemporaryDirectory(prefix='mine-db-',dir=OUT) as dbdir:
   svc=server.Service({'data_dir':dbdir})
   try:
    wid=base['world_id'];svc.config['gameplay_preview']=True;svc.gameplay=Gameplay(config);svc.gameplay.hosts[wid]=host;svc.gameplay.defaults[wid]=copy.deepcopy(base)
    surface=copy.deepcopy(state);surface['world_id']=wid
    world={key:copy.deepcopy(value) for key,value in surface.items() if key not in PERSONAL}
    world={'id':wid,'seed':271828,'map_cells':1024,'gameplay':world}
    person={'id':'p','world_id':wid,'x':site['x'],'y':site['y']+115,'slots':copy.deepcopy(surface['slots']),'equipment':copy.deepcopy(surface['equipment']),'hotbar_equipment':copy.deepcopy(surface['hotbar_equipment']),'gameplay':{key:copy.deepcopy(value) for key,value in surface.items() if key in PERSONAL},'appearance':{}}
    svc.state['worlds'][wid]=world;svc.state['characters']['p']=person
    svc.state['accounts']['a']={'id':'a','player_id':'p','world_id':wid,'enabled':True,'nickname':'Test','role':'player'}
    svc.sessions['token']={'account':'a','expires':time.monotonic()+1000,'seen':time.monotonic(),'entered':True}
    def api(op,**args):return svc.handle(op,{'protocol':1,'version':'0.1.0',**args},'token')
    before=copy.deepcopy(svc.state);save=svc.save
    svc.save=lambda:(_ for _ in ()).throw(OSError('intentional isolated disk failure'))
    command={'request_id':'a'*32,'operation':'mine','args':['place']}
    try:api('game_command',**command);check(False,'disk failure must propagate')
    except OSError:pass
    check(svc.state==before,'SQLite placement failure rolls back chapter inventory receipt together')
    svc.save=save;accepted=api('game_command',**command)['snapshot']
    check(packs(accepted)==1 and accepted['exploration_chapter']['mine']['phase']=='armed','same request succeeds after disk recovery')
    replay=api('game_command',**command)['snapshot'];check(packs(replay)==1,'receipt replay returns state without second cost')
    w=svc.state['worlds'][wid];q=w['gameplay']['exploration_chapter'];due=q['mine']['fuse_due'];q['mine']['fuse_remaining_seconds']=0;clock(w['gameplay'],due+1);svc.gameplay.clocks.pop(wid,None)
    previous=copy.deepcopy(svc.state);svc.save=lambda:(_ for _ in ()).throw(OSError('intentional opening failure'))
    try:api('game_snapshot');check(False,'opening disk failure must propagate')
    except OSError:pass
    check(svc.state==previous and svc.state['worlds'][wid]['gameplay']['exploration_chapter']['mine']['phase']=='armed','opening save failure leaves authoritative seal armed')
    svc.save=save;final=api('game_snapshot')['snapshot'];check(final['exploration_chapter']['mine']['phase']=='open' and packs(final)==1,'next request restores persisted baseline and completes opening')
    stored=json.loads(svc.db.execute('SELECT payload FROM state WHERE id=1').fetchone()[0]);check(stored['worlds'][wid]['gameplay']['exploration_chapter']['mine']['phase']=='open','SQLite persisted authoritative opened state')
   finally:
    svc.gameplay.hosts.clear();svc.db.close()
 finally:host.close()
 # Multi-seed location generation through real authority using each world generator.
 for seed in [314159,161803]:
  identity={'id':'mine-seed-'+str(seed),'seed':seed,'map_cells':1024};host=GameHost(config,identity)
  try:
   sample=host.execute()['snapshot'];sample['exploration_chapter']=copy.deepcopy(ready['exploration_chapter']);q=sample['exploration_chapter'];q['mine']={'site':{},'investigated':False,'recipe':False,'phase':'sealed','fuse_due':-1,'opened_at':-1,'entered':False};sample['combat_personal']['phase']='alive'
   clock(sample,q['mine_due']-.01);check(not host.execute(sample)['snapshot']['exploration_chapter']['mine']['site'],f'seed {seed} waits before deadline')
   clock(sample,q['mine_due']+1);generated=host.execute(sample)['snapshot'];mine=generated['exploration_chapter']['mine']
   check(bool(mine['site']),f'seed {seed} finds safe rocky reachable placement')
   reload=host.execute(generated)['snapshot'];check(reload['exploration_chapter']['mine']['site']==mine['site'],f'seed {seed} persisted location stable')
  finally:host.close()
(OUT/'checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
print('MINE AUTHORITY',len(checks),'passed')
