"""Private persistent original-Godot gameplay rules process.

Requests always restore the database's committed snapshot. Consequently an
aborted SQLite transaction cannot leave an uncommitted reward in the rules host.
The directory is random and local; it is never served by the HTTP handler.
"""
import json
import os
from pathlib import Path
import secrets
import subprocess
import time


class GameHost:
    def __init__(self, config, world):
        self.folder = Path(config["data_dir"]).resolve()/"Runtime"/secrets.token_hex(24)
        self.folder.mkdir(parents=True)
        self.process = None
        self.job = None
        self.log = (self.folder/"host.log").open("wb")
        (self.folder/"bootstrap.json").write_text(json.dumps(world), encoding="utf-8")
        try:
            executable = Path(config["godot"])
            # Godot's Windows console launcher can spawn another process. Own the
            # actual headless engine so shutdown waits for all open save/log handles.
            if executable.name.endswith("_console.exe"):
                engine = executable.with_name(executable.name.replace("_console.exe", ".exe"))
                if engine.is_file():
                    executable = engine
            self.process = subprocess.Popen(
                [str(executable), "--headless", "--path", config["project"],
                 "res://scenes/network_game_worker.tscn", "--", str(self.folder)],
                stdout=self.log, stderr=self.log,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
            if os.name == "nt":self._own_windows_child()
            self._receive(120)
        except BaseException:
            self.close()
            raise

    def _own_windows_child(self):
        # Closing the server process also closes this job handle, so Windows
        # terminates the private rules child even after a crash or forced stop.
        import ctypes
        from ctypes import wintypes
        class Basic(ctypes.Structure):
            _fields_=[("process_time",ctypes.c_int64),("job_time",ctypes.c_int64),
                      ("flags",wintypes.DWORD),("minimum",ctypes.c_size_t),("maximum",ctypes.c_size_t),
                      ("active",wintypes.DWORD),("affinity",ctypes.c_size_t),
                      ("priority",wintypes.DWORD),("scheduling",wintypes.DWORD)]
        class Extended(ctypes.Structure):
            _fields_=[("basic",Basic),("io",ctypes.c_uint64*6),
                      ("process_memory",ctypes.c_size_t),("job_memory",ctypes.c_size_t),
                      ("peak_process",ctypes.c_size_t),("peak_job",ctypes.c_size_t)]
        kernel=ctypes.WinDLL("kernel32",use_last_error=True)
        kernel.CreateJobObjectW.argtypes=[ctypes.c_void_p,wintypes.LPCWSTR]
        kernel.CreateJobObjectW.restype=wintypes.HANDLE
        kernel.SetInformationJobObject.argtypes=[wintypes.HANDLE,ctypes.c_int,ctypes.c_void_p,wintypes.DWORD]
        kernel.AssignProcessToJobObject.argtypes=[wintypes.HANDLE,wintypes.HANDLE]
        self.job=kernel.CreateJobObjectW(None,None)
        if not self.job:raise ctypes.WinError(ctypes.get_last_error())
        limits=Extended();limits.basic.flags=0x2000
        if not kernel.SetInformationJobObject(self.job,9,ctypes.byref(limits),ctypes.sizeof(limits)) or not kernel.AssignProcessToJobObject(self.job,int(self.process._handle)):
            raise ctypes.WinError(ctypes.get_last_error())

    def _receive(self, timeout):
        result = self.folder/"result.json"
        deadline = time.monotonic()+timeout
        while time.monotonic() < deadline:
            if result.exists():
                try:
                    value = json.loads(result.read_text(encoding="utf-8"))
                    result.unlink()
                    return value
                except PermissionError:
                    # Windows scanners can briefly retain a renamed mailbox.
                    # Finish consuming this reply before accepting another call.
                    time.sleep(.01)
                    continue
                except BaseException:
                    self.close()
                    raise
            if self.process.poll() is not None:
                raise RuntimeError("Gameplay rules host exited; committed data was preserved")
            time.sleep(.01)
        # A timed-out command must never be mistaken for the next command's reply.
        self.close()
        raise TimeoutError("Gameplay rules host timed out; committed data was preserved")

    def execute(self, snapshot=None, character=None, operation="snapshot", args=None, elapsed=0, shared=True, player_id="", station=None, expected=None):
        if self.process is None or self.process.poll() is not None:
            raise RuntimeError("Gameplay rules host is unavailable")
        request = {"snapshot": snapshot or {}, "character": character or {},
                   "operation": operation, "args": args or [], "elapsed": elapsed,
                   "shared": shared, "player_id": player_id, "station": station, "expected": expected or {}}
        temporary = self.folder/"request.tmp"
        temporary.write_text(json.dumps(request, ensure_ascii=False, allow_nan=False), encoding="utf-8")
        os.replace(temporary, self.folder/"request.json")
        return self._receive(30)

    def close(self):
        if self.process is not None and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)
        if self.job is not None:
            import ctypes
            ctypes.windll.kernel32.CloseHandle(ctypes.c_void_p(self.job));self.job=None
        self.log.close()
        # Logs are retained on failure for diagnosis; they contain no credentials.
        for name in ("request.json", "request.tmp", "result.json", "result.tmp", "bootstrap.json"):
            (self.folder/name).unlink(missing_ok=True)

    def movement(self, world, character, inputs):
        request = {"operation": "movement", "character": character, "inputs": inputs,
                   "buildings": world["gameplay"]["buildings"]["objects"],
                   "harvested": world["gameplay"]["harvested"]}
        temporary = self.folder/"request.tmp"
        temporary.write_text(json.dumps(request, ensure_ascii=False, allow_nan=False), encoding="utf-8")
        os.replace(temporary, self.folder/"request.json")
        return self._receive(30)

    def __enter__(self):
        return self

    def __exit__(self, *unused):
        self.close()
