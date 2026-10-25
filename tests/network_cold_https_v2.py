"""Real packed clients: login B while A's cold world worker is running."""
import json
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import tempfile
import time
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/network'))
import server
OUT=ROOT/'reports/network-integration-v2/cold-native';OUT.mkdir(exist_ok=True)
RUNTIME=ROOT/'reports/.tmp/network-integration-v2/runtime'
NATIVE='''extends SceneTree
func _initialize() -> void:run.call_deferred()
func ensure(value: bool, label: String) -> void:
 if not value:push_error(label);quit(1);assert(value,label)
func mark(folder: String, name: String) -> void:FileAccess.open(folder.path_join(name),FileAccess.WRITE).store_string("done")
func run() -> void:
 var args=OS.get_cmdline_user_args();var folder: String="";var role: String=""
 for arg in args:
  if arg.begins_with("--fixture="):folder=arg.trim_prefix("--fixture=")
  if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
 var f: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("fixture.json")))
 var network=root.get_node("Network");var began:=Time.get_ticks_msec()
 var login: Dictionary=await network.call_api("login",f["a" if role=="a" else "b"])
 ensure(login.get("ok",false),"cold login failed "+str(login.get("error","")))
 var elapsed:=Time.get_ticks_msec()-began
 if role!="a":
  ensure(elapsed<8000,"unchanged 8 second login deadline")
  FileAccess.open(folder.path_join(role+".json"),FileAccess.WRITE).store_string(JSON.stringify({"login_ms":elapsed}))
  print("COLD_LOGIN_MS ",role," ",elapsed);quit();return
 mark(folder,"creating")
 var world: Dictionary=await network.call_api("create_world",{"name":"Cold login"})
 ensure(world.get("ok",false),"cold world create "+str(world.get("error","")))
 mark(folder,"terrain-done")
 var entered: Dictionary=await network.call_api("character",{"appearance":{"gender":"male","hair_id":"male_natural","skin_id":"skin_2"}})
 ensure(entered.get("ok",false),"cold character entry")
 var state: Dictionary=await network.call_api("game_snapshot",{})
 ensure(state.get("ok",false),"cold world authoritative snapshot")
 mark(folder,"rules-done");print("COLD_NATIVE_A_PASS");quit()
'''

def main():
 with tempfile.TemporaryDirectory(prefix='private-',dir=OUT) as temp:
  folder=Path(temp);config=json.loads((ROOT/'config/network-server.json').read_text())
  config.update(data_dir=str(folder/'Data'),godot=str(RUNTIME/'Server/WorldWorker.exe'),project=str(RUNTIME/'Server'),world_cells=1536,bind='127.0.0.1',port=24875)
  svc=server.Service(config);keys=json.loads(svc.initialize().read_text());users={}
  for i,name in enumerate(('a','b')):
   user={'username':'coldnative'+name,'password':secrets.token_urlsafe(20)};users[name]=user
   token=svc.handle('activate',{'protocol':1,'version':'0.1.0',**keys[i],**user})['token']
   svc.handle('nickname',{'protocol':1,'version':'0.1.0','nickname':'Cold'+name},token)
  cert,_=server.certificate(svc.root);svc.gameplay.close();svc.db.close()
  (folder/'fixture.json').write_text(json.dumps(users),encoding='utf-8')
  (folder/'server.json').write_text(json.dumps(config),encoding='utf-8')
  (folder/'client.json').write_text(json.dumps({'server_url':'https://localhost:24875','certificate':str(cert),'server_name':'windrest-server','protocol':1,'version':'0.1.0'}),encoding='utf-8')
  script=OUT/'native.gd';script.write_text(NATIVE,encoding='utf-8')
  log=(OUT/'server.log').open('w',encoding='utf-8');proc=subprocess.Popen([str(RUNTIME/'Server/WindrestServer.exe'),'--config',str(folder/'server.json')],stdout=log,stderr=log);children=[];results={}
  def launch(role):
   output=(OUT/(role+'.log')).open('w',encoding='utf-8')
   child=subprocess.Popen([str(RUNTIME/'Client/Windrest.exe'),'--path',str(RUNTIME/'Client'),'--script',str(script),'--','--network-config='+str(folder/'client.json'),'--fixture='+str(folder),'--role='+role],stdout=output,stderr=output)
   children.append((child,output));return child
  def worker(kind):
   prefix=str(folder).replace("'","''")
   command="$prefix='"+prefix+"'; Get-CimInstance Win32_Process -Filter \"Name='WorldWorker.exe'\" | Where-Object { $_.CommandLine.Contains($prefix) -and $_.CommandLine.Contains('"+kind+"') } | Select-Object -First 1 -ExpandProperty ProcessId"
   deadline=time.monotonic()+60
   while time.monotonic()<deadline:
    if children and children[0][0].poll() is not None:raise RuntimeError('client A exited before worker phase '+kind)
    if subprocess.run(['powershell','-NoProfile','-Command',command],capture_output=True,text=True).stdout.strip():return
    time.sleep(.1)
   raise TimeoutError('cold worker phase was not observed: '+kind)
  try:
   for _ in range(150):
    try:
     with socket.create_connection(('127.0.0.1',24875),timeout=.2):break
    except OSError:time.sleep(.2)
   a=launch('a')
   worker('network_terrain_worker.gd')
   b=launch('terrain-login');assert b.wait(15)==0
   results['terrain_login']=json.loads((folder/'terrain-login.json').read_text())
   results['world_still_generating_after_login']=not (folder/'terrain-done').exists()
   assert results['world_still_generating_after_login'],'login must complete during generation, not after it'
   worker('network_game_worker.tscn')
   b=launch('rules-login');assert b.wait(15)==0
   results['rules_login']=json.loads((folder/'rules-login.json').read_text())
   assert a.wait(120)==0
  finally:
   for child,output in children:
    if child.poll() is None:child.terminate();child.wait(10)
    output.close()
   prefix=str(folder).replace("'","''")
   subprocess.run(['powershell','-NoProfile','-Command',"$prefix='"+prefix+"'; Get-CimInstance Win32_Process | Where-Object { $_.Name -in @('WindrestServer.exe','WorldWorker.exe') -and $_.CommandLine.Contains($prefix) } | ForEach-Object {Stop-Process -Id $_.ProcessId -Force}"],check=True)
   proc.wait(10);log.close();script.unlink(missing_ok=True);script.with_suffix('.gd.uid').unlink(missing_ok=True)
 (OUT/'checks.json').write_text(json.dumps(results,indent=2),encoding='utf-8');print('PACKED COLD CONCURRENT LOGIN PASS',results)
if __name__=='__main__':main()
