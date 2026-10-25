"""Authenticated service restart against a private SQLite world and original rules."""
import copy,importlib.util,json,secrets,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools/network'))
spec=importlib.util.spec_from_file_location('final_restart_server',ROOT/'tools/network/server.py');server=importlib.util.module_from_spec(spec);spec.loader.exec_module(server)
OUT=ROOT/'reports/final-chapter-v1/restart';OUT.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='private-',dir=OUT) as folder:
 cfg=json.loads((ROOT/'config/network-server.json').read_text(encoding='utf-8'));cfg.update(data_dir=folder,godot='D:/Godot/Godot_v4.7.2-stable_win64.exe',project=str(ROOT),world_cells=1024,gameplay_preview=True)
 svc=server.Service(cfg);keys=json.loads(svc.initialize().read_text(encoding='utf-8'));password=secrets.token_urlsafe(20);header={'protocol':1,'version':'0.1.0'}
 response=svc.handle('activate',{**header,**keys[0],'username':'finalrestart','password':password});token=response['token'];svc.handle('nickname',{**header,'nickname':'Restart'},token)
 created=svc.handle('create_world',{**header,'name':'FinalRestart'},token)['world'];svc.handle('character',{**header,'gameplay_revision':1,'appearance':{'gender':'male','hair_id':'male_natural','skin_id':'skin_2'}},token)
 svc.handle('game_snapshot',header,token)
 world=svc.state['worlds'][created['id']];character=svc.character(svc.state['accounts'][svc.sessions[token]['account']])
 source=json.loads((ROOT/'reports/final-chapter-v1/ready.json').read_text(encoding='utf-8'))
 world['gameplay']['exploration_chapter']=copy.deepcopy(source['exploration_chapter']);world['gameplay']['body_environment']=copy.deepcopy(source['body_environment'])
 character['slots']=copy.deepcopy(source['slots']);character['gameplay']['slots']=copy.deepcopy(source['slots']);svc.save();expected=copy.deepcopy(world['gameplay']['exploration_chapter']['finale'])
 svc.gameplay.close();svc.db.close();del svc
 svc=server.Service(cfg)
 try:
  response=svc.handle('login',{**header,'username':'finalrestart','password':password});token=response['token'];resumed=svc.handle('resume',header,token)
  svc.handle('character',{**header,'gameplay_revision':1,'appearance':resumed['character']['appearance']},token)
  result=svc.handle('game_snapshot',header,token);f=result['snapshot']['exploration_chapter']['finale']
  assert f==expected and f['defeated'] and f['core_claimed'] and f['chest_open'] and f['dock_unlocked']
  assert result['snapshot']['slots']==source['slots']
  (OUT/'result.json').write_text(json.dumps({'checks':2,'failures':0,'same_finale_after_sqlite_service_restart':True,'same_inventory_after_restart':True}),encoding='utf-8')
  print('SERVER RESTART 2 checks 0 failures')
 finally:svc.gameplay.close();svc.db.close()
