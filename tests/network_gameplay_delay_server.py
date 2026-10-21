"""Test-only delayed service, always launched with an isolated configuration."""
from pathlib import Path
import sys
import time
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools/network"))
import server
index=sys.argv.index("--delay")
delay=float(sys.argv[index+1]);del sys.argv[index:index+2]
original=server.Handler.do_POST
def delayed(self):
    if self.path=="/api/move":time.sleep(delay)
    return original(self)
server.Handler.do_POST=delayed
handle=server.Service.handle
def diagnostic(self,*args,**kwargs):
    try:return handle(self,*args,**kwargs)
    except server.Rejected:raise
    except Exception:
        import traceback
        traceback.print_exc()
        raise
server.Service.handle=diagnostic
server.main()
