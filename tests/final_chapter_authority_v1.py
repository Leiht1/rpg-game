"""Private original Godot rules host: time gates, retry, participants and restart."""
import copy,json,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools/network'))
from game_host import GameHost
OUT=ROOT/'reports/final-chapter-v1/authority';OUT.mkdir(parents=True,exist_ok=True)
checks=[]
def check(ok,label):
 checks.append({'test':label,'pass':bool(ok)});print('PASS' if ok else 'FAIL',label,flush=True);assert ok,label
def clock(s,t):s['body_environment'].update(day=int(t//1440)+1,minute=t%1440)
source=json.loads((ROOT/'reports/final-chapter-v1/ready.json').read_text(encoding='utf-8'))
def blank():
 s=copy.deepcopy(source);s['combat_world']['boars']={};s['combat_personal'].update(phase='alive',clock=0,attack={});s['body'].update(health=100,energy=100,hunger=100)
 f=s['exploration_chapter']['finale'];f.update(eligible=False,site={},boss={},discovered=False,triggered=False,defeated=False,core_claimed=False,chest_open=False,letter_claimed=False,blueprint_claimed=False,dock_unlocked=False)
 return s
with tempfile.TemporaryDirectory(prefix='private-',dir=OUT) as directory:
 config={'data_dir':directory,'godot':'D:/Godot/Godot_v4.7.2-stable_win64.exe','project':str(ROOT)};identity={'id':'final-authority','seed':271828,'map_cells':1024}
 host=GameHost(config,identity)
 try:
  base=host.execute()['snapshot'];original=source
  source=copy.deepcopy(base)
  for key in ['exploration_chapter','body_environment','combat_world','combat_personal','body','slots','player_position','mine_travel']:source[key]=copy.deepcopy(original[key])
  state=blank();clock(state,state['exploration_chapter']['mine']['puzzle']['next_due']-.1);old=copy.deepcopy(state['exploration_chapter']);state['exploration_chapter'].pop('finale');q=host.execute(state)['snapshot']['exploration_chapter']
  check(q['mine']==old['mine'] and q['stage']==old['stage'],'pre-finale old world preserves all three rounds')
  state=blank();p=state['exploration_chapter']['mine']['puzzle'];clock(state,p['next_due']-.1)
  result=host.execute(state);check(result['ok'] and not result['snapshot']['exploration_chapter']['finale']['eligible'],'authority blocks early generation')
  state=result['snapshot'];clock(state,p['next_due']+.1);result=host.execute(state)
  check(result['ok'] and result['snapshot']['exploration_chapter']['finale']['eligible'],'world calendar deadline grants qualification')
  check(bool(result['snapshot']['exploration_chapter']['finale']['site']),'authority places safe unique plateau')
  # A dying request owner must not freeze the living peer encounter.
  state=result['snapshot'];f=state['exploration_chapter']['finale'];f['discovered']=True;f['triggered']=True
  state['combat_personal'].update(phase='dying',clock=0,attack={});state['body']['health']=0
  b=f['boss'];b.update(mode='active',clock=0,attack='slam',direction={'x':0,'y':1},hits={})
  peer={'id':'living-peer','x':b['x'],'y':b['y']+65,'phase':'alive'}
  result=host.execute(state,elapsed=.05,combat_peers=[peer]);events=result.get('combat_damage',[])
  check(len(events)==1 and events[0]['target']=='living-peer','living remote participant still receives authoritative boss attack')
  result=host.execute(result['snapshot'],elapsed=.05,combat_peers=[peer]);check(not result.get('combat_damage'),'same attack cannot damage remote peer twice')
  result=host.execute(result['snapshot'],elapsed=.05,combat_peers=[])
  check(result['snapshot']['exploration_chapter']['finale']['boss']['mode']=='idle','last player leaves or dies: encounter resets')
  check(result['snapshot']['exploration_chapter']['mine']==old['mine'],'failure retains preceding mine and map rewards')
  completed=copy.deepcopy(source);check(host.execute(completed)['snapshot']['exploration_chapter']['finale']['defeated'],'completed boss never returns')
 finally:host.close()
 host=GameHost(config,identity)
 try:
  result=host.execute(source)
  check(result['ok'] and result['snapshot']['exploration_chapter']['finale']==source['exploration_chapter']['finale'],'new Godot process restores exact boss, rewards and unlock')
  invalid=copy.deepcopy(source);invalid['exploration_chapter']['finale']['defeated']=False
  check(not host.execute(invalid)['ok'],'inconsistent defeated boss snapshot rejected')
 finally:host.close()
(OUT/'checks.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
print('AUTHORITY',len(checks),'checks 0 failures')
