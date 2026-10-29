"""Synchronization contracts independent of the Godot simulation."""
import sys
import threading
import time
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/network'))
from request_lock import RequestLock
from server import Service

class TransactionTests(unittest.TestCase):
    def test_recursive_condition_releases_and_restores(self):
        lock=RequestLock();condition=threading.Condition(lock);seen=threading.Event()
        def other():
            with condition:seen.set();condition.notify()
        lock.begin()
        with condition:
            with lock:
                thread=threading.Thread(target=other);thread.start()
                condition.wait_for(seen.is_set,timeout=1)
                self.assertTrue(seen.is_set());self.assertTrue(lock._is_owned())
            self.assertTrue(lock._is_owned())
        thread.join(1)
        self.assertFalse(lock._is_owned())
        self.assertGreaterEqual(lock.timings()['hold_ns'],0)

    def fixture(self):
        service=Service.__new__(Service);service.lock=RequestLock()
        service.queue_lock=threading.Lock();service.pending_commits=0
        service.request_ready=threading.Condition(service.lock)
        return service

    def test_busy_commit_times_out_without_ownership_or_stuck_priority(self):
        service=self.fixture();ready=threading.Event();release=threading.Event()
        def owner():
            with service.lock:ready.set();release.wait(2)
        thread=threading.Thread(target=owner);thread.start();self.assertTrue(ready.wait(1))
        try:
            began=time.perf_counter()
            with service.commit_slot() as acquired:self.assertFalse(acquired)
            self.assertLess(time.perf_counter()-began,.6)
            self.assertEqual(service.pending_commits,0)
            self.assertFalse(service.lock._is_owned())
        finally:release.set();thread.join(1)

    def test_completed_notification_does_not_wait_for_another_transaction(self):
        service=self.fixture();ready=threading.Event();release=threading.Event()
        def owner():
            with service.lock:ready.set();release.wait(2)
        thread=threading.Thread(target=owner);thread.start();self.assertTrue(ready.wait(1))
        try:
            began=time.perf_counter();service.notify_requests()
            self.assertLess(time.perf_counter()-began,.1)
        finally:release.set();thread.join(1)

    def test_busy_read_snapshot_defers_without_auth_state_or_world_mutation(self):
        service=self.fixture();service.config={'gameplay_preview':True};service.gameplay=object()
        ready=threading.Event();release=threading.Event()
        def owner():
            with service.lock:ready.set();release.wait(2)
        thread=threading.Thread(target=owner);thread.start();self.assertTrue(ready.wait(1))
        try:
            result=service.read_committed_snapshot({'protocol':1,'version':'0.1.0'},'unused')
            self.assertEqual(result,{'ok':True,'snapshot_pending':True})
        finally:release.set();thread.join(1)

if __name__=='__main__':unittest.main()
