"""Private fixture server: never run against a production data directory."""
import json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/network'))
import server
index=sys.argv.index('--fixture-folder');folder=Path(sys.argv[index+1]);del sys.argv[index:index+2]
if '--delay' in sys.argv:
 import time
 index=sys.argv.index('--delay');delay=float(sys.argv[index+1]);del sys.argv[index:index+2]
 post=server.Handler.do_POST
 def delayed(self):
  if self.path in ('/api/game_command','/api/move'):time.sleep(delay)
  return post(self)
 server.Handler.do_POST=delayed
dispatch=server.Service.dispatch
def isolated(self,op,data,token,ip):
 if (folder/'release-boar').exists() and not (folder/'boar-released').exists():
  target=next(c for c in self.state['characters'].values() if c['appearance']['gender']=='male')
  w=self.state['worlds'][target['world_id']];p=target['gameplay']['combat_personal'];p['attack']={}
  target['gameplay']['body']['health']=12
  at={'x':target['x']-38,'y':target['y']}
  w['gameplay']['combat_world']['boars']={'native-fixture':{**at,'home_x':at['x'],'home_y':at['y'],'health':45.0,'mode':'attack','clock':0.37,'hit':0.0,'generation':0,'struck':False}}
  w['gameplay']['combat_world']['population_initialized']=True
  (folder/'boar-released').write_text('ready')
 return dispatch(self,op,data,token,ip)
server.Service.dispatch=isolated
server.main()
