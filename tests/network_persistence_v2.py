"""Packed server restart, persisted receipts and two independent packed clients."""
import concurrent.futures
import copy
import json
import http.client
from pathlib import Path
import secrets
import socket
import sqlite3
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/network'))
import server
OUT=ROOT/'reports/network-integration-v2/restart'
RUNTIME=ROOT/'reports/.tmp/network-integration-v2/runtime'
OUT.mkdir(parents=True,exist_ok=True)
checks=[]
def check(value,name):
    checks.append({'name':name,'pass':bool(value)})
    assert value,name

def main():
    with tempfile.TemporaryDirectory(prefix='private-',dir=OUT) as temporary:
        folder=Path(temporary)
        config=json.loads((ROOT/'config/network-server.json').read_text())
        config.update(data_dir=str(folder/'Data'),godot=str(RUNTIME/'Server/WorldWorker.exe'),project=str(RUNTIME/'Server'),world_cells=128,port=24874,bind='127.0.0.1')
        svc=server.Service(config)
        svc.terrain_factory=lambda w:(w.update(seed=271828) or svc.make_terrain(w))
        credentials=json.loads(svc.initialize().read_text());tokens=[];users=[]
        def setup(op,data=None,token=''):return svc.handle(op,{'protocol':1,'version':'0.1.0','gameplay_revision':1,**(data or {})},token)
        for i in range(2):
            user={'username':'restart'+str(i),'password':secrets.token_urlsafe(20)};users.append(user)
            token=setup('activate',{**credentials[i],**user})['token'];tokens.append(token)
            setup('nickname',{'nickname':'Restart'+str(i)},token)
        world=setup('create_world',{'name':'Restart private'},tokens[0])['world']
        setup('join_world',{'world_id':world['id']},tokens[1])
        for i,token in enumerate(tokens):
            setup('character',{'appearance':{'gender':'male','hair_id':'male_natural','skin_id':'skin_2'}},token)
            setup('game_snapshot',token=token)
            c=svc.character(svc.state['accounts'][svc.sessions[token]['account']])
            c['gameplay']['combat_personal']['phase']='alive'
            c['gameplay']['body'].update(health=90-i*10,hunger=70+i*5,energy=50+i*10)
            c['gameplay']['body']['weather_body']['wetness']=i*40
            c['slots'][8]={'item_id':'wood','count':30}
            c['equipment']={'head':{'item_id':'wool_hat' if i==0 else 'straw_hat','count':1,'instance_id':'restart-hat-'+str(i),'state':{},'durability':None}}
            c['gameplay']['slots']=c['slots'];c['gameplay']['equipment']=c['equipment']
        w=svc.state['worlds'][world['id']]
        w['gameplay']['body_environment'].update(day=7,minute=1439.9,season={'version':1,'origin_day':1},weather_remaining=9000)
        svc.save();cert,_=server.certificate(svc.root);svc.gameplay.close();svc.db.close()
        (folder/'server.json').write_text(json.dumps(config),encoding='utf-8')
        (folder/'client.json').write_text(json.dumps({'server_url':'https://localhost:24874','certificate':str(cert),'server_name':'windrest-server','protocol':1,'version':'0.1.0'}),encoding='utf-8')
        context=ssl.create_default_context(cafile=str(cert))
        def api(op,data=None,token=''):
            payload=json.dumps({'protocol':1,'version':'0.1.0','gameplay_revision':1,**(data or {})}).encode()
            # Connect directly to loopback while strictly verifying the issued
            # server name, just like the actual clients. Never use host proxies.
            with socket.create_connection(('127.0.0.1',24874),timeout=190) as raw:
                with context.wrap_socket(raw,server_hostname='windrest-server') as tls:
                    tls.sendall(('POST /api/'+op+' HTTP/1.0\r\nHost: windrest-server\r\nAuthorization: Bearer '+token+'\r\nContent-Type: application/json\r\nContent-Length: '+str(len(payload))+'\r\n\r\n').encode()+payload)
                    response=http.client.HTTPResponse(tls);response.begin()
                    result=json.load(response)
                    if response.status!=200:raise urllib.error.HTTPError(op,response.status,str(result),{},None)
                    return result
        def stop(proc,log):
            prefix=str(folder).replace("'","''")
            subprocess.run(['powershell','-NoProfile','-Command',"$prefix='"+prefix+"'; Get-CimInstance Win32_Process | Where-Object { $_.Name -in @('WindrestServer.exe','WorldWorker.exe') -and $_.CommandLine.Contains($prefix) } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"],check=True)
            proc.wait(10);log.close()
        def start(label):
            log=(OUT/(label+'.log')).open('w',encoding='utf-8')
            proc=subprocess.Popen([str(RUNTIME/'Server/WindrestServer.exe'),'--config',str(folder/'server.json')],stdout=log,stderr=log)
            for _ in range(150):
                try:
                    with socket.create_connection(('127.0.0.1',24874),timeout=.2):return proc,log
                except OSError:
                    if proc.poll() is not None:raise RuntimeError('packed server failed')
                    time.sleep(.2)
            proc.terminate();proc.wait(10);log.close();raise TimeoutError('listen')
        proc,log=start('first-server')
        try:
            tokens=[api('login',user)['token'] for user in users]
            for token in tokens:api('character',token=token)
            with concurrent.futures.ThreadPoolExecutor(2) as pool:
                initial=list(pool.map(lambda t:api('game_snapshot',token=t),tokens))
            time.sleep(1)
            first=api('game_snapshot',token=tokens[0])['snapshot'];second=api('game_snapshot',token=tokens[1])['snapshot']
            check(first['body_environment']['day']==8 and second['body_environment']==first['body_environment'],'both authority snapshots cross spring to summer once')
            check(first['body']['energy']!=second['body']['energy'] and first['body']['weather_body']['wetness']!=second['body']['weather_body']['wetness'],'personal body states remain distinct')
            for dx,dy in ((0,0),(96,0),(-96,0),(0,64),(0,-64)):
                at=first['player_position'];row={'kind':'wood_floor','x':at['x']+dx,'y':at['y']+dy}
                try:
                    built=api('game_command',{'request_id':secrets.token_hex(16),'operation':'building_place','args':[row,first['slots']]},tokens[0])
                    if built['ok']:break
                except urllib.error.HTTPError:continue
            check(built['ok'],'actual authority building placed before restart')
            command={'request_id':secrets.token_hex(16),'operation':'inventory','args':['move_slot',8,9]}
            moved=api('game_command',command,tokens[0])
            check(moved['ok'] and moved['snapshot']['slots'][9].get('item_id')=='wood','inventory mutation acknowledged before stop')
        finally:
            stop(proc,log)
        with sqlite3.connect(folder/'Data/state.sqlite3') as db:stored=json.loads(db.execute('SELECT payload FROM state WHERE id=1').fetchone()[0])
        db.close()
        check(len(stored['receipts'])>=2,'command receipts committed to SQLite')
        native=(ROOT/'tests/network_reconnect_smoke.gd').read_text(encoding='utf-8')
        native=native.replace('\tvar messages:Dictionary=', '''\tverify(resume.world.gameplay.body_environment==fixture.expected_world.gameplay.body_environment,"season date weather temperature source restored exactly")
\tverify(resume.world.gameplay.buildings==fixture.expected_world.gameplay.buildings,"buildings restored exactly")
\tverify(resume.character.gameplay.body==fixture.expected_character.gameplay.body,"personal body restored exactly")
\tvar messages:Dictionary=''')
        script=OUT/'reconnect.gd';script.write_text(native,encoding='utf-8')
        proc,log=start('second-server');children=[]
        try:
            for i,user in enumerate(users):
                account=next(a for a in stored['accounts'].values() if a['username']==user['username'])
                fixture={**user,'expected_world':stored['worlds'][account['world_id']],'expected_character':stored['characters'][account['player_id']]}
                path=folder/(str(i)+'.json');path.write_text(json.dumps(fixture),encoding='utf-8')
                output=(OUT/('client'+str(i)+'.log')).open('w',encoding='utf-8')
                child=subprocess.Popen([str(RUNTIME/'Client/Windrest.exe'),'--path',str(RUNTIME/'Client'),'--script',str(script),'--','--network-config='+str(folder/'client.json'),'--fixture='+str(path)],stdout=output,stderr=output)
                children.append((child,output))
            codes=[child.wait(60) for child,output in children]
            check(codes==[0,0],'both packed clients verify exact persisted state after real restart')
            token=api('login',users[0])['token'];api('character',token=token)
            replay=api('game_command',command,token)
            check(replay['ok'] and replay['snapshot']['slots'][9]==moved['snapshot']['slots'][9] and not replay['snapshot']['slots'][8],'same request after server restart cannot duplicate or repeat inventory movement')
        finally:
            for child,output in children:
                if child.poll() is None:child.terminate();child.wait(10)
                output.close()
            stop(proc,log);script.unlink(missing_ok=True);script.with_suffix('.gd.uid').unlink(missing_ok=True)
    (OUT/'checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
    print('PACKED RESTART',len(checks),'passed')

if __name__=='__main__':main()
