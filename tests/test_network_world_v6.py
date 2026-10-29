"""World rule work must run outside the state lock; commit remains durable."""
import copy,sys,tempfile,time,threading,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools/network'))
from server import Service

class Rules:
    def __init__(self,config=None):self.clocks={'w':time.monotonic()-2};self.calls=[];self.hook=None
    def prepare(self,world):pass
    def apply(self,w,c,operation='snapshot',args=None,elapsed=0,shared=True,**kw):
        self.calls.append((c['id'],operation,elapsed,shared))
        if self.hook:self.hook()
        if operation!='snapshot':c['slots'][8]={'item_id':'branch','count':c['slots'][8].get('count',0)+1}
        if elapsed:c['gameplay']['elapsed']=c['gameplay'].get('elapsed',0)+elapsed
        c['gameplay']['slots']=copy.deepcopy(c['slots'])
        return {'ok':True,'snapshot':self.snapshot(w,c),'events':[]}
    def snapshot(self,w,c):return {**copy.deepcopy(w['gameplay']),**copy.deepcopy(c['gameplay'])}
    def close(self):pass

class WorldTransactions(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='world-v6-');self.s=Service({'data_dir':self.tmp.name})
        self.s.config['gameplay_preview']=True;self.s.gameplay=Rules();self.s.tick_gameplay=Rules()
        self.s.state['worlds']['w']={'id':'w','seed':1,'map_cells':128,'gameplay':{'value':0},'exploration':[]}
        for i in range(2):
            cid='c'+str(i);aid='a'+str(i);slots=[{} for _ in range(40)]
            self.s.state['characters'][cid]={'id':cid,'world_id':'w','x':10,'y':20,'slots':slots,'equipment':{},'hotbar_equipment':{},'selected':0,'gameplay':{'slots':copy.deepcopy(slots),'body':{},'combat_personal':{'phase':'alive'},'player_position':{'x':10,'y':20}}}
            self.s.state['accounts'][aid]={'id':aid,'world_id':'w','player_id':cid,'enabled':True,'nickname':aid}
            self.s.sessions['t'+str(i)]={'account':aid,'entered':True,'seen':time.monotonic(),'expires':time.monotonic()+100,'seq':-1,'input_ack':0}
    def tearDown(self):self.s.db.close();self.tmp.cleanup()
    def command(self):return self.s.handle('game_command',{'protocol':1,'version':'0.1.0','operation':'interact','args':[{'drop_id':'d'}],'request_id':'a'*32},'t0')
    def test_entry_waits_for_both_authorities_outside_state_lock(self):
        prepared=threading.Event();ready=threading.Event()
        def clock_prepare(world):
            self.assertFalse(self.s.lock._is_owned())
            prepared.set();self.assertTrue(ready.wait(2))
        def command_prepare(world):
            self.assertFalse(self.s.lock._is_owned())
            self.assertTrue(prepared.wait(2));ready.set()
        self.s.tick_gameplay.prepare=clock_prepare
        self.s.gameplay.prepare=command_prepare
        self.s.gameplay.inventory_host=lambda cid:None
        with patch.object(self.s,'handle_locked',side_effect=lambda *args: {'ok':ready.is_set()}):
            self.assertTrue(self.s.handle('character',{'protocol':1,'version':'0.1.0'},'t0')['ok'])
    def test_first_snapshot_restores_authority_without_advancing_time(self):
        self.s.sessions['t0']['game_fresh']=True;clock=self.s.gameplay.clocks['w']
        request={'protocol':1,'version':'0.1.0'}
        self.s.handle('game_snapshot',request,'t0')
        self.assertEqual(self.s.gameplay.calls,[('c0','snapshot',0,False)])
        self.assertEqual(self.s.gameplay.clocks['w'],clock)
        self.s.handle('game_snapshot',request,'t0')
        self.assertEqual(len(self.s.gameplay.calls),1,'Ordinary snapshots must not repeat rule restoration')
    def test_command_one_ipc_no_elapsed_and_no_state_lock(self):
        self.s.gameplay.hook=lambda:self.assertFalse(self.s.lock._is_owned())
        self.assertTrue(self.command()['ok'])
        self.assertEqual(self.s.gameplay.calls,[('c0','interact',0,False)])
        self.assertEqual(self.s.state['characters']['c0']['slots'][8]['count'],1)
        self.assertTrue(self.command()['ok'])
        self.assertEqual(self.s.state['characters']['c0']['slots'][8]['count'],1)
    def test_tick_world_conflict_discards_without_consuming_clock(self):
        clock=self.s.gameplay.clocks['w'];began=threading.Event();release=threading.Event();result=[]
        def blocked():began.set();self.assertTrue(release.wait(2))
        self.s.tick_gameplay.hook=blocked
        thread=threading.Thread(target=lambda:result.append(self.s.advance_world_tick('w')));thread.start()
        self.assertTrue(began.wait(1))
        with self.s.lock:self.s.state['worlds']['w']['gameplay']['value']=7
        release.set();thread.join(3)
        self.assertEqual(result,[False]);self.assertEqual(self.s.gameplay.clocks['w'],clock)
        self.assertNotIn('elapsed',self.s.state['characters']['c0']['gameplay'])
        self.s.tick_gameplay.hook=lambda:self.assertFalse(self.s.lock._is_owned())
        self.assertTrue(self.s.advance_world_tick('w'))
        self.assertEqual(self.s.state['worlds']['w']['gameplay']['value'],7)
        self.assertGreater(self.s.state['characters']['c0']['gameplay']['elapsed'],0)
        calls=self.s.tick_gameplay.calls[-2:]
        self.assertEqual(sum(row[3] for row in calls),1,'Shared world must advance once, not per player')
    def test_tick_merges_ordinary_motion_without_teleporting(self):
        self.s.state['characters']['c0']['gameplay']['combat_personal']['attack']={'active':True}
        def moved():
            with self.s.lock:
                c=self.s.state['characters']['c0'];c['x']=99
                c['pose']={'action':'pickup','clock':.25,'facing':'right'}
        self.s.tick_gameplay.hook=moved
        self.assertTrue(self.s.advance_world_tick('w'))
        self.assertEqual(self.s.state['characters']['c0']['x'],99)
        self.assertEqual(self.s.state['characters']['c0']['gameplay']['player_position']['x'],99)
        self.assertEqual(self.s.state['characters']['c0']['pose'],{'action':'pickup','clock':.25,'facing':'right'})
    def test_tick_authoritative_relocation_overrides_later_motion(self):
        original=self.s.tick_gameplay.apply
        def relocate(w,c,**kw):
            result=original(w,c,**kw)
            if c['id']=='c0':c['x']=30
            return result
        def moved():
            with self.s.lock:self.s.state['characters']['c0']['x']=99
        self.s.tick_gameplay.hook=moved;self.s.tick_gameplay.apply=relocate
        self.assertTrue(self.s.advance_world_tick('w'))
        self.assertEqual(self.s.state['characters']['c0']['x'],30)
        self.assertEqual(self.s.state['characters']['c0']['gameplay']['player_position']['x'],30)
    def test_tick_save_failure_rolls_back_state_and_clock(self):
        before=copy.deepcopy(self.s.state);clock=self.s.gameplay.clocks['w']
        with patch.object(self.s,'save',side_effect=OSError('disk')):
            with self.assertRaises(OSError):self.s.advance_world_tick('w')
        self.assertEqual(self.s.state,before);self.assertEqual(self.s.gameplay.clocks['w'],clock)
    def test_tick_keeps_idle_bag_commit_and_monotonic_revision(self):
        def bag():
            with self.s.lock:
                c=self.s.state['characters']['c0'];c['slots'][8]={'item_id':'wood','count':7};c['gameplay']['slots']=copy.deepcopy(c['slots']);c['_personal_revision']=9
        self.s.tick_gameplay.hook=bag
        self.assertTrue(self.s.advance_world_tick('w'))
        c=self.s.state['characters']['c0'];self.assertEqual(c['slots'][8]['count'],7);self.assertEqual(c['_personal_revision'],10)
    def test_tick_cannot_overwrite_inventory_consumed_by_rules(self):
        original=self.s.tick_gameplay.apply
        def consume(w,c,**kw):
            result=original(w,c,**kw);c['slots'][8]={'item_id':'branch','count':1};return result
        self.s.tick_gameplay.apply=consume
        def bag():
            with self.s.lock:self.s.state['characters']['c0']['slots'][8]={'item_id':'wood','count':7}
        self.s.tick_gameplay.hook=bag
        self.assertFalse(self.s.advance_world_tick('w'))
        self.assertEqual(self.s.state['characters']['c0']['slots'][8]['count'],7)
    def test_repeated_tick_conflict_reserves_writer_outside_state_lock(self):
        self.s.tick_conflicts['w']=2
        def reserved():
            self.assertTrue(self.s.world_rules_lock._is_owned());self.assertFalse(self.s.lock._is_owned())
        self.s.tick_gameplay.hook=reserved
        self.assertTrue(self.s.advance_world_tick('w'));self.assertEqual(self.s.tick_conflicts['w'],0)
    def test_command_conflict_recomputes_and_keeps_other_inventory(self):
        def change_once():
            self.s.gameplay.hook=None
            with self.s.lock:self.s.state['characters']['c1']['slots'][8]={'item_id':'wood','count':7}
        self.s.gameplay.hook=change_once
        self.command()
        self.assertEqual(len(self.s.gameplay.calls),2)
        self.assertEqual(self.s.state['characters']['c1']['slots'][8]['count'],7)
        self.assertEqual(self.s.state['characters']['c0']['slots'][8]['count'],1)
    def test_command_save_failure_no_receipt_or_reward_then_retry_once(self):
        before=copy.deepcopy(self.s.state)
        with patch.object(self.s,'save',side_effect=OSError('disk')):
            with self.assertRaises(OSError):self.command()
        self.assertEqual(self.s.state,before)
        self.command();self.command()
        self.assertEqual(self.s.state['characters']['c0']['slots'][8]['count'],1)

if __name__=='__main__':unittest.main()
