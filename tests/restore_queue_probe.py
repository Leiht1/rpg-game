import sys,threading,time,json,runpy,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools/network'))
from server import Service
from game_host import GameHost
rows=[];pending={};lock=threading.Lock();local=threading.local();original=Service.handle;execute=GameHost.execute

def handle(self,op,data,*args,**kwargs):
 row={'id':uuid.uuid4().hex,'op':op,'thread':threading.get_ident(),'queued_ns':time.perf_counter_ns(),'spans':[]}
 with lock:
  row['queue_depth']=len(pending);row['oldest_wait_ms']=max([(row['queued_ns']-r['queued_ns'])/1e6 for r in pending.values()]+[0]);pending[row['id']]=row
 local.row=row
 try:return original(self,op,data,*args,**kwargs)
 except BaseException as exc:row['error']=type(exc).__name__;raise
 finally:
  row['finished_ns']=time.perf_counter_ns()
  with lock:pending.pop(row['id']);rows.append(row)
  local.row=None

def rules(self,*args,**kwargs):
 row=getattr(local,'row',None);start=time.perf_counter_ns()
 try:return execute(self,*args,**kwargs)
 finally:
  if row is not None:row['spans'].append({'stage':'rules_ipc','start_ns':start,'end_ns':time.perf_counter_ns(),'pid':self.process.pid,'exit':self.process.poll()})
def stage(cls,name,label):
 original=getattr(cls,name)
 def wrapped(self,*args,**kwargs):
  start=time.perf_counter_ns();row=getattr(local,'row',None)
  try:return original(self,*args,**kwargs)
  finally:
   if row is not None:row['spans'].append({'stage':label,'start_ns':start,'end_ns':time.perf_counter_ns()})
 setattr(cls,name,wrapped)
Service.handle=handle;GameHost.execute=rules
stage(Service,'handle_locked','transaction_after_queue')
stage(Service,'dispatch','dispatch')
stage(GameHost,'_send','tcp_send')
stage(GameHost,'_receive','tcp_response_wait')
try:runpy.run_path(str(ROOT/'tests/network_latency_load.py'),run_name='__main__')
finally:(ROOT/'reports/interaction-latency-audit/round3-queue.json').write_text(json.dumps(rows),encoding='utf-8')
