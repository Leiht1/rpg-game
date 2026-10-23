"""Large gameplay replies negotiate compression without changing their JSON."""
import gzip
import http.client
import json
from pathlib import Path
import sys
import threading
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools/network"))
import server


class CompressionTests(unittest.TestCase):
    def test_negotiation_and_payload(self):
        payload={"ok":True,"snapshot":{"world_exploration":{"bits":"A"*393216},"label":"出生点"}}
        class Service:
            def handle(self,*args):return payload
        listener=server.ThreadingHTTPServer(("127.0.0.1",0),server.Handler)
        listener.service=Service()
        worker=threading.Thread(target=listener.serve_forever,daemon=True);worker.start()
        try:
            for accept,compressed in [("gzip, deflate",True),("gzip;q=0",False),("gzip;q=0.0",False),("identity",False),("",False)]:
                connection=http.client.HTTPConnection(*listener.server_address,timeout=3)
                connection.request("POST","/api/game_snapshot",body="{}",headers={"Accept-Encoding":accept})
                reply=connection.getresponse();body=reply.read()
                self.assertEqual(reply.status,200)
                self.assertEqual(reply.getheader("Content-Encoding"),"gzip" if compressed else None)
                if compressed:
                    self.assertLess(len(body),len(json.dumps(payload).encode())*.02)
                    body=gzip.decompress(body)
                self.assertEqual(json.loads(body),payload)
                connection.close()
        finally:
            listener.shutdown();listener.server_close();worker.join(3)

if __name__=="__main__":unittest.main()

