"""Per-request monotonic accounting; nested RLock acquisitions are not double counted."""
import threading
import time

class RequestLock:
    def __init__(self):
        self.raw=threading.RLock()
        self.local=threading.local()

    def begin(self):
        self.local.wait_ns=0
        self.local.hold_ns=0

    def acquire(self, blocking=True, timeout=-1):
        nested=self.raw._is_owned()
        start=time.perf_counter_ns()
        ok=self.raw.acquire(blocking,timeout)
        end=time.perf_counter_ns()
        if not nested:
            self.local.wait_ns=getattr(self.local,'wait_ns',0)+end-start
            if ok:self.local.held_at=end
        if ok:self.local.depth=getattr(self.local,'depth',0)+1
        return ok

    def release(self):
        if self.local.depth==1:
            self.local.hold_ns=getattr(self.local,'hold_ns',0)+time.perf_counter_ns()-self.local.held_at
        self.local.depth-=1
        self.raw.release()

    def _is_owned(self):return self.raw._is_owned()
    def _release_save(self):
        self.local.hold_ns=getattr(self.local,'hold_ns',0)+time.perf_counter_ns()-self.local.held_at
        depth=self.local.depth;self.local.depth=0
        return self.raw._release_save(),depth
    def _acquire_restore(self,state):
        raw_state,depth=state
        start=time.perf_counter_ns();self.raw._acquire_restore(raw_state)
        self.local.held_at=time.perf_counter_ns()
        self.local.depth=depth
        self.local.wait_ns=getattr(self.local,'wait_ns',0)+self.local.held_at-start
    def __enter__(self):self.acquire();return self
    def __exit__(self,*_):self.release()
    def timings(self):
        return {key:getattr(self.local,key,0)/1e6 for key in ('wait_ns','hold_ns')}
