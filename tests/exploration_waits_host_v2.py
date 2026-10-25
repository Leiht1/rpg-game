"""World clock gates and v1 migration through the real isolated rule process."""
import copy
import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/network'))
from game_host import GameHost

OUT = ROOT / 'reports/exploration-waits-v2/waits-host'
OUT.mkdir(parents=True, exist_ok=True)
checks = []
def check(ok, label):
    checks.append({'name':label, 'pass':bool(ok)})
    print('CHECK',bool(ok),label,flush=True)
    assert ok, label

def clock(state, minutes):
    state['body_environment'].update(day=int(minutes//1440)+1,minute=minutes%1440)

source = json.loads((ROOT/'reports/.tmp/exploration-v1/items-isolated.json').read_text(encoding='utf-8'))
ready = json.loads((ROOT/'reports/.tmp/exploration-waits-v2/ready.json').read_text(encoding='utf-8'))
with tempfile.TemporaryDirectory(prefix='private-', dir=OUT) as directory:
    config={'data_dir':directory,'godot':'D:/Godot/Godot_v4.7.2-stable_win64.exe','project':str(ROOT)}
    identity={'id':'waits-v2','seed':271828,'map_cells':1024}
    host=GameHost(config,identity)
    try:
        base=host.execute()['snapshot']
        unqualified=copy.deepcopy(base)
        clock(unqualified,3*1440+480)
        check(host.execute(unqualified)['snapshot']['exploration_chapter']['stage']==0,'day four alone cannot generate ruins')
        unqualified['slots'][8]={'item_id':'metal_workbench','count':1}
        check(host.execute(unqualified)['snapshot']['exploration_chapter']['stage']==0,'inventory workbench is not a built valid facility')
        def project(value):
            result=copy.deepcopy(base)
            result['exploration_chapter']=copy.deepcopy(value['exploration_chapter'])
            result['body_environment']=copy.deepcopy(value['body_environment'])
            result['combat_personal'].update(phase='alive',clock=0)
            result['combat_world']['boars']={}
            result['body'].update(health=100,energy=100,hunger=100)
            return result
        source=project(source);ready=project(ready)
        state=copy.deepcopy(source)
        state['combat_personal']['phase']='alive'
        state['combat_world']['boars']={}
        state['player_position']=copy.deepcopy(state['exploration_chapter']['shore'])
        q=copy.deepcopy(state['exploration_chapter'])
        result=host.execute(state,operation='chapter',args=['shore'])
        check(not result['ok'],'authority refuses old shore bypass during elder wait')
        state=host.execute(state)['snapshot']
        check(state['exploration_chapter']['elder_due']==q['elder_due'],'snapshot keeps exact pending deadline')
        restart=copy.deepcopy(state)
    finally:
        host.close()
    host=GameHost(config,identity)
    try:
        state=host.execute(restart)['snapshot']
        check(state['exploration_chapter']==restart['exploration_chapter'],'new rule process restores pending wait exactly')
        clock(state,q['elder_due']-1)
        result=host.execute(state)
        check(not result['snapshot']['exploration_chapter']['elder_spawned'],'authority keeps elder hidden before complete day')
        state=copy.deepcopy(ready)
        q=state['exploration_chapter']
        q.update(stage=3,dialogue_at=-1.0,fishing_due=-1.0,fishing_open=False)
        state['player_position']=copy.deepcopy(q['elder'])
        result=host.execute(state,operation='chapter',args=['shore'])
        if not result.get('ok'):
            print('DIALOGUE ERROR',result.get('error'), 'CHAPTER',state['exploration_chapter'],flush=True)
        check(result['ok'] and result['snapshot']['exploration_chapter']['stage']==4,'authority completes real in-range dialogue')
        state=result['snapshot'];q=state['exploration_chapter'];deadline=q['fishing_due']
        check(deadline-q['dialogue_at']==1440 and not q['fishing_open'],'dialogue starts full-day authoritative gate')
        repeat=host.execute(state,operation='chapter',args=['shore'])['snapshot']
        check(repeat['exploration_chapter']['fishing_due']==deadline,'dialogue retry preserves deadline')
        clock(state,deadline-1)
        state=host.execute(state)['snapshot']
        check(not state['exploration_chapter']['fishing_open'],'authority withholds special catch before deadline')
        waiting=copy.deepcopy(state)
    finally:
        host.close()
    host=GameHost(config,identity)
    try:
        state=host.execute(waiting)['snapshot']
        check(state['exploration_chapter']['fishing_due']==deadline,'second process restart preserves fishing wait')
        clock(state,deadline+1)
        state=host.execute(state)['snapshot']
        check(state['exploration_chapter']['fishing_open'],'world clock opens catch after complete day')
        for stage in [3,4,5]:
            old=copy.deepcopy(source)
            oldq=old['exploration_chapter']
            old['exploration_chapter']={key:oldq[key] for key in ['stage','eligible_at','site','shore','lake','attempts','bottle_claimed','bottle_read']}
            old['exploration_chapter'].update(version=1,stage=stage,bottle_claimed=stage==5,bottle_read=stage==5)
            result=host.execute(old)
            check(result['ok'] and result['snapshot']['exploration_chapter']['stage']==stage,f'legacy stage {stage} preserved')
            migrated=result['snapshot'];mq=migrated['exploration_chapter']
            check(mq['version']==2 and mq['bottle_claimed']==(stage==5),f'legacy stage {stage} rewards preserved')
            again=host.execute(migrated)['snapshot']['exploration_chapter']
            check(again==mq,f'legacy stage {stage} does not reroll on reload')
            check(migrated['slots']==old['slots'],f'legacy stage {stage} migration grants no items')
    finally:
        host.close()
(OUT/'checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
print('EXPLORATION WAITS HOST',len(checks),'passed')
