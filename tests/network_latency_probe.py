"""Isolated service-stage probe. Does not measure TLS or rendered UI latency.

Run with --seconds 300 for each 1/2/4 caller group. Raw monotonic spans
contain no tokens, credentials, inventory contents or player identifiers.
"""
import json
import runpy
import sys
import threading
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/network'))
from server import Service
from game_host import GameHost

local = threading.local()
rows = []
rows_lock = threading.Lock()


def stage(cls, name, label):
    original = getattr(cls, name)
    def wrapped(self, *args, **kwargs):
        row = getattr(local, 'row', None)
        if row is None:
            return original(self, *args, **kwargs)
        start = time.perf_counter_ns()
        try:
            return original(self, *args, **kwargs)
        finally:
            row['spans'].append([label, start, time.perf_counter_ns()])
    setattr(cls, name, wrapped)


original_handle = Service.handle
def handle(self, op, data, *args, **kwargs):
    row = {'request_id': uuid.uuid4().hex, 'op': op,
           'start_ns': time.perf_counter_ns(), 'spans': []}
    local.row = row
    try:
        result = original_handle(self, op, data, *args, **kwargs)
        row['ok'] = result.get('ok', False)
        return result
    except BaseException as exc:
        row['error_type'] = type(exc).__name__
        raise
    finally:
        row['end_ns'] = time.perf_counter_ns()
        local.row = None
        with rows_lock:
            rows.append(row)


if __name__ == '__main__':
    Service.handle = handle
    # handle_locked is entered after the outer Condition has acquired the lock.
    stage(Service, 'handle_locked', 'transaction')
    stage(Service, 'dispatch', 'dispatch')
    stage(Service, 'save', 'sqlite_serialize_commit')
    stage(GameHost, 'execute', 'godot_ipc_execute')
    try:
        runpy.run_path(str(ROOT / 'tests/network_latency_load.py'), run_name='__main__')
    finally:
        output = ROOT / 'reports/network-performance-v7/latency-stage-raw.json'
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps({'clock': 'perf_counter_ns',
            'scope': 'local service calls; movement and snapshot only',
            'requests': rows}, indent=2), encoding='utf-8')
