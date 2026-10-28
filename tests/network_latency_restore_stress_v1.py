"""Read/restore timing with a full-size disposable world and changing camp.

Uses the existing profiler, never edits gameplay code or accesses player saves.
"""
import copy,json,os,re,statistics,sys,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/network'))
from game_host import GameHost
os.environ['WINDREST_PROFILE_NETWORK']='1'
OUT=ROOT/'reports/network-latency-full-v1'
def stats(values):
    v=sorted(values)
    return dict(n=len(v),p50_ms=round(statistics.median(v),3),p95_ms=round(v[int((len(v)-1)*.95)],3),max_ms=round(v[-1],3))
def main():
    OUT.mkdir(exist_ok=True)
    rows=[]
    with tempfile.TemporaryDirectory(prefix='windrest-restore-latency-') as temp:
        config=dict(data_dir=temp,project=str(ROOT),godot='D:/Godot/Godot_v4.7.2-stable_win64.exe')
        began=time.perf_counter()
        with GameHost(config,dict(id='latency-1536',seed=271828,map_cells=1536)) as host:
            cold_ms=(time.perf_counter()-began)*1000
            base=host.execute()['snapshot'];base['combat_personal']['phase']='alive'
            at=base['player_position'];gx=int(at['x']//96);gy=int(at['y']//64)
            for kind in ['steady','camp-121','changed-camp-121','resource-rollback']:
                state=copy.deepcopy(base)
                if 'camp' in kind:
                    for x in range(-5,6):
                        for y in range(-5,6):
                            xx=gx+x;yy=gy+y
                            state['buildings']['objects'][f'audit-floor:{x}:{y}']=dict(kind='wood_floor',layer='ground',gx=xx,gy=yy,x=xx*96+48,y=yy*64+32,vertical=False,open=False,inward=False,facing=0,hits=0,contents=[{} for _ in range(12)])
                for turn in range(16):
                    if kind=='changed-camp-121':
                        for key,row in state['buildings']['objects'].items():
                            if key.startswith('audit-floor:'):row['hits']=turn%2
                    if kind=='resource-rollback':state['consumed']={'audit-consumed':True} if turn%2 else {}
                    start=time.perf_counter();result=host.execute(state,operation='snapshot',elapsed=.4)
                    rows.append(dict(case=kind,turn=turn,ms=(time.perf_counter()-start)*1000,ok=result.get('ok',False),error=result.get('error','')))
                    if not result.get('ok'):raise RuntimeError(kind+' '+str(result.get('error')))
            text=(host.folder/'host.log').read_text(encoding='utf-8',errors='replace')
            raw=ROOT/'reports/.tmp/restore-profile.log';raw.write_text(text,encoding='utf-8')
            phases=[]
            for op,restore,wait,advance,snapshot in re.findall(r'RULES_US (\w+) restore=(\d+) wait=(\d+) advance=(\d+) snapshot=(\d+)',text):
                phases.append(dict(operation=op,restore_ms=int(restore)/1000,wait_ms=int(wait)/1000,advance_ms=int(advance)/1000,snapshot_and_operation_ms=int(snapshot)/1000))
            # The final field spans dispatch/operation and snapshot serialization.
            report=dict(scope='local Godot IPC; full 1536-cell world; no TLS, SQLite or rendered client; profiler enabled; 121 injected floors and resource rollback are synthetic stress fixtures',cold_worker_ms=cold_ms,rows=rows,summary={k:stats([r['ms'] for r in rows if r['case']==k]) for k in sorted({r['case'] for r in rows})},profile=phases)
            (OUT/'restore-stress.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
            print(json.dumps(report['summary']),flush=True)
if __name__=='__main__':main()
