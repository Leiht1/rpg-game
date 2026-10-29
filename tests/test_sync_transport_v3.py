"""Exercise negotiated state transport over real TLS, including stale/lost bases."""
import sys,json,copy,ssl,http.client,tempfile,threading,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/network'))
import server

class TransportTests(unittest.TestCase):
 def test_lost_concurrent_base_and_legacy(self):
  with tempfile.TemporaryDirectory() as folder:
   class Service:
    config={}
    state={'slots':[{'item_id':'wood','count':2}],'entities':{'a':{'open':False}},'removed':1}
    def handle(self,*args):return {'ok':True,'snapshot':copy.deepcopy(self.state)}
   svc=Service();svc.root=Path(folder);(svc.root/"Accounts").mkdir();cert,key=server.certificate(svc.root)
   ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);ctx.load_cert_chain(cert,key)
   httpd=server.ConcurrentTLSServer(('127.0.0.1',0),server.Handler);httpd.service=svc;httpd.tls_context=ctx;httpd.daemon_threads=True
   thread=threading.Thread(target=httpd.serve_forever,daemon=True);thread.start()
   client_ctx=ssl.create_default_context(cafile=str(cert));client_ctx.check_hostname=False
   conn=http.client.HTTPSConnection('127.0.0.1',httpd.server_port,context=client_ctx)
   def request(data):
    conn.request('POST','/api/game_snapshot',json.dumps(data),{'Content-Type':'application/json'})
    response=conn.getresponse();result=json.loads(response.read());self.assertEqual(response.status,200);return result
   try:
    first=request({'sync_delta':1});base=first['sync_tokens'];self.assertEqual(first['snapshot'],svc.state)
    self.assertEqual(request({'sync_delta':1,'sync_tokens':base})['snapshot'],{})
    svc.state['slots'][0]['count']=1;svc.state['entities']['a']['open']=True;del svc.state['removed']
    # A discarded reply cannot silently advance a server-owned client baseline.
    discarded=request({'sync_delta':1,'sync_tokens':base})
    retried=request({'sync_delta':1,'sync_tokens':base});self.assertEqual(discarded,retried)
    restored={k:v for k,v in first['snapshot'].items() if k in retried['sync_tokens']};restored.update(retried['snapshot']);self.assertEqual(restored,svc.state)
    self.assertNotIn('snapshot_delta',request({}))
    self.assertEqual(request({})['snapshot'],svc.state)
    self.assertEqual(request({'sync_delta':1,'sync_tokens':[]})['snapshot'],svc.state)
    self.assertEqual(request({'sync_delta':1})['snapshot'],svc.state)
   finally:
    conn.close();httpd.shutdown();httpd.server_close();thread.join()

if __name__=='__main__':unittest.main()
