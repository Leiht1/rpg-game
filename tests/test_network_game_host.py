"""Original rules host contract; isolated fixtures, no production data."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/"tools"/"network"))
from game_host import GameHost
from gameplay import Gameplay, PERSONAL, validate


class RulesHostTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="windrest-gameplay-")
        cls.host = GameHost({"data_dir": cls.temporary.name, "project": str(ROOT),
                            "godot": os.environ.get("WINDREST_GODOT", "D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")},
                           {"id": "isolated-gameplay-v5", "seed": 271828, "map_cells": 128})
        cls.baseline = cls.host.execute()["snapshot"]

    @classmethod
    def tearDownClass(cls):
        cls.host.close()
        cls.temporary.cleanup()

    def test_roundtrip_original_snapshot(self):
        result = self.host.execute(copy.deepcopy(self.baseline))
        self.assertTrue(result["ok"], result.get("error"))
        for key in ("world_id", "seed", "slots", "body", "buildings", "campfires"):
            self.assertEqual(self.baseline[key], result["snapshot"][key])

    @unittest.skipUnless(os.name == "nt", "Windows mailbox sharing regression")
    def test_busy_request_is_retried_without_losing_command(self):
        import ctypes
        import threading
        from ctypes import wintypes
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                      ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
        kernel.CreateFileW.restype = wintypes.HANDLE
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        replace = os.replace
        held = []
        timers = []
        def publish_locked(source, target):
            # Allow atomic rename but deny Godot's read until the timer releases it.
            handle = kernel.CreateFileW(str(source), 0x80000000, 4, None, 3, 0, None)
            self.assertNotEqual(handle, ctypes.c_void_p(-1).value)
            held.append(handle)
            try:
                replace(source, target)
            finally:
                timer = threading.Timer(.3, lambda: kernel.CloseHandle(handle))
                timers.append(timer);timer.start()
        try:
            with patch('game_host.os.replace', publish_locked):
                reply = self.host.execute(copy.deepcopy(self.baseline))
            self.assertTrue(reply['ok'], reply.get('error'))
            self.assertEqual(reply['snapshot']['slots'], self.baseline['slots'])
            self.assertTrue(held)
            self.assertTrue(self.host.execute(copy.deepcopy(self.baseline))['ok'])
        finally:
            for timer in timers:timer.join()

    def test_malformed_mailbox_does_not_stall_next_request(self):
        temporary = self.host.folder / 'request.tmp'
        temporary.write_text('{incomplete', encoding='utf-8')
        os.replace(temporary, self.host.folder / 'request.json')
        rejected = self.host._receive(5)
        self.assertFalse(rejected['ok'])
        self.assertTrue(rejected['error'])
        restored = self.host.execute(copy.deepcopy(self.baseline))
        self.assertTrue(restored['ok'], restored.get('error'))
        self.assertEqual(restored['snapshot']['slots'], self.baseline['slots'])

    def test_windows_busy_result_file_does_not_mix_replies(self):
        original=Path.read_text
        attempts=[]
        def busy_once(path,*args,**kwargs):
            if path.name=="result.json" and not attempts:
                attempts.append(True)
                raise PermissionError("isolated Windows file hold")
            return original(path,*args,**kwargs)
        with patch.object(Path,"read_text",busy_once):
            result=self.host.execute(self.baseline)
        self.assertTrue(attempts)
        self.assertTrue(result["ok"])
        state=self.baseline
        character={"x":state["player_position"]["x"],"y":state["player_position"]["y"],"gameplay":{"body":state["body"]}}
        moved=self.host.movement({"gameplay":state},character,[])
        self.assertEqual(set(moved),{"x","y"})
        self.assertTrue(self.host.execute(self.baseline)["ok"])

    def test_invalid_snapshot_is_rejected(self):
        state = copy.deepcopy(self.baseline)
        state["seed"] += 1
        result = self.host.execute(state)
        self.assertFalse(result["ok"])
        self.assertNotIn("snapshot", result)
        self.assertTrue(self.host.execute(self.baseline)["ok"])

    def test_failed_material_check_does_not_grant_items(self):
        result = self.host.execute(self.baseline, operation="craft", args=["stone_axe", 1])
        self.assertFalse(result["ok"])
        self.assertEqual(self.baseline["slots"], result["snapshot"]["slots"])

    def test_unknown_command_cannot_call_inventory_add(self):
        result = self.host.execute(self.baseline, operation="inventory", args=["add", "wood", 99])
        self.assertFalse(result["ok"])
        self.assertEqual(self.baseline["slots"], result["snapshot"]["slots"])

    def test_craft_progress_and_completion_survive_request_restore(self):
        state = copy.deepcopy(self.baseline)
        for index, item in enumerate(("branch", "flint", "plant_fiber")):
            state["slots"][index+8] = {"item_id": item, "count": 20}
        result = self.host.execute(state, operation="craft", args=["hand_stone_axe", 1])
        self.assertTrue(result["ok"], result.get("error"))
        state = result["snapshot"]
        self.assertTrue(state["network_craft_job"])
        result = self.host.execute(state, elapsed=2)
        self.assertTrue(result["ok"], result.get("error"))
        self.assertFalse(result["snapshot"]["network_craft_job"])
        self.assertEqual(sum(row.get("count", 0) for row in result["snapshot"]["slots"] if row.get("item_id") == "stone_axe"), 1)
        restored = self.host.execute(result["snapshot"], elapsed=2)
        self.assertEqual(sum(row.get("count", 0) for row in restored["snapshot"]["slots"] if row.get("item_id") == "stone_axe"), 1)

    def test_personal_tick_does_not_advance_shared_world_twice(self):
        state = copy.deepcopy(self.baseline)
        first = self.host.execute(state, elapsed=1, shared=True)["snapshot"]
        second = self.host.execute(first, elapsed=1, shared=False)["snapshot"]
        self.assertEqual(first["body_environment"], second["body_environment"])
        self.assertLess(second["body"]["energy"], first["body"]["energy"])
        self.assertEqual(first["animals"]["clock"], second["animals"]["clock"])

    def test_fishing_requires_rod_and_cannot_award_by_judging_idle(self):
        state = copy.deepcopy(self.baseline)
        state["equipment"] = {}
        start = self.host.execute(state, operation="fish_start")
        self.assertFalse(start["ok"])
        for unused in range(3):
            result = self.host.execute(state, operation="fish_judge", elapsed=.5)
            self.assertTrue(result["ok"])
            self.assertEqual(result["snapshot"]["slots"], state["slots"])
            self.assertEqual(result["snapshot"]["network_fishing"]["state"], "idle")

    def test_fishing_character_cannot_move(self):
        state = copy.deepcopy(self.baseline)
        character = {"x": state["player_position"]["x"], "y": state["player_position"]["y"], "gameplay": {"body": state["body"], "network_fishing": {"state": "game"}}}
        result = self.host.movement({"gameplay": state}, character, [{"dx": 1, "dy": 0, "dt": .05, "run": True}])
        self.assertEqual(result, {"x": character["x"], "y": character["y"]})

    def test_database_restore_discards_uncommitted_mutation(self):
        state = copy.deepcopy(self.baseline)
        state["slots"][8] = {"item_id": "wood", "count": 7}
        result = self.host.execute(state, operation="inventory", args=["move_slot", 8, 9])
        self.assertTrue(result["ok"], result.get("error"))
        self.assertEqual(result["snapshot"]["slots"][9]["count"], 7)
        restored = self.host.execute(state)
        self.assertEqual(restored["snapshot"]["slots"][8]["count"], 7)
        self.assertFalse(restored["snapshot"]["slots"][9])

    def fixture_building(self, kind, extra=None):
        state = copy.deepcopy(self.baseline)
        definition = json.loads((ROOT/"data/camp_buildings.json").read_text(encoding="utf-8"))[kind]
        x, y = state["player_position"]["x"]+60, state["player_position"]["y"]
        gx, gy = int(x//96), int(y//64)
        if definition["layer"] != "free":x,y = gx*96+48,gy*64+32
        row = {"kind": kind, "layer": definition["layer"], "x": x, "y": y, "gx": gx, "gy": gy,
               "vertical": False, "open": False, "inward": False, "facing": 0, "hits": 0,
               "contents": [{} for unused in range(definition.get("storage_slots", 12))]}
        if definition["layer"] == "ground":state["player_position"]={"x":x,"y":y}
        if extra:row.update(extra)
        state["buildings"]["objects"] = {"fixture": row}
        return state

    def test_shared_chest_transfer_rejects_stale_take(self):
        state = self.fixture_building("wood_chest")
        state["buildings"]["objects"]["fixture"]["contents"][0] = {"item_id": "wood", "count": 7}
        result = self.host.execute(state, operation="building_transfer", args=["fixture",0,8,{"item_id":"wood","count":7},{}])
        self.assertTrue(result["ok"], result.get("error"))
        self.assertEqual(result["snapshot"]["slots"][8].get("count"), 7)
        repeated = self.host.execute(result["snapshot"], operation="building_transfer", args=["fixture",0,9,{"item_id":"wood","count":7},{}])
        self.assertFalse(repeated["ok"])

    def test_campfire_cooking_and_claim_restore(self):
        state = copy.deepcopy(self.baseline)
        at = state["player_position"]
        state["campfires"]["objects"] = {"fixture": {"x":at["x"]+60,"y":at["y"],"fuel":100.0,"lit":True,"recipe":"","elapsed":0.0,"ready":False}}
        state["slots"][8] = {"item_id":"wild_carrot","count":2}
        result = self.host.execute(state, operation="camp_act", args=["fixture","experiment","",{"wild_carrot":1}])
        self.assertTrue(result["ok"], result.get("error"))
        for unused in range(3):result = self.host.execute(result["snapshot"], elapsed=5)
        self.assertTrue(result["snapshot"]["campfires"]["objects"]["fixture"]["ready"])
        result = self.host.execute(result["snapshot"], operation="camp_act", args=["fixture","claim","",{}])
        self.assertTrue(result["ok"], result.get("error"))
        self.assertEqual(sum(row.get("count",0) for row in result["snapshot"]["slots"] if row.get("item_id")=="roasted_carrot"),1)

    def test_industry_fuel_queue_and_claim_restore(self):
        machine = {"version":2,"fuel":0.0,"jobs":[{}],"queue":[],"completed":[],"feed":{},"enabled":False,"legacy_queue":[],"legacy_fuel":0.0}
        state = self.fixture_building("stone_furnace", {"machine":machine})
        state["slots"][8] = {"item_id":"wood","count":2}
        state["slots"][9] = {"item_id":"copper_ore","count":2}
        for action,key,count in (("fuel","wood",1),("ignite","",1),("start","smelt_copper",1)):
            result = self.host.execute(state, operation="industry", args=["fixture",action,0,key,count,{}])
            self.assertTrue(result["ok"], result.get("error"));state=result["snapshot"]
        for unused in range(5):state = self.host.execute(state, elapsed=5)["snapshot"]
        result = self.host.execute(state, operation="industry", args=["fixture","claim_all",0,"",1,{}])
        self.assertTrue(result["ok"], result.get("error"))
        self.assertEqual(sum(row.get("count",0) for row in result["snapshot"]["slots"] if row.get("item_id")=="copper_ingot"),1)

    def test_wire_inventory_expected_and_stale_source(self):
        state = copy.deepcopy(self.baseline)
        state["slots"][8] = {"item_id":"wood","count":7}
        result = self.host.execute(state, operation="inventory", args=["move_slot",8,9], expected={"8":{"item_id":"wood","count":7}})
        self.assertTrue(result["ok"], result.get("error"))
        rejected = self.host.execute(result["snapshot"], operation="inventory", args=["destroy_slot",9], expected={"9":{"item_id":"wood","count":6}})
        self.assertFalse(rejected["ok"])
        self.assertEqual(rejected["snapshot"]["slots"][9]["count"],7)

    def test_sleep_occupancy_second_character_and_wake(self):
        state = self.fixture_building("straw_mat", {"sleep_state":"PLACED"})
        state["body"]["energy"] = 40.0
        result = self.host.execute(state, operation="sleep", args=["fixture","maximum"], player_id="first")
        self.assertTrue(result["ok"], result.get("error"))
        asleep = result["snapshot"]
        self.assertTrue(asleep["body"]["sleeping"])
        second = copy.deepcopy(asleep);second["body"] = copy.deepcopy(self.baseline["body"]);second["body"]["energy"]=40.0
        rejected = self.host.execute(second, operation="sleep", args=["fixture","maximum"], player_id="second")
        self.assertFalse(rejected["ok"])
        self.assertIn("snapshot",rejected)
        wake = self.host.execute(asleep, operation="wake", player_id="first")
        self.assertTrue(wake["ok"],wake.get("error"))
        self.assertFalse(wake["snapshot"]["body"]["sleeping"])
        self.assertEqual(wake["snapshot"]["buildings"]["objects"]["fixture"]["sleep_state"],"PLACED")

    def test_crop_seed_fertilizer_and_harvest(self):
        state = self.fixture_building("tilled_soil", {"crop":"","growth_minutes":0.0,"roots":False})
        state["slots"][8] = {"item_id":"carrot_seed","count":2}
        state["slots"][9] = {"item_id":"compost_fertilizer","count":1}
        result = self.host.execute(state, operation="plant", args=["fixture","carrot_seed"])
        self.assertTrue(result["ok"],result.get("error"));state=result["snapshot"]
        self.assertEqual(state["slots"][8]["count"],1)
        result = self.host.execute(state, operation="fertilize", args=["fixture"])
        self.assertTrue(result["ok"],result.get("error"));state=result["snapshot"]
        self.assertTrue(state["buildings"]["objects"]["fixture"]["fertilized"])
        state["buildings"]["objects"]["fixture"]["growth_minutes"] = 2880.0
        result = self.host.execute(state, operation="plant", args=["fixture",""])
        self.assertTrue(result["ok"],result.get("error"))
        self.assertEqual(sum(v.get("count",0) for v in result["snapshot"]["slots"] if v.get("item_id")=="wild_carrot"),4)
        self.assertTrue(result["snapshot"]["buildings"]["objects"]["fixture"]["roots"])

    def test_expansion_fuel_deposit(self):
        state = self.fixture_building("fuel_supply_box", {"expansion":{"version":1,"fuel_items":{},"job":{}}})
        state["slots"][8] = {"item_id":"wood","count":7}
        result = self.host.execute(state, operation="expansion", args=["fixture","deposit",-1,{},"wood",3])
        self.assertTrue(result["ok"],result.get("error"))
        self.assertEqual(result["snapshot"]["slots"][8]["count"],4)
        self.assertEqual(result["snapshot"]["buildings"]["objects"]["fixture"]["expansion"]["fuel_items"]["wood"],3)

    def test_merchant_trade_and_sold_stock(self):
        state = copy.deepcopy(self.baseline)
        merchant = state["merchant"]
        self.assertTrue(merchant)
        state["player_position"] = {"x":merchant["x"],"y":merchant["y"]+55}
        rules = json.loads((ROOT/"data/merchant_v1.json").read_text(encoding="utf-8"))
        item = next(iter(merchant["offers"]))
        price = rules["products"][item][merchant["offers"][item]["template"]]
        for index,(key,count) in enumerate(price.items()):state["slots"][index+8] = {"item_id":key,"count":count}
        result = self.host.execute(state, operation="buy", args=[item])
        self.assertTrue(result["ok"],result.get("error"))
        self.assertEqual(result["snapshot"]["merchant"]["offers"][item]["stock"],0)
        again = self.host.execute(result["snapshot"], operation="buy", args=[item])
        self.assertFalse(again["ok"])

    def test_animal_feed_shared_trust_and_cooldown(self):
        state = copy.deepcopy(self.baseline)
        state = self.host.execute(state,elapsed=.1)["snapshot"]
        aid,animal = next(iter(state["animals"]["objects"].items()))
        state["player_position"]={"x":animal["x"],"y":animal["y"]+35}
        rules = json.loads((ROOT/"data/animals.json").read_text(encoding="utf-8"))
        food = rules[animal["species"]]["foods"][0]
        state["slots"][8] = {"item_id":food,"count":3}
        result = self.host.execute(state, operation="animal_feed", args=[aid,8,state["slots"][8]])
        self.assertTrue(result["ok"],result.get("error"))
        self.assertEqual(result["snapshot"]["animals"]["objects"][aid]["trust"],animal["trust"]+1)
        again = self.host.execute(result["snapshot"], operation="animal_feed", args=[aid,8,result["snapshot"]["slots"][8]])
        self.assertFalse(again["ok"])

    def test_original_gathering_and_pickup_targets(self):
        positions = json.loads((ROOT/"reports/network-gameplay-v5/positions.json").read_text(encoding="utf-8"))
        for action,tool in (("chop","stone_axe"),("mine","stone_pickaxe"),("dig","simple_shovel"),("pickup",None)):
            with self.subTest(action=action):
                state = copy.deepcopy(self.baseline)
                target = positions["targets"][action]
                state["player_position"] = target["position"]
                if tool:
                    definition = next(item for item in json.loads((ROOT/"data/items.json").read_text(encoding="utf-8")) if item["item_id"]==tool)
                    state["equipment"] = {"main_hand":{"item_id":tool,"count":1,"instance_id":"test-tool-"+action,"state":{},"durability":definition["durability"]}}
                result = self.host.execute(state, operation="interact", args=[target["target"]])
                self.assertTrue(result["ok"],result.get("error"))
                if tool:self.assertLess(result["snapshot"]["equipment"]["main_hand"]["durability"],definition["durability"])
                else:self.assertNotEqual(result["snapshot"]["slots"],state["slots"])

    def test_fishing_success_restores_without_duplicate_rewards(self):
        positions = json.loads((ROOT/"reports/network-gameplay-v5/positions.json").read_text(encoding="utf-8"))
        for spot in positions["spots"]:
            state = copy.deepcopy(self.baseline);state["player_position"] = spot["stand"]
            state["equipment"] = {"main_hand":{"item_id":"fishing_rod","count":1,"instance_id":"test-rod","state":{},"durability":150}}
            result = self.host.execute(state, operation="fish_start")
            if result["ok"]:break
        self.assertTrue(result["ok"],result.get("error"))
        state = result["snapshot"]
        for unused in range(12):
            state = self.host.execute(state,elapsed=.7)["snapshot"]
            if state["network_fishing"]["state"]=="game":break
        self.assertEqual(state["network_fishing"]["state"],"game")
        for unused in range(2):
            fishing = state["network_fishing"]
            delay = fishing["safe_center"]/.72 - fishing["marker_phase"]/.72
            result = self.host.execute(state,operation="fish_judge",elapsed=max(.29,delay))
            self.assertTrue(result["ok"],result.get("error"));state=result["snapshot"]
        self.assertEqual(state["network_fishing"]["state"],"success")
        state = self.host.execute(state,elapsed=1.3)["snapshot"]
        count = sum(v.get("count",0) for v in state["slots"])
        self.assertEqual(count,1)
        again = self.host.execute(state,elapsed=.1)["snapshot"]
        self.assertEqual(sum(v.get("count",0) for v in again["slots"]),count)

    def test_personal_inventories_and_bodies_are_separate(self):
        gameplay = Gameplay({})
        wid = self.baseline["world_id"]
        gameplay.hosts[wid] = self.host
        gameplay.defaults[wid] = copy.deepcopy(self.baseline)
        world = {"id": wid, "gameplay": {key: copy.deepcopy(value) for key, value in self.baseline.items() if key not in PERSONAL}}
        def character(count):
            return {"x": self.baseline["player_position"]["x"], "y": self.baseline["player_position"]["y"],
                    "slots": [{"item_id": "wood", "count": count}]+[{} for _ in range(39)],
                    "equipment": {}, "hotbar_equipment": {}}
        first, second = character(3), character(7)
        self.assertTrue(gameplay.apply(world, first)["ok"])
        self.assertTrue(gameplay.apply(world, second)["ok"])
        self.assertEqual(first["slots"][0]["count"], 3)
        self.assertEqual(second["slots"][0]["count"], 7)
        first["gameplay"]["body"]["hunger"] = 12.0
        self.assertTrue(gameplay.apply(world, first)["ok"])
        self.assertTrue(gameplay.apply(world, second)["ok"])
        self.assertEqual(first["gameplay"]["body"]["hunger"], 12.0)
        self.assertNotEqual(second["gameplay"]["body"]["hunger"], 12.0)

    def test_command_types_and_coordinates_are_checked_before_host(self):
        for operation, args in (("inventory", ["add", "wood", 99]),
                                ("inventory", ["move_slot", True, 1]),
                                ("craft", ["stone_axe", "99"]),
                                ("building_place", [{"kind": "wood_chest", "x": float("nan"), "y": 0}, []]),
                                ("sleep", ["bed", "maximum", True]),
                                ("interact", [{"arbitrary_node": "anything"}])):
            with self.subTest(operation=operation, args=args):
                with self.assertRaises(ValueError):
                    validate(operation, args)

    def test_legacy_containers_migrate_once_and_restore_in_new_host(self):
        gameplay = Gameplay({})
        wid = self.baseline["world_id"]
        gameplay.hosts[wid] = self.host
        gameplay.defaults[wid] = copy.deepcopy(self.baseline)
        position = self.baseline["player_position"]
        world = {"id": wid, "seed":271828,"map_cells":128,
                 "storage":{"old-box":{"x":position["x"],"y":position["y"],"contents":[{"item_id":"wood","count":7}]}},
                 "drops":{},"legacies":{}}
        character = {"id":"migration-player","x":position["x"],"y":position["y"],
                     "slots":[{} for _ in range(40)],"equipment":{},"hotbar_equipment":{}}
        self.assertTrue(gameplay.apply(world,character)["ok"])
        key="online-v1:storage:old-box:0"
        self.assertEqual(world["gameplay"]["loose"][key]["count"],7)
        self.assertFalse(world["storage"])
        world=json.loads(json.dumps(world));character=json.loads(json.dumps(character))
        config={"data_dir":self.temporary.name,"project":str(ROOT),
                "godot":os.environ.get("WINDREST_GODOT","D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")}
        restored=Gameplay(config)
        try:
            self.assertTrue(restored.apply(world,character)["ok"])
            self.assertEqual(world["gameplay"]["loose"][key]["count"],7)
            self.assertEqual(len([k for k in world["gameplay"]["loose"] if k.startswith("online-v1:")]),1)
            self.assertFalse(any(character["slots"]))
        finally:
            for host in restored.hosts.values():host.close()

    def test_building_place_consumes_materials_and_rejects_repeat(self):
        state=copy.deepcopy(self.baseline)
        state["slots"][8]={"item_id":"wood","count":30}
        at=state["player_position"]
        for dx,dy in ((0,0),(96,0),(-96,0),(0,64),(0,-64),(96,64),(-96,-64)):
            row={"kind":"wood_floor","x":at["x"]+dx,"y":at["y"]+dy}
            result=self.host.execute(state,operation="building_place",args=[row,state["slots"]])
            if result["ok"]:break
        self.assertTrue(result["ok"],result.get("error"))
        self.assertEqual(len(result["snapshot"]["buildings"]["objects"]),len(state["buildings"]["objects"])+1)
        self.assertLess(result["snapshot"]["slots"][8]["count"],30)
        placed=result["snapshot"]
        repeated=self.host.execute(placed,operation="building_place",args=[row,placed["slots"]])
        self.assertFalse(repeated["ok"])
        self.assertEqual(repeated["snapshot"]["slots"],placed["slots"])

    def test_food_use_and_bag_organize_restore(self):
        state=copy.deepcopy(self.baseline)
        state["body"]["hunger"]=30.0
        state["slots"][8]={"item_id":"wild_berry","count":2}
        result=self.host.execute(state,operation="inventory",args=["use_slot",8])
        self.assertTrue(result["ok"],result.get("error"))
        self.assertGreater(result["snapshot"]["body"]["hunger"],30)
        self.assertEqual(result["snapshot"]["slots"][8]["count"],1)
        state=result["snapshot"];state["slots"][11]={"item_id":"wood","count":3};state["slots"][15]={"item_id":"wood","count":4}
        result=self.host.execute(state,operation="organize")
        self.assertTrue(result["ok"],result.get("error"))
        wood=[v for v in result["snapshot"]["slots"] if v.get("item_id")=="wood"]
        self.assertEqual(wood,[{"item_id":"wood","count":7}])

    def test_service_transaction_retry_and_feature_gate(self):
        spec = importlib.util.spec_from_file_location("windrest_gameplay_test_server", ROOT/"tools/network/server.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory(prefix="windrest-gameplay-db-") as folder:
            service = module.Service({"data_dir": folder})
            try:
                wid = self.baseline["world_id"]
                character = {"id": "isolated-character", "world_id": wid,
                             "x": self.baseline["player_position"]["x"], "y": self.baseline["player_position"]["y"],
                             "slots": [{} for _ in range(40)], "equipment": {}, "hotbar_equipment": {}}
                character["slots"][8] = {"item_id": "wood", "count": 3}
                service.state["worlds"][wid] = {"id": wid}
                service.state["characters"]["player"] = character
                service.state["accounts"]["account"] = {"id": "account", "player_id": "player", "world_id": wid,
                                                        "enabled": True, "nickname": "Isolated", "role": "player"}
                service.sessions["token"] = {"account": "account", "expires": time.monotonic()+100,
                                             "seen": time.monotonic(), "entered": True}
                def api(endpoint, **data):
                    return service.handle(endpoint, {"protocol": 1, "version": "0.1.0", **data}, "token")
                with self.assertRaises(module.Rejected):
                    api("game_snapshot")
                service.config["gameplay_preview"] = True
                service.gameplay = Gameplay({})
                service.gameplay.hosts[wid] = self.host
                service.gameplay.defaults[wid] = copy.deepcopy(self.baseline)
                self.assertTrue(api("game_snapshot")["ok"])
                previous = copy.deepcopy(service.state)
                save = service.save
                def fail():
                    raise OSError("isolated disk failure")
                service.save = fail
                command = {"request_id": "a"*32, "operation": "inventory", "args": ["move_slot", 8, 9]}
                with self.assertRaises(OSError):
                    api("game_command", **command)
                self.assertEqual(service.state, previous)
                service.save = save
                result = api("game_command", **command)
                self.assertEqual(result["snapshot"]["slots"][9]["count"], 3)
                duplicate = api("game_command", **command)
                self.assertEqual(duplicate["snapshot"]["slots"], result["snapshot"]["slots"])
                stored = json.loads(service.db.execute("SELECT payload FROM state WHERE id=1").fetchone()[0])
                self.assertEqual(stored["characters"]["player"]["slots"][9]["count"], 3)
                self.assertEqual(len(stored["receipts"]), 1)
                self.assertNotIn("snapshot", next(iter(stored["receipts"].values())))
            finally:
                service.db.close()


if __name__ == "__main__":
    unittest.main()
