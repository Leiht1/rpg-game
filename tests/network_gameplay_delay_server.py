"""Test-only delayed service, always launched with an isolated configuration."""
from pathlib import Path
import sys
import time
import os
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools/network"))
import server
index=sys.argv.index("--delay")
delay=float(sys.argv[index+1]);del sys.argv[index:index+2]
delay_scope="move"
if "--delay-scope" in sys.argv:
    index=sys.argv.index("--delay-scope")
    delay_scope=sys.argv[index+1];del sys.argv[index:index+2]
original=server.Handler.do_POST
def delayed(self):
    if self.path=="/api/move" or (delay_scope=="gameplay" and self.path in ("/api/game_snapshot","/api/game_command","/api/poll")):time.sleep(delay)
    return original(self)
server.Handler.do_POST=delayed
handle=server.Service.handle
def diagnostic(self,*args,**kwargs):
    began=time.perf_counter()
    try:return handle(self,*args,**kwargs)
    except server.Rejected:raise
    except Exception:
        import traceback
        traceback.print_exc()
        raise
    finally:
        if os.environ.get("WINDREST_PROFILE_NETWORK")=="1":print("SERVICE_MS",args[0],round((time.perf_counter()-began)*1000),flush=True)
server.Service.handle=diagnostic
server.main()
