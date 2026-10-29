"""An unfinished TLS client must not stall other clients' connections."""
import socket, ssl, sys, tempfile, threading, time, unittest, json
from concurrent.futures import ThreadPoolExecutor
from http.client import HTTPSConnection
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools/network"))
import server

class TLSTests(unittest.TestCase):
    def test_parallel_trace_records_remain_complete(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);(root/'Accounts').mkdir()
            cert,key=server.certificate(root)
            http=server.ConcurrentTLSServer(('127.0.0.1',0),server.Handler)
            context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(cert,key)
            http.tls_context=context;http.monitor=None
            class Service:
                config={'sync_trace_file':str(root/'trace.jsonl')}
                trace_lock=threading.Lock()
                def handle(self,*args):return {'ok':True}
            http.service=Service()
            thread=threading.Thread(target=http.serve_forever,daemon=True);thread.start()
            client=ssl.create_default_context(cafile=str(cert))
            def request(index):
                connection=HTTPSConnection('windrest-server',http.server_port,context=client,timeout=5)
                connection._create_connection=lambda *a,**kw:socket.create_connection(http.server_address,timeout=5)
                try:
                    connection.request('POST','/api/profile',body=json.dumps({'request_id':str(index)}))
                    response=connection.getresponse();response.read()
                    self.assertEqual(response.status,200)
                finally:connection.close()
            try:
                with ThreadPoolExecutor(max_workers=8) as pool:list(pool.map(request,range(24)))
                deadline=time.monotonic()+2
                while time.monotonic()<deadline:
                    with http.service.trace_lock:
                        rows=[json.loads(line) for line in (root/'trace.jsonl').read_text().splitlines()]
                    if len(rows)==24:break
                    time.sleep(.01)
                self.assertEqual({r['request_id'] for r in rows},{str(i) for i in range(24)})
                self.assertEqual(len(rows),24)
            finally:http.shutdown();http.server_close();thread.join(3)

    def test_persistent_tls_reuses_connection_and_preserves_errors(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder)/"Accounts").mkdir()
            cert,key=server.certificate(Path(folder))
            http=server.ConcurrentTLSServer(("127.0.0.1",0),server.Handler)
            context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(cert,key)
            http.tls_context=context
            peers=[]
            class Service:
                config={}
                def handle(self,op,*args):
                    if op=="rejected":raise server.Rejected("expected")
                    return {"ok":True}
            class Handler(server.Handler):
                def post_request(self):
                    peers.append((self.client_address,self.connection.getsockopt(socket.IPPROTO_TCP,socket.TCP_NODELAY)))
                    super().post_request()
            http.RequestHandlerClass=Handler;http.service=Service();http.monitor=None
            thread=threading.Thread(target=http.serve_forever,daemon=True);thread.start()
            client=ssl.create_default_context(cafile=str(cert))
            connection=HTTPSConnection("windrest-server",http.server_port,context=client,timeout=3)
            connection._create_connection=lambda *a,**kw:socket.create_connection(http.server_address,timeout=3)
            try:
                for op,status in [("profile",200),("rejected",400),("profile",200)]:
                    connection.request("POST","/api/"+op,body="{}")
                    reply=connection.getresponse();reply.read();self.assertEqual(reply.status,status)
                self.assertEqual(len({peer for peer,flag in peers}),1)
                self.assertTrue(all(flag==1 for peer,flag in peers))
            finally:
                connection.close();http.shutdown();http.server_close();thread.join(3)

    def test_slow_handshake_does_not_block_accept(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder)/"Accounts").mkdir()
            cert,key=server.certificate(Path(folder))
            http=server.ConcurrentTLSServer(("127.0.0.1",0),server.Handler)
            context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(cert,key)
            http.tls_context=context
            class Service:
                config={}
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
