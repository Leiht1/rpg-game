"""An unfinished TLS client must not stall other clients' connections."""
import socket, ssl, sys, tempfile, threading, time, unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools/network"))
import server

class TLSTests(unittest.TestCase):
    def test_slow_handshake_does_not_block_accept(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder)/"Accounts").mkdir()
            cert,key=server.certificate(Path(folder))
            http=server.ConcurrentTLSServer(("127.0.0.1",0),server.Handler)
            context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(cert,key)
            http.tls_context=context
            class Service:
                def handle(self,*args):return {"ok":True}
            http.service=Service()
            http.monitor=server.TrafficMonitor(Path(folder))
            thread=threading.Thread(target=http.serve_forever,daemon=True);thread.start()
            stalled=socket.create_connection(http.server_address,timeout=2)
            try:
                began=time.monotonic()
                client=ssl.create_default_context(cafile=str(cert))
                with socket.create_connection(http.server_address,timeout=2) as raw:
                    with client.wrap_socket(raw,server_hostname="windrest-server") as tls:
                        tls.sendall(b'POST /api/profile HTTP/1.0\r\nContent-Length: 2\r\n\r\n{}')
                        reply=tls.recv(1024)
                self.assertIn(b"200 OK",reply)
                deadline=time.monotonic()+1
                while http.monitor.total < 1 and time.monotonic()<deadline:time.sleep(.01)
                self.assertEqual(http.monitor.total,1)
                self.assertEqual(http.monitor.active,0)
                self.assertEqual(http.monitor.received,2)
                self.assertGreater(http.monitor.sent,0)
                self.assertEqual(http.monitor.events[-1]["operation"],"profile")
                self.assertNotIn("token",str(http.monitor.events))
                self.assertLess(time.monotonic()-began,2)
            finally:
                stalled.close();http.shutdown();http.server_close();thread.join(3)

if __name__=="__main__":unittest.main()
