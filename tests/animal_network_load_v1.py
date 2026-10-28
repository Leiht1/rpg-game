"""Isolated real service + Godot authority; never connects to the live server."""
import base64, concurrent.futures, copy, json, os, secrets, sys, tempfile, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/network'))
import server

def main():
    with tempfile.TemporaryDirectory(prefix='animal-network-load-') as folder:
        config = dict(data_dir=folder, world_cells=128, gameplay_preview=True,
                      godot=os.environ.get('WINDREST_GODOT', 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'),
                      project=str(ROOT), hair_ids={'male':['male_natural']})
        nav = lambda w: dict(generator=w['generator'],spawn=[240,240],step=48,width=128,
                             mask=base64.b64encode(bytes([1])*128*128).decode())
        svc = server.Service(config, nav)
        def api(op, data, token):
            return svc.handle(op, dict(protocol=1,version='0.1.0',**data), token)
        try:
            keys = json.loads(svc.initialize().read_text())
            tokens = []
            for i in range(4):
                token=api('activate',dict(**keys[i],username='animaltest'+str(i),password='Animal-test-123'),'')['token']
                api('nickname',{'nickname':'动物测试'+str(i)},token);tokens.append(token)
            world=api('create_world',{'name':'动物隔离压力测试'},tokens[0])['world']
            for i,token in enumerate(tokens):
                if i:api('join_world',{'world_id':world['id']},token)
                api('character',dict(gameplay_revision=1,appearance=dict(gender='male',hair_id='male_natural',skin_id='skin_2')),token)
                api('game_snapshot',{},token)
            for token in tokens:
                c=svc.character(svc.state['accounts'][svc.sessions[token]['account']])
                c['gameplay']['combat_personal']['phase']='alive'
            rows=[]
            def player(i):
                token=tokens[i];local=[]
                for turn in range(12):
                    attack_id=secrets.token_hex(16)
                    ops=[('game_snapshot',{})]
                    if turn%4==0:
                        command=dict(request_id=attack_id,operation='combat_attack',args=[dict(x=1,y=0)])
                        ops=[('game_command',command),('game_command',command)]
                    ops.append(('move',dict(seq=1000+turn,dx=0,dy=0,
                                           inputs=[dict(id=1000+turn,dt=.025,dx=1,dy=0,run=False)])))
                    for op,data in ops:
                        began=time.perf_counter();result=api(op,data,token)
                        assert result['ok'],result
                        local.append(dict(players=count,player=i,operation=op,id=data.get('request_id',data.get('seq','snapshot')),
                                          ms=(time.perf_counter()-began)*1000))
                    time.sleep(.22)
                return local
            for count in (1,2,4):
                # Sequence and input IDs restart only after a fresh character entry.
                for token in tokens[:count]:
                    api('character',dict(gameplay_revision=1,appearance=dict(gender='male',hair_id='male_natural',skin_id='skin_2')),token)
                with concurrent.futures.ThreadPoolExecutor(max_workers=count) as pool:
                    for result in pool.map(player,range(count)):rows.extend(result)
                values=sorted(r['ms'] for r in rows if r['players']==count)
                print(json.dumps(dict(players=count,requests=len(values),p50=values[len(values)//2],
                                      p95=values[int(len(values)*.95)],maximum=max(values),
                                      over_1000=sum(v>1000 for v in values),over_10000=sum(v>10000 for v in values))),flush=True)
            print('PASS real service 1/2/4 concurrent clients, attacks/retries/movement/snapshots; isolated data',flush=True)
        finally:
            if svc.gameplay:svc.gameplay.close()
            svc.db.close()

if __name__=='__main__':main()
