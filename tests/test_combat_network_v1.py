"""Private real Godot rules host and server transaction checks for combat."""
import copy,json,os,sys,tempfile,time,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/network'))
from game_host import GameHost
from gameplay import Gameplay,validate
import server

class CombatNetworkTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory(prefix='windrest-combat-')
  cls.config={'data_dir':cls.tmp.name,'godot':os.environ.get('WINDREST_GODOT','D:/Godot/Godot_v4.7.2-stable_win64_console.exe'),'project':str(ROOT)}
  cls.host=GameHost(cls.config,{'id':'combat-network-isolated','seed':271828,'map_cells':128})
  cls.base=cls.host.execute()['snapshot']
 @classmethod
 def tearDownClass(cls):cls.host.close();cls.tmp.cleanup()
 def fresh(self):
  s=copy.deepcopy(self.base);s['combat_personal']['phase']='alive';return s
 def building(self,kind):
  s=self.fresh();d=json.loads((ROOT/'data/camp_buildings.json').read_text(encoding='utf-8'))[kind]
  x=s['player_position']['x']+60;y=s['player_position']['y']
  row={'kind':kind,'layer':d['layer'],'x':x,'y':y,'gx':int(x//96),'gy':int(y//64),'vertical':False,'open':False,'inward':False,'facing':0,'hits':0,'contents':[{} for _ in range(d.get('storage_slots',12))]}
  if kind=='advanced_smokehouse':row['expansion']={'version':1,'fuel_items':{},'job':{}}
  s['buildings']['objects']={'fixture':row};return s
 def test_free_pvp_requires_no_consent_and_hits_once(self):
  s=self.fresh();p=s['player_position'];peer={'id':'second','x':p['x']+28,'y':p['y'],'phase':'alive'}
  r=self.host.execute(s,player_id='first',combat_peers=[peer],operation='combat_attack',args=[{'x':1,'y':0}]);self.assertTrue(r['ok'],r)
  r=self.host.execute(r['snapshot'],player_id='first',combat_peers=[peer],elapsed=.17);self.assertEqual(r['combat_damage'],[])
  r=self.host.execute(r['snapshot'],player_id='first',combat_peers=[peer],elapsed=.04);self.assertEqual(len(r['combat_damage']),1);self.assertFalse(r['combat_damage'][0]['duel'])
  r=self.host.execute(r['snapshot'],player_id='first',combat_peers=[peer],elapsed=.02);self.assertEqual(r['combat_damage'],[])
 def test_duel_nonlethal_and_formal_death_reconnect(self):
  s=self.fresh();s['body']['health']=3;s['slots'][8]={'item_id':'wood','count':9};s['slots'][9]={'item_id':'boar_tusk','count':2}
  hit={'target':'first','amount':12,'source':s['player_position'],'duel':True}
  r=self.host.execute(s,player_id='first',combat_damage=[hit]);self.assertTrue(r['ok'],r);self.assertEqual(r['snapshot']['body']['health'],1);self.assertEqual(r['snapshot']['combat_world']['relics'],{})
  hit['duel']=False;r=self.host.execute(r['snapshot'],player_id='first',combat_damage=[hit]);self.assertTrue(r['ok'],r)
  s=r['snapshot'];self.assertEqual(s['combat_personal']['phase'],'dying');self.assertEqual(len(s['combat_world']['relics']),1);self.assertEqual(s['slots'][8],{});self.assertEqual(s['slots'][9]['count'],2)
  again=self.host.execute(s,player_id='first',combat_damage=[hit]);self.assertEqual(len(again['snapshot']['combat_world']['relics']),1)
  r=self.host.execute(s,player_id='first',elapsed=3.1);self.assertEqual(r['snapshot']['body']['health'],100);self.assertEqual(r['snapshot']['combat_personal']['phase'],'entering')
  r=self.host.execute(r['snapshot'],player_id='first',elapsed=1.1);self.assertEqual(r['snapshot']['combat_personal']['phase'],'alive')
 def test_relic_public_and_partial_claim(self):
  s=self.fresh();p=s['player_position'];s['combat_world']['relics']={'r':{**p,'owner':'first','contents':[{'item_id':'wood','count':9}]}}
  s['slots']=[{'item_id':'stone','count':99} for i in range(40)];s['slots'][8]={'item_id':'wood','count':98}
  r=self.host.execute(s,player_id='second',operation='relic_claim',args=['r',0,{'item_id':'wood','count':9}]);self.assertTrue(r['ok'],r);self.assertEqual(r['snapshot']['combat_world']['relics']['r']['contents'][0]['count'],8)
  r=self.host.execute(s,player_id='first',operation='relic_claim',args=['r',0,{'item_id':'wood','count':9}]);self.assertTrue(r['ok'],r);self.assertEqual(r['snapshot']['slots'][8]['count'],99);self.assertEqual(r['snapshot']['combat_world']['relics']['r']['contents'][0]['count'],8)
 def boar_fixture(self,night=False):
  s=self.fresh();p=s['player_position'];x=p['x']+140;y=p['y']
  s['combat_world'].update(population_initialized=True,population_revision=2,boars={'fixture':{'x':x,'y':y,'home_x':x,'home_y':y,'health':45,'mode':'chase','clock':1.0,'hit':0.0,'generation':0}})
  s['body_environment']['minute']=1320 if night else 720
  return s
 def test_night_boar_speed_and_population_preservation(self):
  day=self.boar_fixture();night=self.boar_fixture(True)
  d=self.host.execute(day,elapsed=.1)['snapshot']['combat_world']['boars']['fixture']
  n=self.host.execute(night,elapsed=.1)['snapshot']['combat_world']['boars']['fixture']
  origin=day['combat_world']['boars']['fixture']['x']
  self.assertAlmostEqual((origin-n['x'])/(origin-d['x']),1.2,places=3)
 def test_boar_tramples_crop_without_rewards(self):
  s=self.boar_fixture();b=s['combat_world']['boars']['fixture'];defs=json.loads((ROOT/'data/camp_buildings.json').read_text(encoding='utf-8'))
  s['buildings']['objects']={'plot':{'kind':'tilled_soil','layer':defs['tilled_soil']['layer'],'x':b['x'],'y':b['y'],'gx':int(b['x']//96),'gy':int(b['y']//64),'vertical':False,'open':False,'inward':False,'facing':0,'hits':0,'contents':[{} for _ in range(12)],'crop':'carrot','growth_minutes':0.0,'roots':False,'fertilized':True}}
  plot=s['buildings']['objects']['plot'];plot['x']=plot['gx']*96+48;plot['y']=plot['gy']*64+32
  b.update(x=plot['x'],y=plot['y'],home_x=plot['x'],home_y=plot['y'])
  # Use the configured crop ID rather than a display name.
  crops=json.loads((ROOT/'data/planting.json').read_text(encoding='utf-8'))['crops']
  s['buildings']['objects']['plot']['crop']=next(iter(crops))
  r=self.host.execute(s,elapsed=.1);self.assertTrue(r['ok'],r)
  plot=r['snapshot']['buildings']['objects']['plot']
  self.assertEqual(plot['crop'],'');self.assertTrue(plot['roots']);self.assertEqual(plot['growth_minutes'],0)
  self.assertFalse(plot.get('fertilized',False));self.assertEqual(s['slots'],r['snapshot']['slots'])
  for kind in ('stone_wall','wood_fence'):
   fenced=copy.deepcopy(s);plot=fenced['buildings']['objects']['plot'];boar=fenced['combat_world']['boars']['fixture']
   boar.update(x=plot['x']+72,y=plot['y'],home_x=plot['x']+72,home_y=plot['y'])
   wall={'kind':kind,'layer':'edge','x':plot['x']+48,'y':plot['y'],'gx':plot['gx']+1,'gy':plot['gy'],'vertical':True,'open':False,'inward':False,'facing':0,'hits':0,'contents':[{} for _ in range(12)]}
   fenced['buildings']['objects']['wall']=wall
   r=self.host.execute(fenced,elapsed=1);self.assertTrue(r['ok'],r)
   self.assertNotEqual(r['snapshot']['buildings']['objects']['plot']['crop'],'')
   self.assertEqual(r['snapshot']['buildings']['objects']['wall']['hits'],0)
   self.assertGreater(r['snapshot']['combat_world']['boars']['fixture']['x'],wall['x'])
 def test_population_revision_preserves_existing_boars(self):
  s=self.boar_fixture();s['combat_world']['population_revision']=1
  s['combat_world']['boars']['fixture'].update(health=0,respawn=123,dropped=True,generation=7)
  r=self.host.execute(s,elapsed=.1);self.assertTrue(r['ok'],r)
  b=r['snapshot']['combat_world']['boars']['fixture']
  self.assertEqual(b['health'],0);self.assertEqual(b['generation'],7);self.assertAlmostEqual(b['respawn'],122.9)
  self.assertEqual(r['snapshot']['combat_world']['population_revision'],2)

 def test_invalid_command_never_accepts_damage(self):
  with self.assertRaises(ValueError):validate('combat_damage',[{'amount':999}])
  with self.assertRaises(ValueError):validate('combat_attack',[{'x':float('nan'),'y':0}])
  for direction in [{},{'x':True,'y':0},{'x':[],'y':0},{'x':0,'y':0},{'x':2,'y':0}]:
   with self.assertRaises(ValueError):validate('combat_attack',[direction])
 def test_legacy_snapshot_and_malformed_combat(self):
  s=self.fresh();s.pop('combat_world');s.pop('combat_personal');s['body']['health']=8;s['body']['down']=True
  r=self.host.execute(s);self.assertTrue(r['ok'],r);self.assertFalse(r['snapshot']['body']['down'])
  s=self.fresh();s['combat_personal']['clock']=-1
  r=self.host.execute(s);self.assertFalse(r['ok'])
 def test_smoking_whitelist_ready_claim_and_rotten_rejection(self):
  for source,output in [('roasted_fish','smoked_fish'),('boar_meat','cured_pork'),('meatballs','smoked_meatballs')]:
   with self.subTest(source=source):
    s=self.building('advanced_smokehouse');s['slots'][8]={'item_id':source,'count':1,'spoilage':0};s['slots'][9]={'item_id':'wood','count':2}
    r=self.host.execute(s,operation='expansion',args=['fixture','process',8,s['slots'][8],'',1]);self.assertTrue(r['ok'],r)
    after=r['snapshot'];job=after['buildings']['objects']['fixture']['expansion']['job'];self.assertEqual(job['output']['item_id'],output);self.assertEqual(after['slots'][8],{})
    job['minutes']=119.99
    r=self.host.execute(after,elapsed=.1);self.assertTrue(r['ok'],r);after=r['snapshot'];self.assertTrue(after['buildings']['objects']['fixture']['expansion']['job']['ready'])
    r=self.host.execute(after,operation='expansion',args=['fixture','claim',-1,{},'',1]);self.assertTrue(r['ok'],r)
    self.assertEqual(sum(v.get('count',0) for v in r['snapshot']['slots'] if v.get('item_id')==output),1)
  for source,spoilage in [('carrot_pork',0),('boar_meat',1),('meatballs',1),('roasted_fish',1)]:
   s=self.building('advanced_smokehouse');s['slots'][8]={'item_id':source,'count':1,'spoilage':spoilage};s['slots'][9]={'item_id':'wood','count':2}
   r=self.host.execute(s,operation='expansion',args=['fixture','process',8,s['slots'][8],'',1]);self.assertFalse(r['ok']);self.assertEqual(r['snapshot']['slots'],s['slots'])
 def test_cooking_meatballs_and_carrot_pork(self):
  for recipe,materials,output,seconds in [('boar_meatballs',{'boar_meat':2},'meatballs',24),('boar_carrot',{'boar_meat':1,'wild_carrot':1},'carrot_pork',28)]:
   s=self.fresh();p=s['player_position'];s['campfires']['objects']={'fire':{**p,'fuel':300.0,'lit':True,'recipe':'','elapsed':0.0,'ready':False}}
   for i,(id,count) in enumerate(materials.items()):s['slots'][8+i]={'item_id':id,'count':count,**({'spoilage':0} if id=='boar_meat' else {})}
   r=self.host.execute(s,operation='camp_act',args=['fire','cook',recipe,{}]);self.assertTrue(r['ok'],r)
   after=r['snapshot'];after['campfires']['objects']['fire']['elapsed']=seconds-.01
   r=self.host.execute(after,elapsed=.1);self.assertTrue(r['ok'],r);after=r['snapshot'];self.assertTrue(after['campfires']['objects']['fire']['ready'])
   r=self.host.execute(after,operation='camp_act',args=['fire','claim','',{}]);self.assertTrue(r['ok'],r);self.assertEqual(sum(v.get('count',0) for v in r['snapshot']['slots'] if v.get('item_id')==output),1)
 def test_medical_kit_and_full_health(self):
  s=self.fresh();s['body']['health']=20;s['slots'][8]={'item_id':'medical_kit','count':2}
  r=self.host.execute(s,operation='inventory',args=['use_slot',8]);self.assertTrue(r['ok'],r);self.assertEqual(r['snapshot']['body']['health'],75);self.assertEqual(r['snapshot']['slots'][8]['count'],1)
  s=r['snapshot'];s['body']['health']=100
  r=self.host.execute(s,operation='inventory',args=['use_slot',8]);self.assertFalse(r['ok']);self.assertEqual(r['snapshot']['slots'][8]['count'],1)
 def test_disease_hallucination_and_rotten_food_are_lethal(self):
  s=self.fresh();s['body']['health']=.1;s['body']['hallucination_remaining']=60
  r=self.host.execute(s,elapsed=1);self.assertTrue(r['ok'],r);self.assertEqual(r['snapshot']['combat_personal']['phase'],'dying')
  s=self.fresh();s['body'].update(health=1,hunger=0,illness=1,deprivation=1,damage_clock=59.9)
  r=self.host.execute(s,elapsed=1);self.assertTrue(r['ok'],r);self.assertEqual(r['snapshot']['combat_personal']['phase'],'dying')
  s=self.fresh();s['body'].update(health=3,hunger=50);s['slots'][8]={'item_id':'meatballs','count':1,'spoilage':1}
  r=self.host.execute(s,operation='inventory',args=['use_slot',8]);self.assertTrue(r['ok'],r)
  r=self.host.execute(r['snapshot'],elapsed=.01);self.assertEqual(r['snapshot']['combat_personal']['phase'],'dying');self.assertEqual(r['snapshot']['slots'][8],{})
 def test_death_interrupts_forced_sleep_without_resetting_energy(self):
  s=self.fresh();s['body'].update(health=1,energy=20,sleeping=True,sleep_forced=True,sleep_elapsed=0,sleep_duration=180)
  hit={'amount':12,'source':s['player_position'],'duel':False}
  r=self.host.execute(s,combat_damage=[hit]);self.assertTrue(r['ok'],r);self.assertFalse(r['snapshot']['body']['sleeping']);self.assertEqual(r['snapshot']['body']['sleep_session'],{});self.assertEqual(r['snapshot']['body']['energy'],20)
 def test_attack_cancels_when_weapon_instance_changes(self):
  s=self.fresh();r=self.host.execute(s,operation='combat_attack',args=[{'x':1,'y':0}]);self.assertTrue(r['ok'],r)
  s=r['snapshot'];s['equipment']={'main_hand':{'item_id':'stone_axe','count':1,'instance_id':'switched-tool','state':{},'durability':100}}
  r=self.host.execute(s,elapsed=.2);self.assertTrue(r['ok'],r);self.assertEqual(r['snapshot']['combat_personal']['attack'],{});self.assertEqual(r['combat_damage'],[])
 def test_two_deaths_keep_distinct_relics_and_cross_process(self):
  s=self.fresh();hit={'amount':12,'source':s['player_position'],'duel':False}
  for count in [7,11]:
   s['body']['health']=1;s['slots'][8]={'item_id':'wood','count':count}
   r=self.host.execute(s,player_id='first',combat_damage=[hit]);self.assertTrue(r['ok'],r);s=r['snapshot']
   s=self.host.execute(s,player_id='first',elapsed=3.1)['snapshot'];s=self.host.execute(s,player_id='first',elapsed=1.1)['snapshot']
  relics=s['combat_world']['relics'];self.assertEqual(len(relics),2);self.assertEqual(sorted(r['contents'][0]['count'] for r in relics.values()),[7,11])
  host=GameHost(self.config,{'id':'combat-network-isolated','seed':271828,'map_cells':128})
  try:
   r=host.execute(s,player_id='first');self.assertTrue(r['ok'],r);self.assertEqual(r['snapshot']['combat_world']['relics'],relics);self.assertEqual(r['snapshot']['slots'][8],{})
  finally:host.close()
 def test_raw_pork_refrigerator_transfer_preserves_spoilage(self):
  s=self.building('refrigerator');s['slots'][8]={'item_id':'boar_meat','count':2,'spoilage':.4}
  r=self.host.execute(s,operation='building_transfer',args=['fixture',0,8,{},s['slots'][8]]);self.assertTrue(r['ok'],r.get('error'))
  self.assertEqual(r['snapshot']['slots'][8],{});self.assertEqual(r['snapshot']['buildings']['objects']['fixture']['contents'][0],s['slots'][8])

 def test_real_service_receipts_db_rollback_and_restart(self):
  import base64,secrets
  with tempfile.TemporaryDirectory(prefix='combat-db-') as folder:
   config={**self.config,'data_dir':folder,'world_cells':128,'gameplay_preview':True,'hair_ids':{'male':['male_natural'],'female':['female_bob']}}
   nav=lambda w:{'generator':w['generator'],'spawn':[240,240],'step':48,'width':128,'mask':base64.b64encode(bytes([1])*128*128).decode()}
   s=server.Service(config,nav)
   def api(op,data=None,token=''):return s.handle(op,{'protocol':1,'version':'0.1.0',**(data or {})},token)
   tokens=[]
   try:
    keys=json.loads(s.initialize().read_text())
    for i in range(2):
     t=api('activate',{**keys[i],'username':'combat'+str(i),'password':'Test-combat-123'})['token'];api('nickname',{'nickname':'测试'+str(i)},t);tokens.append(t)
    world=api('create_world',{'name':'战斗隔离'},tokens[0])['world'];api('join_world',{'world_id':world['id']},tokens[1])
    for t in tokens:api('character',{'gameplay_revision':1,'appearance':{'gender':'male','hair_id':'male_natural','skin_id':'skin_2'}},t);api('game_snapshot',{},t)
    chars=[s.character(s.state['accounts'][s.sessions[t]['account']]) for t in tokens]
    for c in chars:c['gameplay']['combat_personal']['phase']='alive';c['gameplay']['body']['health']=100
    chars[1]['x']=chars[0]['x']+28;chars[1]['y']=chars[0]['y'];s.save()
    def command(t,op,args,rid=None):return api('game_command',{'request_id':rid or secrets.token_hex(16),'operation':op,'args':args},t)
    rid=secrets.token_hex(16);command(tokens[0],'combat_attack',[{'x':1,'y':0}],rid)
    s.gameplay.clocks[world['id']]=time.monotonic()-.21
    s.gameplay.tick_ready[world['id']]=0
    api('game_snapshot',{},tokens[0]);self.assertEqual(chars[1]['gameplay']['body']['health'],96)
    command(tokens[0],'combat_attack',[{'x':1,'y':0}],rid);self.assertAlmostEqual(chars[1]['gameplay']['body']['health'],96,places=2)
    c=s.character(s.state['accounts'][s.sessions[tokens[0]]['account']]);c['gameplay']['combat_personal']['attack']={};s.save()
    before=copy.deepcopy(s.state)
    with patch.object(s,'save',side_effect=OSError('injected isolated DB failure')):
     with self.assertRaises(OSError):command(tokens[0],'snapshot',[])
    self.assertEqual(s.state,before)
    s.gameplay.close();s.db.close();s=server.Service(config,nav)
    self.assertEqual(s.state,before)
   finally:
    if s.gameplay:s.gameplay.close()
    s.db.close()

if __name__=='__main__':unittest.main()
