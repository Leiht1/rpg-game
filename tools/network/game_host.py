"""Private persistent original-Godot gameplay rules process.

Requests restore the service's authoritative transaction snapshot. An aborted
SQLite transaction cannot leave an uncommitted reward in the rules host.
The directory is random and local; it is never served by the HTTP handler.
"""
import json
import os
from pathlib import Path
import secrets
import socket
import struct
import subprocess
import time


class GameHost:
    def __init__(self, config, world):
        self.folder = Path(config["data_dir"]).resolve()/"Runtime"/secrets.token_hex(24)
        self.folder.mkdir(parents=True)
        self.process = None
        self.job = None
        self.channel = None
        self.listener = socket.socket()
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen(1)
        self.listener.settimeout(120)
        nonce = secrets.token_hex(32)
        self.log = (self.folder/"host.log").open("wb")
        (self.folder/"bootstrap.json").write_text(json.dumps(dict(world, ipc_port=self.listener.getsockname()[1], ipc_nonce=nonce)), encoding="utf-8")
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
            self.channel, _ = self.listener.accept()
            self.channel.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            self.listener.close()
            ready = self._receive(120)
            if ready.get("ready") is not True or not secrets.compare_digest(str(ready.get("ipc_nonce", "")), nonce):
                raise RuntimeError("Private gameplay channel authentication failed")
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

    def _send(self, request):
        began = time.perf_counter()
        data = json.dumps(request, ensure_ascii=False, allow_nan=False).encode("utf-8")
        self.last_send = {"encode_ms": (time.perf_counter()-began)*1000, "request_bytes": len(data)}
        if len(data) > 8*1024*1024:
            raise ValueError("Gameplay request exceeds private channel limit")
        try:
            self.channel.sendall(struct.pack("<I", len(data))+data)
        except OSError:
            self.close()
            raise

    def _receive(self, timeout):
        deadline = time.monotonic()+timeout
        def exact(size):
            chunks = bytearray()
            while len(chunks) < size:
                remaining = deadline-time.monotonic()
                if remaining <= 0:
                    raise TimeoutError("Gameplay response exceeded its total deadline")
                self.channel.settimeout(remaining)
                part = self.channel.recv(size-len(chunks))
                if not part:
                    raise ConnectionError("Gameplay rules host disconnected; committed data was preserved")
                chunks.extend(part)
            return chunks
        try:
            size = struct.unpack("<I", exact(4))[0]
            if not 0 < size <= 8*1024*1024:
                raise ValueError("Invalid gameplay response size")
            return json.loads(exact(size))
        except BaseException:
            # A partial or timed-out reply must never become the next reply.
            self.close()
            raise

    def execute(self, snapshot=None, character=None, operation="snapshot", args=None, elapsed=0, shared=True, player_id="", station=None, expected=None, combat_peers=None, combat_damage=None):
        began=time.perf_counter()
        if self.process is None or self.process.poll() is not None:
            raise RuntimeError("Gameplay rules host is unavailable")
        request = {"snapshot": snapshot or {}, "character": character or {},
                   "operation": operation, "args": args or [], "elapsed": elapsed,
                   "shared": shared, "player_id": player_id, "station": station, "expected": expected or {}, "combat_peers":combat_peers or [], "combat_damage":combat_damage or []}
        self._send(request)
        result=self._receive(30)
        result["ipc_metrics"] = {**self.last_send, "total_ms": (time.perf_counter()-began)*1000}
        if os.environ.get("WINDREST_PROFILE_NETWORK")=="1":print("HOST_MS",operation,round((time.perf_counter()-began)*1000),flush=True)
        return result

    def close(self):
        if self.channel is not None:
            self.channel.close(); self.channel = None
        self.listener.close()
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
        for name in ("bootstrap.json",):
            (self.folder/name).unlink(missing_ok=True)

    def movement(self, world, character, inputs):
        request = {"operation": "movement", "character": character, "inputs": inputs,
                   "buildings": world["gameplay"]["buildings"]["objects"],
                   "exploration_chapter": world["gameplay"].get("exploration_chapter", {}),
                   "combat_world": world["gameplay"].get("combat_world", {}),
                   "harvested": world["gameplay"]["harvested"]}
        self._send(request)
        return self._receive(30)

    def __enter__(self):
        return self

    def __exit__(self, *unused):
        self.close()
