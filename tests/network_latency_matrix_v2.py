"""Latency-only audit using valid original-rule fixtures and disposable TLS service.

No production data or implementation changes. Scenario resets are outside timed
requests; this controlled matrix is not a live-world soak or a WAN benchmark.
"""
import base64, collections, concurrent.futures, copy, gzip, http.client, inspect
import json, os, secrets, socket, ssl, statistics, sys, tempfile, threading, time
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/network-latency-v2'/os.environ.get('WINDREST_AUDIT_PHASE','before')
sys.path[:0]=[str(ROOT/'tools/network'),str(ROOT/'tests')]
os.environ.setdefault('WINDREST_GODOT','D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe')
import server
from game_host import GameHost
from gameplay import PERSONAL, ARITY
from test_network_game_host import RulesHostTests
if os.environ.get("WINDREST_AUDIT_PROJECT"):
    import test_network_game_host
    test_network_game_host.ROOT=Path(os.environ["WINDREST_AUDIT_PROJECT"])

corpus=[]
rows=[]
local=threading.local()
original_execute=GameHost.execute
signature=inspect.signature(original_execute)
def capture(self,*args,**kwargs):
    values=signature.bind(self,*args,**kwargs);values.apply_defaults()
    state=values.arguments.get('snapshot')
    operation=values.arguments['operation']
    started=time.perf_counter()
    result=original_execute(self,*args,**kwargs)
    if state is not None and result.get('ok') and operation!='snapshot':
        arguments=copy.deepcopy({k:v for k,v in values.arguments.items() if k!='self'})
        key=operation+':'+json.dumps(arguments.get('args'),sort_keys=True,ensure_ascii=False)
        if operation in {'craft_cancel','fish_judge','fish_cancel','lamp'}:
            key+=' @'+json.dumps(dict(craft=bool(state.get('network_craft_job')),fishing=state.get('network_fishing',{}).get('state','idle'),lamp=state.get('network_lamp_on',False)),sort_keys=True)
        if not any(c['key']==key for c in corpus):
            corpus.append(dict(key=key,values=arguments,fixture_ms=(time.perf_counter()-started)*1000))
    return result

def summarize(values):
    values=sorted(values)
    return dict(n=len(values),p50_ms=round(statistics.median(values),3),
                p95_ms=round(values[max(0,int(len(values)*.95)-1)],3),max_ms=round(values[-1],3),
                over_250=sum(x>250 for x in values),over_1000=sum(x>1000 for x in values),
                over_10000=sum(x>10000 for x in values)) if values else {}

def instrument(cls,name,label):
    original=getattr(cls,name)
    def wrap(self,*args,**kwargs):
        row=getattr(local,'row',None);began=time.perf_counter()
        try:return original(self,*args,**kwargs)
        finally:
            if row is not None:row['stages'].append(dict(stage=label,ms=(time.perf_counter()-began)*1000))
    setattr(cls,name,wrap)

def fixture_corpus():
    GameHost.execute=capture
    prepare=RulesHostTests.setUpClass.__func__
    def ready(cls):
        prepare(cls)
        cls.baseline['combat_personal']['phase']='alive'
    RulesHostTests.setUpClass=classmethod(ready)
    names=[name for name in unittest.defaultTestLoader.getTestCaseNames(RulesHostTests)
           if not any(word in name for word in ['fragment','malformed','partial_response','invalid_snapshot','unknown_command','types_and_coordinates','legacy_containers'])]
    if '--extra' in sys.argv:names=[]
    try:
        suite=unittest.TestSuite(RulesHostTests(name) for name in names)
        result=unittest.TextTestRunner(verbosity=1).run(suite)
        if not result.wasSuccessful():raise RuntimeError('Fixture preparation failed')
        RulesHostTests.setUpClass()
        case=RulesHostTests()
        def run(state,operation,args=None,**kwargs):
            result=case.host.execute(state,operation=operation,args=args,**kwargs)
            if not result.get('ok'):raise RuntimeError('Invalid additional fixture: '+operation+' '+str(result.get('error')))
            return result['snapshot']
        def fresh():return copy.deepcopy(case.baseline)
        try:
            state=fresh();state['slots'][8]={'item_id':'wood','count':7}
            run(state,'discard',[8,1]);run(state,'inventory',['split_slot',8,2]);run(state,'inventory',['destroy_slot',8])
            state=fresh();state['slots'][8]={'item_id':'stone_axe','count':1,'instance_id':'audit-tool','state':{},'durability':100}
            equipped=run(state,'inventory',['equip',8]);run(equipped,'inventory',['unequip',40]);run(state,'inventory',['equip_hotbar',8,40])
            state=case.fixture_building('wood_chest');state['buildings']['objects']['fixture']['contents'][0]={'item_id':'wood','count':7}
            run(state,'building_open',['fixture',True]);run(state,'building_edit',['fixture',0,{'item_id':'wood','count':7},'split',-1,2])
            state=case.fixture_building('workbench');run(state,'station',['fixture']);run(fresh(),'station',[''])
            state=fresh();state['slots'][8]={'item_id':'field_lantern','count':1,'lamp_id':'audit-lamp','fuel':1800.0}
            lit=run(state,'lamp',[8]);run(lit,'lamp',[8])
            run(fresh(),'combat_attack',[{'x':1,'y':0}]);run(fresh(),'craft_cancel');run(fresh(),'fish_cancel')
            state=fresh();state['slots'][8]={'item_id':'branch','count':10};state['slots'][9]={'item_id':'flint','count':10};state['slots'][10]={'item_id':'plant_fiber','count':10}
            state=run(state,'craft',['hand_stone_axe',1]);run(state,'craft_cancel')
            if '--variants' in sys.argv:
                fishing=next(c for c in corpus if c['values']['operation']=='fish_start')
                state=run(copy.deepcopy(fishing['values']['snapshot']),'fish_start')
                run(state,'fish_cancel')
            if '--extra' in sys.argv:
                state=fresh();state['slots'][8]={'item_id':'predecessor_map','count':1};run(state,'chapter_read',['predecessor_map'])
                state=fresh();p=copy.deepcopy(state['player_position'])
                state['exploration_chapter'].update(stage=2,eligible_at=0,site=dict(x=p['x']+50,y=p['y']),shore=p,lake=0)
                run(state,'chapter',['remains'])
                state=fresh();p=state['player_position'];state['combat_world']['relics']={'audit-relic':dict(**p,owner='other',contents=[{'item_id':'wood','count':2}])}
                run(state,'relic_claim',['audit-relic',0,{'item_id':'wood','count':2}])
                opened=False
                for shift in [192,-192,384,-384,576]:
                    state=case.fixture_building('fence_gate');gate=state['buildings']['objects']['fixture'];gate['gx']+=shift//96;gate['x']+=shift;gate['y']=gate['gy']*64;state['player_position']=dict(x=gate['x'],y=gate['y']+80)
                    if case.host.execute(state,operation='building_toggle',args=['fixture']).get('ok'):opened=True;break
                if not opened:raise RuntimeError('No clear gate sweep fixture')
                state=fresh();p=copy.deepcopy(state['player_position']);chapter=state['exploration_chapter']
                chapter.update(stage=5,eligible_at=0,site=p,shore=p,lake=0,investigated_at=0,elder_due=100000,dialogue_at=0,fishing_due=100000,bottle_claimed=True,bottle_read=True,bottle_read_at=0,mine_due=1440)
                mine_at=dict(x=p['x']+300,y=p['y']);chapter['mine'].update(site=mine_at,record_site=p,investigated=True,recipe=True,phase='open',fuse_due=0,opened_at=1,fuse_remaining_seconds=0)
                state['body_environment'].update(day=3,minute=720);state['player_position']=dict(x=mine_at['x'],y=mine_at['y']+55)
                inside=run(state,'mine',['enter']);run(inside,'mine',['exit'])
                for operation in ['building_bag','camp_place','camp_build']:
                    accepted=False
                    for dx,dy in [(x*96,y*64) for x in range(3,10) for y in range(-3,4)]:
                        state=fresh();p=state['player_position'];at=dict(x=p['x']+dx,y=p['y']+dy)
                        state['player_position']=dict(x=at['x'],y=at['y']+90)
                        if operation=='building_bag':
                            state['slots'][8]={'item_id':'sleeping_bag','count':1};args=[dict(kind='sleeping_bag',**at),8,state['slots'][8]]
                        elif operation=='camp_place':
                            state['slots'][8]={'item_id':'simple_campfire','count':1};args=[at,8,state['slots'][8]]
                        else:
                            state['slots'][8]={'item_id':'stone','count':20};args=[at,'build_stone_wall',state['slots']]
                        result=case.host.execute(state,operation=operation,args=args)
                        if result.get('ok'):accepted=True;break
                    if not accepted:raise RuntimeError('Could not place fixture for '+operation)
        finally:RulesHostTests.tearDownClass()
    finally:GameHost.execute=original_execute
    print('Prepared valid latency scenarios:',len(corpus),flush=True)

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    fixture_corpus()
    if '--extra' in sys.argv:
        corpus[:]=[c for c in corpus if c['values']['operation'] in {'building_bag','building_toggle','camp_build','camp_place','chapter','chapter_read','mine','relic_claim'}]
    if '--variants' in sys.argv:
        corpus[:]=[c for c in corpus if (c['values']['operation']=='fish_judge' and c['values']['snapshot'].get('network_fishing',{}).get('state')=='game') or (c['values']['operation']=='fish_cancel' and c['values']['snapshot'].get('network_fishing',{}).get('state') not in [None,'idle']) or (c['values']['operation']=='craft_cancel' and c['values']['snapshot'].get('network_craft_job')) or (c['values']['operation']=='lamp' and c['values']['snapshot'].get('network_lamp_on'))]
    for cls,name,label in [(server.Service,'handle_locked','transaction'),(server.Service,'dispatch','dispatch'),
                           (server.Service,'save','sqlite_serialize_commit'),(GameHost,'execute','godot_ipc')]:instrument(cls,name,label)
    original_handle=server.Service.handle
    def measured(self,op,data,*args,**kwargs):
        row=dict(id=data.get('request_id',''),op=op,stages=[]);local.row=row;began=time.perf_counter()
        try:return original_handle(self,op,data,*args,**kwargs)
        finally:
            row['service_ms']=(time.perf_counter()-began)*1000
            if row['id']:rows.append(row)
            local.row=None
    server.Service.handle=measured
    samples=[]
    with tempfile.TemporaryDirectory(prefix='windrest-latency-audit-') as tmp:
        config=dict(data_dir=tmp,project=os.environ.get("WINDREST_AUDIT_PROJECT",str(ROOT)),godot=os.environ['WINDREST_GODOT'],world_cells=128,gameplay_preview=True)
        nav=lambda w:dict(generator=w['generator'],spawn=[240,240],step=48,width=128,mask=base64.b64encode(bytes([1])*128*128).decode())
        svc=server.Service(config,nav)
        cert,key=server.certificate(svc.root)
        tls=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);tls.minimum_version=ssl.TLSVersion.TLSv1_2;tls.load_cert_chain(cert,key)
        httpd=server.ConcurrentTLSServer(('127.0.0.1',0),server.Handler)
        httpd.daemon_threads=True;httpd.service=svc;httpd.tls_context=tls
        httpd.monitor=server.TrafficMonitor(svc.root);svc.monitor=httpd.monitor
        thread=threading.Thread(target=httpd.serve_forever,daemon=True);thread.start()
        class Conn(http.client.HTTPSConnection):
            def connect(self):
                raw=socket.create_connection(('127.0.0.1',httpd.server_port),timeout=60)
                raw.setsockopt(socket.IPPROTO_TCP,socket.TCP_NODELAY,1)
                self.sock=ssl.create_default_context(cafile=str(cert)).wrap_socket(raw,server_hostname='windrest-server')
        connections=[Conn('windrest-server',httpd.server_port,timeout=60) for _ in range(4)]
        world_id=corpus[0]['values']['snapshot']['world_id']
        host=GameHost(config,dict(id=world_id,seed=271828,map_cells=128))
        svc.gameplay.hosts[world_id]=host
        svc.gameplay.defaults[world_id]=copy.deepcopy(corpus[0]['values']['snapshot'])
        def seed(scenario,count):
            state=copy.deepcopy(scenario['values']['snapshot']);at=state['player_position']
            with svc.lock:
                for session in svc.sessions.values():session['entered']=False
                svc.state['worlds'][world_id]=dict(id=world_id,seed=271828,map_cells=128,generator=state['generator'],storage={},drops={},legacies={},exploration=[],gameplay={k:v for k,v in state.items() if k not in PERSONAL})
                svc.terrain(svc.state['worlds'][world_id])
                for i in range(count):
                    aid=f'a{i}';cid=f'p{i}';token=f'token{i}'
                    svc.state['accounts'][aid]=dict(id=aid,player_id=cid,world_id=world_id,enabled=True,avatar='',nickname=cid,role='player')
                    personal={k:copy.deepcopy(v) for k,v in state.items() if k in PERSONAL}
                    if i and state['body'].get('sleeping'):
                        personal['body']=copy.deepcopy(svc.gameplay.defaults[world_id]['body'])
                    svc.state['characters'][cid]=dict(id=cid,world_id=world_id,x=at['x'],y=at['y'],facing='front',moving=False,running=False,appearance=dict(gender='male',hair_id='male_natural',skin_id='skin_2'),slots=copy.deepcopy(state['slots']),equipment=copy.deepcopy(state['equipment']),hotbar_equipment=copy.deepcopy(state['hotbar_equipment']),gameplay=personal)
                    if state['body'].get('sleeping'):
                        for building in svc.state['worlds'][world_id]['gameplay']['buildings']['objects'].values():
                            if building.get('network_sleep_owner'):building['network_sleep_owner']='p0'
                    now=time.monotonic()
                    svc.sessions[token]=dict(account=aid,expires=now+3600,seen=now,entered=True,move_at=now,seq=-1)
                svc.state['receipts'].clear()
        def request(i,scenario,count,round_index):
            values=scenario['values'];rid=secrets.token_hex(16)
            data=dict(protocol=1,version='0.1.0',request_id=rid,operation=values['operation'],args=values.get('args') or [])
            if values.get('expected'):data['expected']=values['expected']
            start=time.perf_counter()
            conn=connections[i]
            conn.request('POST','/api/game_command',json.dumps(data),{'Content-Type':'application/json','Accept-Encoding':'gzip','Authorization':f'Bearer token{i}'})
            response=conn.getresponse();packed=response.read();decoded=gzip.decompress(packed) if response.getheader('Content-Encoding')=='gzip' else packed
            payload=json.loads(decoded)
            samples.append(dict(id=rid,scenario=scenario['key'],players=count,round=round_index,status=response.status,ok=payload.get('ok',False),error=payload.get('error',''),end_to_end_ms=(time.perf_counter()-start)*1000,body_bytes=len(packed),decoded_bytes=len(decoded)))
        try:
            for count in (1,2,4):
                for scenario in corpus:
                    for iteration in range(6):
                        seed(scenario,count)
                        with concurrent.futures.ThreadPoolExecutor(max_workers=count) as pool:
                            list(pool.map(lambda i:request(i,scenario,count,iteration),range(count)))
                        time.sleep(.22)
                group=[r['end_to_end_ms'] for r in samples if r['players']==count]
                print('TLS matrix',count,json.dumps(summarize(group)),flush=True)
        finally:
            for conn in connections:conn.close()
            httpd.shutdown();httpd.server_close();thread.join(10)
            svc.gameplay.close();svc.db.close()
        indexed={r['id']:r for r in rows}
        for row in samples:row['server']=indexed.get(row['id'],{})
        groups=collections.defaultdict(list)
        for row in samples:groups[(row['players'],row['scenario'],row['ok'])].append(row)
        summary=[dict(players=n,scenario=scenario,ok=ok,**summarize([r['end_to_end_ms'] for r in group]),median_body_bytes=statistics.median(r['body_bytes'] for r in group)) for (n,scenario,ok),group in groups.items()]
        operations={c['values']['operation'] for c in corpus}
        filename='controlled-extra-tls.json' if '--extra' in sys.argv else 'controlled-variants-tls.json' if '--variants' in sys.argv else 'controlled-tls.json'
        (OUT/filename).write_text(json.dumps(dict(scope='local strict TLS, compressed persistent connections, authoritative Godot + SQLite; isolated scenario resets; not WAN or rendered UI',engine='Godot 4.7.2',operations=sorted(operations),missing_operations=sorted(set(ARITY)-operations),summary=summary,samples=samples),ensure_ascii=False,indent=2),encoding='utf-8')
        print('Audit saved; successes',sum(r['ok'] for r in samples),'of',len(samples),'missing operations',sorted(set(ARITY)-operations),flush=True)

if __name__=='__main__':main()
