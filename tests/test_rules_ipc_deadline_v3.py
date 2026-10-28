import sys,unittest,struct,json
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/network'))
from game_host import GameHost
class DeadlineTests(unittest.TestCase):
 def test_continuous_fragments_cannot_extend_total_deadline(self):
  class Socket:
   now=0.0
   data=struct.pack('<I',11)+b'{"ok":true}'
   def settimeout(self,value):pass
   def recv(self,size):
    self.now+=.03
    part=self.data[:1];self.data=self.data[1:];return part
  sock=Socket();host=GameHost.__new__(GameHost);host.channel=sock;closed=[];host.close=lambda:closed.append(True)
  with patch('game_host.time.monotonic',side_effect=lambda:sock.now):
   with self.assertRaises(TimeoutError):host._receive(.05)
  self.assertEqual(closed,[True]);self.assertLessEqual(sock.now,.06)
if __name__=='__main__':unittest.main()
