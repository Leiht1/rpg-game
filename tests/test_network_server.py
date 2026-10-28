"""Isolated authority/transaction tests; never read the player's local Godot data."""
import base64
import copy
import concurrent.futures
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC=importlib.util.spec_from_file_location("windrest_server",Path(__file__).parents[1]/"tools/network/server.py")
server=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(server)


class ServerTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.config={"data_dir":self.temp.name,"world_cells":128,"max_players":16,
                     "godot":os.environ.get("WINDREST_GODOT", "D:/Godot/Godot_v4.7.2-stable_win64.exe"),"project":str(Path(__file__).parents[1]),
                     "hair_ids":{"male":["male_natural"],"female":["female_bob"]}}
        self.nav=lambda w:{"generator":w["generator"],"spawn":[240,240],"step":48,"width":128,"mask":base64.b64encode(bytes([1])*128*128).decode()}
        self.s=server.Service(self.config,self.nav)
        self.keys=json.loads(self.s.initialize().read_text())
        self.t1=self.activate(0,"playerone","原野一号")
        self.t2=self.activate(1,"playertwo","原野二号")
        self.admin=self.activate(8,"serveradmin","管理测试")
    def tearDown(self):
        self.s.db.close();self.temp.cleanup()
    def api(self,op,data=None,token=""):
        return self.s.handle(op,{"protocol":1,"version":"0.1.0",**(data or {})},token)
    def activate(self,i,username,nickname):
        row=self.keys[i]
        token=self.api("activate",{**row,"username":username,"password":"Test-password-123"})["token"]
        self.api("nickname",{"nickname":nickname},token)
        return token
    def world(self,token=None):
        return self.api("create_world",{"name":"测试原野"},token or self.t1)["world"]
    def enter(self,token):
        return self.api("character",{"appearance":{"gender":"male","hair_id":"male_natural","skin_id":"skin_2"}},token)
    def both(self):
        w=self.world();self.api("join_world",{"world_id":w["id"]},self.t2)
        self.enter(self.t1);self.enter(self.t2)
        return w
    def test_activation_and_password(self):
        with self.assertRaises(server.Rejected):self.api("activate",{**self.keys[0],"username":"again","password":"Test-password-123"})
        with self.assertRaises(server.Rejected):self.api("login",{"username":"playerone","password":"Wrong-password"})
        self.api("password",{"current":"Test-password-123","password":"New-password-123"},self.t1)
        with self.assertRaises(server.Rejected):self.api("login",{"username":"playerone","password":"Test-password-123"})
        self.assertTrue(self.api("login",{"username":"playerone","password":"New-password-123"})["ok"])
        self.assertNotIn("New-password-123",json.dumps(self.s.state))
    def test_cross_gender_hair_selection(self):
        w=self.world();self.api("join_world",{"world_id":w["id"]},self.t2)
        for token,gender,hair in [(self.t1,"male","female_bob"),(self.t2,"female","male_natural")]:
            self.api("character",{"appearance":{"gender":gender,"hair_id":hair,"skin_id":"skin_2"}},token)
        appearances=[row["appearance"] for row in self.s.state["characters"].values()]
        self.assertIn({"gender":"male","hair_id":"female_bob","skin_id":"skin_2"},appearances)
        self.assertIn({"gender":"female","hair_id":"male_natural","skin_id":"skin_2"},appearances)
    def test_release_catalog_and_new_unisex_character_creation(self):
        root=Path(__file__).parents[1]
        config=json.loads((root/"config/network-server.json").read_text(encoding="utf-8"))
        catalog=json.loads((root/"prototypes/character-creation-v1/catalog.json").read_text(encoding="utf-8"))
        allowed={hair for group in config["hair_ids"].values() for hair in group}
        self.assertEqual(allowed,set(catalog["hair"]))
        self.s.config["hair_ids"]=config["hair_ids"]
        w=self.world();self.api("join_world",{"world_id":w["id"]},self.t2)
        for token,gender,hair in [(self.t1,"male","unisex_mohawk"),(self.t2,"female","unisex_bun")]:
            self.api("character",{"appearance":{"gender":gender,"hair_id":hair,"skin_id":"skin_2"}},token)
        self.assertEqual({c["appearance"]["hair_id"] for c in self.s.state["characters"].values()},
                         {"unisex_mohawk","unisex_bun"})
    def test_reenter_resets_movement_sequence(self):
        self.world();self.enter(self.t1)
        self.api("move",{"seq":20,"dx":0,"dy":0},self.t1)
        self.api("leave_lobby",{},self.t1)
        self.enter(self.t1)
        self.assertTrue(self.api("move",{"seq":1,"dx":0,"dy":0},self.t1)["ok"])
    def test_permissions_and_disabled(self):
        with self.assertRaises(server.Rejected):self.api("admin_list",{},self.t1)
        self.api("admin_enabled",{"account":"TEST-001","enabled":False},self.admin)
        with self.assertRaises(server.Rejected):self.api("profile",{},self.t1)
        with self.assertRaises(server.Rejected):self.api("login",{"username":"playerone","password":"Test-password-123"})
    def test_admin_password_reset_preserves_bound_username_and_identity(self):
        before=self.s.state["accounts"]["TEST-001"]["player_id"]
        result=self.api("admin_reset",{"account":"TEST-001"},self.admin)
        with self.assertRaises(server.Rejected):self.api("profile",{},self.t1)
        with self.assertRaises(server.Rejected):self.api("activate",{**result,"username":"differentname","password":"Replacement-password"})
        token=self.api("activate",{**result,"username":"playerone","password":"Replacement-password"})["token"]
        profile=self.api("profile",{},token)["profile"]
        self.assertEqual(profile["player_id"],before)
        self.assertEqual(profile["nickname_uses"],1)
    def test_nickname_counter_and_admin(self):
        self.api("nickname",{"nickname":"新昵称"},self.t1)
        with self.assertRaises(server.Rejected):self.api("nickname",{"nickname":"第三次"},self.t1)
        with self.assertRaises(server.Rejected):self.api("nickname",{"nickname":"管理员"},self.t2)
        with self.assertRaises(server.Rejected):self.api("nickname",{"nickname":"新昵称"},self.t2)
        self.api("nickname_request",{"nickname":"审核通过"},self.t1)
        self.api("admin_nickname",{"account":"TEST-001"},self.admin)
        self.assertEqual(self.api("profile",{},self.t1)["profile"]["nickname"],"审核通过")
        self.assertEqual(self.s.state["accounts"]["TEST-001"]["nickname_uses"],2)
    def test_avatar_real_format_and_rollback(self):
        from PIL import Image
        out=io.BytesIO();Image.new("RGB",(128,128),"green").save(out,format="PNG")
        result=self.api("avatar",{"image":base64.b64encode(out.getvalue()).decode()},self.t1)
        old=result["profile"]["avatar"]
        with self.assertRaises(server.Rejected):self.api("avatar",{"image":base64.b64encode(b"fake.png").decode()},self.t1)
        self.assertEqual(self.api("profile",{},self.t1)["profile"]["avatar"],old)
        self.assertTrue(self.api("avatar_get",{"avatar":old},self.t2)["image"])
    def test_world_identity_and_reconnect(self):
        w=self.both();c=self.s.state["characters"][self.s.state["accounts"]["TEST-001"]["player_id"]]
        self.s.sessions[self.t1]["move_at"]-=.1
        self.api("move",{"dx":1,"dy":0,"seq":1,"run":True},self.t1)
        # Responses are detached from mutable service rows.
        c=self.s.state["characters"][self.s.state["accounts"]["TEST-001"]["player_id"]]
        self.assertGreater(c["x"],240)
        with self.assertRaises(server.Rejected):self.api("move",{"dx":1,"dy":0,"seq":1},self.t1)
        with self.assertRaises(server.Rejected):self.api("move",{"dx":100,"dy":0,"seq":2},self.t1)
        with self.assertRaises(server.Rejected):self.world(self.t1)
        self.api("leave_lobby",{},self.t1)
        result=self.enter(self.t1)
        self.assertEqual(result["world"]["id"],w["id"])
        self.assertEqual(result["character"]["id"],c["id"])
    def test_delayed_input_batch_and_limits(self):
        self.world();self.enter(self.t1)
        session=self.s.sessions[self.t1]
        session["move_at"]-=.6
        batch=[{"id":i+1,"dx":1,"dy":0,"run":False,"dt":1/60} for i in range(36)]
        result=self.api("move",{"seq":1,"inputs":batch},self.t1)
        self.assertAlmostEqual(result["character"]["x"],360,places=4)
        self.assertEqual(result["input_ack"],36)
        before=result["character"]["x"]
        retry=self.api("move",{"seq":2,"inputs":batch},self.t1)
        self.assertEqual(retry["character"]["x"],before)
        excessive=[{**row,"id":row["id"]+36} for row in batch]
        session["move_credit"]=0
        session["move_at"]=server.time.monotonic()
        deferred=self.api("move",{"seq":3,"inputs":excessive},self.t1)
        self.assertEqual(deferred["input_ack"],36)
        self.assertEqual(self.s.sessions[self.t1]["input_ack"],36)
        self.assertEqual(self.s.character(self.s.state["accounts"]["TEST-001"])["x"],before)
        session=self.s.sessions[self.t1];session["move_at"]-=.6
        self.s.movement_checkpoint=0
        self.s.save=lambda:(_ for _ in ()).throw(OSError("isolated save failure"))
        with self.assertRaises(OSError):self.api("move",{"seq":4,"inputs":excessive},self.t1)
        self.assertEqual(self.s.sessions[self.t1]["input_ack"],36)

    def test_movement_batch_terrain_and_invalid_numbers(self):
        self.world();self.enter(self.t1)
        session=self.s.sessions[self.t1];session["move_at"]-=.7
        world=self.s.state["worlds"][self.s.state["accounts"]["TEST-001"]["world_id"]]
        mask=bytearray([1])*128*128
        for y in range(128):mask[y*128+6]=0
        self.s.mask_cache[world["id"]]=bytes(mask)
        batch=[{"id":i+1,"dx":1,"dy":0,"run":True,"dt":.05} for i in range(12)]
        response=self.api("move",{"seq":1,"inputs":batch},self.t1)
        self.assertLess(response["character"]["x"],288)
        for invalid in (float("nan"),float("inf"),-1,.06):
            with self.assertRaises(server.Rejected):self.api("move",{"seq":2,"inputs":[{"id":13,"dx":0,"dy":0,"dt":invalid}]},self.t1)
        self.assertEqual(self.s.sessions[self.t1]["input_ack"],12)

    def test_global_chat_no_history(self):
        self.both()
        third=self.activate(2,"playerthree","三号玩家");self.world(third);self.enter(third)
        self.api("chat",{"text":"你好 <b>纯文本</b>"},self.t1)
        result=self.api("poll",{"cursor":0},third)
        self.assertEqual(result["messages"][0]["nickname"],"原野一号")
        self.assertNotIn("纯文本",json.dumps(self.s.state,ensure_ascii=False))
        for i in range(2):self.api("chat",{"text":"测试"},self.t1)
        with self.assertRaises(server.Rejected):self.api("chat",{"text":"刷屏"},self.t1)
    def test_atomic_pickup_and_storage(self):
        w=self.both();w=self.s.state["worlds"][w["id"]]
        w["drops"]["one"]={"x":240,"y":240,"contents":[{"item_id":"wood","count":1}]}
        def take(token):
            try:return self.api("pickup",{"object_id":"one","index":0,"amount":1,"request_id":server.identifier()},token)["ok"]
            except server.Rejected:return False
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            results=list(pool.map(take,[self.t1,self.t2]))
        self.assertEqual(sum(results),1)
        w=self.s.state["worlds"][w["id"]]
        w["storage"]["box"]={"x":240,"y":240,"contents":[{"item_id":"stone","count":1}]}
        rid=server.identifier();request={"object_id":"box","index":0,"amount":1,"taking":True,"request_id":rid}
        self.api("storage",request,self.t1);self.api("storage",request,self.t1)
        with self.assertRaises(server.Rejected):self.api("storage",{**request,"request_id":server.identifier()},self.t2)
        c=self.s.state["characters"][self.s.state["accounts"]["TEST-001"]["player_id"]]
        self.assertEqual(sum(s.get("count",0) for s in c["slots"] if s.get("item_id")=="stone"),1)
    def test_save_failure_rolls_back(self):
        self.both()
        self.s.character(self.s.account(self.t1)[0])["slots"][8]={"item_id":"wood","count":1}
        before=json.dumps(self.s.state,sort_keys=True)
        original=self.s.save
        self.s.save=lambda:(_ for _ in ()).throw(OSError("simulated disk failure"))
        with self.assertRaises(OSError):self.api("nickname",{"nickname":"失败不提交"},self.t1)
        character=self.s.state["characters"][self.s.state["accounts"]["TEST-001"]["player_id"]]
        index=next(i for i,s in enumerate(character["slots"]) if s)
        with self.assertRaises(OSError):self.api("inventory",{"action":"drop","index":index,"amount":1,"request_id":server.identifier()},self.t1)
        self.s.save=original
        self.assertEqual(json.dumps(self.s.state,sort_keys=True),before)
        self.assertEqual(self.api("profile",{},self.t1)["profile"]["nickname"],"原野一号")
    def test_invalid_world_names_do_not_exhaust_create_limit(self):
        for name in ["", "   ", "\n", "x"*21, "a\x00", ""]:
            with self.assertRaises(server.Rejected):self.api("create_world",{"name":name},self.t1)
        self.assertFalse(self.s.limits[("world",self.s.account(self.t1)[0]["id"])])
        self.assertEqual(self.world()["name"],"测试原野")
    def test_new_character_no_starter_outfit(self):
        self.world();character=self.enter(self.t1)["character"]
        self.assertEqual([slot for slot in character["slots"] if slot],[{"item_id":"survival_guide","count":1}])
        self.assertFalse(any(character["equipment"].values()))
        self.s.state["characters"][self.s.state["accounts"]["TEST-001"]["player_id"]]["slots"][8]={"item_id":"wood","count":3}
        self.assertEqual(self.enter(self.t1)["character"]["slots"][8],{"item_id":"wood","count":3})
    def test_failed_move_save_restores_character_exploration_and_input_ack(self):
        self.both()
        before=copy.deepcopy(self.s.state)
        self.s.sessions[self.t1]["move_at"]-=.1
        session=copy.deepcopy(self.s.sessions[self.t1])
        save=self.s.save
        def fail():raise OSError("isolated disk failure")
        self.s.save=fail
        self.s.movement_checkpoint=0
        with self.assertRaises(OSError):self.api("move",{"dx":1,"dy":0,"seq":1},self.t1)
        self.assertEqual(self.s.state,before)
        self.assertEqual(self.s.sessions[self.t1],session)
        self.s.save=save
        self.assertTrue(self.api("move",{"dx":1,"dy":0,"seq":1},self.t1)["ok"])

    def test_movement_checkpoints_coalesce_but_keep_latest_position(self):
        self.both()
        now=server.time.monotonic()
        self.s.movement_checkpoint=now
        self.s.sessions[self.t1]["move_at"]=now
        save=self.s.save
        with patch.object(self.s,"save",wraps=save) as writes:
            for seq,offset in enumerate((.1,.2,.6),1):
                with patch.object(server.time,"monotonic",return_value=now+offset):self.api("move",{"dx":1,"dy":0,"seq":seq},self.t1)
                self.assertEqual(writes.call_count,1 if seq==3 else 0)
        stored=json.loads(self.s.db.execute("SELECT payload FROM state WHERE id=1").fetchone()[0])
        self.assertEqual(stored["characters"],self.s.state["characters"])
        self.assertEqual(self.s.pending_moves,0)

    def test_world_tick_coalesces_and_retry_never_repeats_command(self):
        self.both();self.s.config["gameplay_preview"]=True
        w=self.s.state["worlds"][self.s.account(self.t1)[0]["world_id"]]
        w["gameplay"]={}
        for person in self.s.state["characters"].values():person["gameplay"]={}
        calls=[]
        class Rules:
            def prepare(self, world):
                pass
            clocks={w["id"]:99.0}
            def snapshot(inner,world,character):return {"player_position":{"x":character["x"],"y":character["y"]}}
            def apply(inner,world,character,operation="snapshot",args=None,**options):
                calls.append((character["id"],operation,options))
                return {"ok":True,"snapshot":inner.snapshot(world,character),"events":[]}
        self.s.gameplay=Rules()
        with patch.object(server.time,"monotonic",return_value=100):self.api("game_snapshot",{},self.t1)
        self.assertEqual(len(calls),2)
        self.assertEqual(sum(row[2]["shared"] for row in calls),1)
        with patch.object(server.time,"monotonic",return_value=100.1):self.api("game_snapshot",{},self.t2)
        self.assertEqual(len(calls),2)
        command={"operation":"organize","args":[],"request_id":"a"*32}
        with patch.object(server.time,"monotonic",return_value=100.2):self.api("game_command",command,self.t1)
        self.assertEqual(len(calls),3)
        self.assertEqual(calls[-1][2]["elapsed"],0)
        with patch.object(server.time,"monotonic",return_value=100.3):self.api("game_command",command,self.t1)
        self.assertEqual(sum(row[1]=="organize" for row in calls),1)
        self.assertEqual(calls[-1][1],"snapshot")
        for person in self.s.state["characters"].values():person["gameplay"]["combat_personal"]={"phase":"entering"}
        with patch.object(server.time,"monotonic",return_value=100.41):self.api("game_snapshot",{},self.t1)
        advanced=len(calls)
        with patch.object(server.time,"monotonic",return_value=100.5):self.api("game_snapshot",{},self.t2)
        self.assertEqual(len(calls),advanced)
    def test_terrain_cache_never_regenerates_existing_world(self):
        w={"id":server.identifier(),"generator":"windrest-continent-0.6.0","map_cells":128}
        target=Path(self.temp.name)/"Worlds"/(w["id"]+".terrain.json")
        target.write_text(json.dumps(self.nav(w)),encoding="utf-8")
        self.assertEqual(self.s.make_terrain(w)["width"],128)
        original=target.read_bytes();w["generator"]="unknown-future-generator"
        with self.assertRaises(server.Rejected):self.s.make_terrain(w)
        self.assertEqual(target.read_bytes(),original)
        missing={"id":server.identifier(),"generator":"windrest-continent-0.6.0","map_cells":128}
        self.s.state["worlds"][missing["id"]]=missing
        with self.assertRaises(server.Rejected):self.s.make_terrain(missing)
    def test_restart_and_permanent_leave(self):
        w=self.both();self.s.save();self.s.db.close()
        self.s=server.Service(self.config,self.nav)
        self.assertEqual(self.s.state["accounts"]["TEST-001"]["world_id"],w["id"])
        self.assertEqual(len(self.s.state["characters"]),2)
        self.assertEqual(len(self.s.messages),0)
        self.t1=self.api("login",{"username":"playerone","password":"Test-password-123"})["token"]
        self.api("permanent_leave",{"confirm":w["id"]},self.t1)
        self.assertEqual(len(self.s.state["worlds"][w["id"]]["legacies"]),1)
        self.assertEqual(len(self.s.state["characters"]),1)
        self.assertEqual(self.s.state["accounts"]["TEST-001"]["nickname"],"原野一号")
    def test_admin_delete_requires_offline_backup(self):
        w=self.both()
        with self.assertRaises(server.Rejected):self.api("admin_delete_world",{"world_id":w["id"],"confirm":w["id"]},self.admin)
        self.api("leave_lobby",{},self.t1);self.api("leave_lobby",{},self.t2)
        result=self.api("admin_delete_world",{"world_id":w["id"],"confirm":w["id"]},self.admin)
        self.assertTrue((Path(self.temp.name)/"Backups"/result["backup"]).is_file())
        with server.zipfile.ZipFile(Path(self.temp.name)/"Backups"/result["backup"]) as archive:
            self.assertIn("state.sqlite3",archive.namelist())
            self.assertIn("Accounts/FIRST-ACTIVATION.private.json",archive.namelist())
        self.assertNotIn(w["id"],self.s.state["worlds"])

if __name__=="__main__":unittest.main(verbosity=2)
