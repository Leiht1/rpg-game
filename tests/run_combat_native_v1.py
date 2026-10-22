"""Two native clients; private HTTPS service, accounts and SQLite only."""
import argparse,importlib.util,json,socket,subprocess,sys,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools/network'))
import server
OUT=ROOT/'reports/combat-v1';OUT.mkdir(parents=True,exist_ok=True)
ENGINE=Path('D:/Godot/Godot_v4.7.2-stable_win64_console.exe')
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--delay',type=float,default=0);options=parser.parse_args()
 prefix='delay-' if options.delay else ''
 with tempfile.TemporaryDirectory(prefix='windrest-combat-native-') as temp:
  folder=Path(temp);config=json.loads((ROOT/'config/network-server.json').read_text(encoding='utf-8'))
  config.update(data_dir=str(folder/'Data'),godot=str(ENGINE),project=str(ROOT),world_cells=128,port=24873,bind='127.0.0.1',gameplay_preview=True)
  svc=server.Service(config);keys=json.loads(svc.initialize().read_text());tokens=[];children=[]
  def api(op,data=None,token=''):return svc.handle(op,{'protocol':1,'version':'0.1.0',**(data or {})},token)
  try:
   for i in range(2):
    token=api('activate',{**keys[i],'username':'combatnative'+str(i),'password':'Test-native-123'})['token'];api('nickname',{'nickname':'切磋测试'+str(i)},token);tokens.append(token)
   w=api('create_world',{'name':'Combat Private'},tokens[0])['world'];api('join_world',{'world_id':w['id']},tokens[1])
   for i,t in enumerate(tokens):
    api('character',{'gameplay_revision':1,'appearance':{'gender':'male' if i==0 else 'female','hair_id':'male_natural' if i==0 else 'female_bob','skin_id':'skin_2'}},t);api('game_snapshot',{},t)
   chars=[svc.character(svc.state['accounts'][svc.sessions[t]['account']]) for t in tokens];p=chars[0]
   for i,c in enumerate(chars):
    c['x']=p['x']+i*45;c['y']=p['y'];c['gameplay']['combat_personal']['phase']='alive';c['gameplay']['body']['health']=100
    c['equipment']={'main_hand':{'item_id':'wood_club','count':1,'instance_id':'native-club-'+str(i),'state':{},'durability':None}};c['gameplay']['equipment']=c['equipment']
    c['slots'][8]={'item_id':'wood','count':7};c['slots'][9]={'item_id':'plaster','count':2};c['gameplay']['slots']=c['slots']
   svc.save();cert,_=server.certificate(svc.root)
   if svc.gameplay:svc.gameplay.close()
   svc.db.close()
   (folder/'server.json').write_text(json.dumps(config),encoding='utf-8')
   (folder/'client.json').write_text(json.dumps({'server_url':'https://localhost:24873','certificate':str(cert),'server_name':'windrest-server','protocol':1,'version':'0.1.0'}),encoding='utf-8')
   with (OUT/(prefix+'native-server.log')).open('w',encoding='utf-8') as log:
    proc=subprocess.Popen([sys.executable,str(ROOT/'tests/network_combat_server_v1.py'),'--fixture-folder',str(folder),'--delay',str(options.delay),'--config',str(folder/'server.json')],stdout=log,stderr=log)
    try:
     for i in range(120):
      try:
       with socket.create_connection(('127.0.0.1',24873),timeout=.3):break
      except OSError:time.sleep(.25)
     for i in range(2):
      path=folder/(str(i)+'.json');path.write_text(json.dumps({'index':i,'username':'combatnative'+str(i),'password':'Test-native-123'}))
      output=(OUT/(prefix+'native-client'+str(i)+'.log')).open('w',encoding='utf-8')
      child=subprocess.Popen([str(ENGINE),'--path',str(ROOT),'--script',str(ROOT/'tests/network_combat_native_v1.gd'),'--','--network-config='+str(folder/'client.json'),'--fixture='+str(path)],stdout=output,stderr=output);children.append((child,output))
     codes=[p.wait(timeout=150) for p,f in children];print('COMBAT_NATIVE_EXIT_CODES',codes)
     if any(codes):raise SystemExit(1)
    finally:
     for child,output in children:
      if child.poll() is None:child.terminate();child.wait(timeout=10)
      output.close()
     proc.terminate();proc.wait(timeout=10)
  finally:
   if svc.gameplay:svc.gameplay.close()
   svc.db.close()
if __name__=='__main__':main()
