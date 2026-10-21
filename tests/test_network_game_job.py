"""Windows server termination must release its private Godot worker."""
import ctypes
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT=Path(__file__).resolve().parents[1]

@unittest.skipUnless(os.name=="nt","Windows job ownership")
class JobOwnershipTest(unittest.TestCase):
    def test_forced_parent_stop_terminates_worker(self):
        with tempfile.TemporaryDirectory(prefix="windrest-job-") as temporary:
            folder=Path(temporary)
            script=folder/"parent.py"
            script.write_text("import sys,time\nfrom pathlib import Path\nsys.path.insert(0,"+repr(str(ROOT/"tools/network"))+")\nfrom game_host import GameHost\nhost=GameHost("+repr({"data_dir":temporary,"project":str(ROOT),"godot":"D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe"})+",{'id':'job-test','seed':271828,'map_cells':128})\nPath("+repr(str(folder/"pid"))+").write_text(str(host.process.pid))\ntime.sleep(120)\n",encoding="utf-8")
            parent=subprocess.Popen(["python",str(script)],creationflags=subprocess.CREATE_NO_WINDOW)
            worker=None
            try:
                deadline=time.monotonic()+120
                while not (folder/"pid").exists() and time.monotonic()<deadline and parent.poll() is None:time.sleep(.1)
                self.assertTrue((folder/"pid").exists(),"private worker did not boot")
                kernel=ctypes.WinDLL("kernel32",use_last_error=True)
                kernel.OpenProcess.restype=ctypes.c_void_p
                kernel.WaitForSingleObject.argtypes=[ctypes.c_void_p,ctypes.c_uint32]
                kernel.CloseHandle.argtypes=[ctypes.c_void_p]
                worker=kernel.OpenProcess(0x100000,False,int((folder/"pid").read_text()))
                self.assertTrue(worker)
                parent.kill();parent.wait(timeout=10)
                self.assertEqual(kernel.WaitForSingleObject(worker,10000),0,"orphan rules worker survived server shutdown")
            finally:
                if parent.poll() is None:parent.kill();parent.wait(timeout=10)
                if worker:kernel.CloseHandle(worker)

if __name__=="__main__":unittest.main()
