"""Existing gear through real authoritative rules, including equipped labour."""
import copy
import json
import sys
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tests'))
import test_network_game_host as fixtures

class GearHostTests(unittest.TestCase):
    setUpClass=classmethod(fixtures.RulesHostTests.setUpClass.__func__)
    tearDownClass=classmethod(fixtures.RulesHostTests.tearDownClass.__func__)
    fixture_building=fixtures.RulesHostTests.fixture_building

    def fresh(self):
        state=copy.deepcopy(self.baseline)
        state['combat_personal']['phase']='alive'
        return state

    def item(self, name):
        return {'item_id':name,'count':1,'instance_id':'gear-'+name,'state':{},'durability':None}

    def test_four_recipes_equip_unequip_and_restore(self):
        recipes=json.loads((ROOT/'data/recipes.json').read_text(encoding='utf-8'))
        for item in ('wool_sweater','wool_hat','straw_hat','straw_raincoat'):
            with self.subTest(item=item):
                state=self.fresh()
                recipe=next(r for r in recipes if r['output_id']==item)
                for i,(material,count) in enumerate(recipe['materials'].items()):
                    state['slots'][8+i]={'item_id':material,'count':count}
                r=self.host.execute(state,operation='craft',args=[recipe['recipe_id'],1])
                self.assertTrue(r['ok'],r.get('error'))
                for _ in range(12):
                    r=self.host.execute(r['snapshot'],elapsed=1)
                    if any(s.get('item_id')==item for s in r['snapshot']['slots']):break
                state=r['snapshot']
                index=next(i for i,s in enumerate(state['slots']) if s.get('item_id')==item)
                r=self.host.execute(state,operation='inventory',args=['equip',index])
                self.assertTrue(r['ok'],r.get('error'))
                slot='head' if 'hat' in item else 'outfit'
                self.assertEqual(r['snapshot']['equipment'][slot]['item_id'],item)
                restored=self.host.execute(json.loads(json.dumps(r['snapshot'])))['snapshot']
                self.assertEqual(restored['equipment'][slot]['item_id'],item)
                # Inventory's unequip command uses the existing equipment slot index.
                slots=json.loads((ROOT/'data/equipment_slots.json').read_text(encoding='utf-8'))
                r=self.host.execute(restored,operation='inventory',args=['unequip',40+next(i for i,s in enumerate(slots) if s['id']==slot)])
                self.assertTrue(r['ok'],r.get('error'))
                self.assertFalse(r['snapshot']['equipment'].get(slot))
                self.assertEqual(sum(s.get('count',0) for s in r['snapshot']['slots'] if s.get('item_id')==item),1)

    def test_hat_raincoat_never_block_original_labor(self):
        positions=json.loads((ROOT/'reports/network-gameplay-v5/positions.json').read_text())
        definitions={d['item_id']:d for d in json.loads((ROOT/'data/items.json').read_text(encoding='utf-8'))}
        for action,tool in (('chop','stone_axe'),('mine','stone_pickaxe'),('dig','simple_shovel'),('pickup',None)):
            with self.subTest(action=action):
                state=self.fresh(); target=positions['targets'][action]
                state['player_position']=target['position']
                state['equipment']={'head':self.item('straw_hat'),'outfit':self.item('straw_raincoat')}
                if tool:state['equipment']['main_hand']={'item_id':tool,'count':1,'instance_id':'rain-'+tool,'durability':definitions[tool]['durability'],'state':{}}
                r=self.host.execute(state,operation='interact',args=[target['target']])
                self.assertTrue(r['ok'],r.get('error'))
                self.assertEqual(r['snapshot']['equipment']['head']['item_id'],'straw_hat')
                self.assertEqual(r['snapshot']['equipment']['outfit']['item_id'],'straw_raincoat')
                if tool:self.assertEqual(r['snapshot']['equipment']['main_hand']['durability'],definitions[tool]['durability']-1)

    def test_authority_rain_protection_and_personal_isolation(self):
        wet=[]
        for items in ((),('straw_hat',),('straw_raincoat',),('straw_hat','straw_raincoat'),('rain_umbrella',)):
            state=self.fresh()
            env=state['body_environment']
            env.update(day=3,minute=720,season={'version':1,'origin_day':1},current_weather=3,target_weather=3,blend=[0,1,0],transition_from=[0,1,0],transition_elapsed=25,weather_remaining=9000)
            state['equipment']={}
            for item in items:state['equipment']['main_hand' if item=='rain_umbrella' else 'head' if item=='straw_hat' else 'outfit']=self.item(item)
            state['body']['weather_body']['wetness']=0
            before=copy.deepcopy(state)
            r=self.host.execute(state,elapsed=10)
            self.assertTrue(r['ok'],r.get('error'))
            wet.append(r['snapshot']['body']['weather_body']['wetness'])
            self.assertEqual(state,before)
        self.assertTrue(all(a>b for a,b in zip(wet,wet[1:])),wet)

    def test_authority_heat_only_reduces_sleep_recovery(self):
        state=self.fixture_building('straw_mat',{'sleep_state':'PLACED'})
        state['combat_personal']['phase']='alive'
        state['body']['energy']=10
        state['body_environment'].update(day=10,minute=720,season={'version':1,'origin_day':1},current_weather=0,target_weather=0,blend=[1,0,0],transition_from=[1,0,0],transition_elapsed=25,weather_remaining=9000)
        asleep=self.host.execute(state,operation='sleep',args=['fixture','maximum'],player_id='heat')['snapshot']
        normal=copy.deepcopy(asleep)
        hot=copy.deepcopy(asleep)
        hot['body']['summer_heat'].update(hot=True,minutes=120,temperature=32)
        a=self.host.execute(normal,elapsed=5,shared=False,player_id='heat')['snapshot']
        b=self.host.execute(hot,elapsed=5,shared=False,player_id='heat')['snapshot']
        self.assertAlmostEqual(b['body']['energy']-hot['body']['energy'],(a['body']['energy']-normal['body']['energy'])*.85,places=5)
        self.assertEqual(a['body']['health'],b['body']['health'])
        self.assertEqual(a['body_environment'],b['body_environment'])

    def test_authority_wool_and_running_temperature(self):
        naked=self.fresh();wool=self.fresh()
        naked['body_environment'].update(day=24,minute=720,season={'version':1,'origin_day':1},current_weather=0,target_weather=0,blend=[1,0,0],transition_from=[1,0,0],transition_elapsed=25,weather_remaining=9000)
        wool=copy.deepcopy(naked);wool['equipment']={'head':self.item('wool_hat'),'outfit':self.item('wool_sweater')}
        a=self.host.execute(naked,elapsed=10)['snapshot'];b=self.host.execute(wool,elapsed=10)['snapshot']
        self.assertGreater(b['body']['weather_body']['felt_temperature'],a['body']['weather_body']['felt_temperature'])
        # Movement status is a server-authenticated character projection.
        summer=self.fresh();summer['body_environment'].update(day=10,minute=720,season={'version':1,'origin_day':1})
        motion={**summer['player_position'],**{key:summer[key] for key in ('slots','equipment','hotbar_equipment')},'appearance':{}}
        idle=self.host.execute(summer,elapsed=10,character={**motion,'moving':False,'running':False})['snapshot']
        active=self.host.execute(summer,elapsed=10,character={**motion,'moving':True,'running':True})['snapshot']
        self.assertGreater(active['body']['summer_heat']['activity'],idle['body']['summer_heat']['activity'])

if __name__=='__main__':unittest.main()
