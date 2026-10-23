"""Windrest LAN V0.1: TLS transport, scrypt accounts, transactional world ownership.

No credentials or chat bodies are logged. Config and writable data live outside
the program. The Godot world worker supplies the existing generator's spawn/nav.
"""
import argparse
import base64
import copy
import gzip
import datetime as dt
import hashlib
import hmac
import io
import json
import math
import os
from pathlib import Path
import re
import secrets
import shutil
import sqlite3
import ssl
import subprocess
import threading
import time
import unicodedata
import zipfile
from collections import defaultdict, deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

VERSION = "0.1.0"
PROTOCOL = 1


class ConcurrentTLSServer(ThreadingHTTPServer):
    # TLS handshakes must not block accept(). A small listening backlog plus
    # simultaneous movement/snapshot connections caused TCP retry delays.
    request_queue_size = 64
    daemon_threads = True

    def process_request_thread(self, request, client_address):
        try:
            request.settimeout(8)
            request = self.tls_context.wrap_socket(request, server_side=True)
        except (OSError, ssl.SSLError):
            request.close()
            return
        super().process_request_thread(request, client_address)


class Rejected(Exception):
    pass


def require(condition, message):
    if not condition:
        raise Rejected(message)


def digest(password, salt=None):
    require(isinstance(password, str) and 10 <= len(password) <= 128,
            "密码须为10至128个字符")
    salt = salt or secrets.token_hex(16)
    value = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt),
                           n=32768, r=8, p=1, maxmem=64*1024*1024).hex()
    return {"algorithm": "scrypt-32768-8-1", "salt": salt, "hash": value}


def verifies(password, record):
    if not record or not isinstance(password, str) or not 10 <= len(password) <= 128:
        return False
    return hmac.compare_digest(digest(password, record["salt"])["hash"], record["hash"])


def identifier():
    return secrets.token_hex(16)


class Service:
    def __init__(self, config, terrain_factory=None):
        self.config = config
        self.root = Path(config["data_dir"]).resolve()
        self.root.mkdir(parents=True, exist_ok=True)
        for name in ("Accounts", "Worlds", "Players", "Backups", "Logs"):
            (self.root/name).mkdir(exist_ok=True)
        self.db = sqlite3.connect(self.root/"state.sqlite3", check_same_thread=False)
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA synchronous=FULL")
        self.db.execute("CREATE TABLE IF NOT EXISTS state (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL)")
        row = self.db.execute("SELECT payload FROM state WHERE id=1").fetchone()
        self.state = json.loads(row[0]) if row else {"format": 1, "accounts": {}, "worlds": {}, "characters": {}, "receipts": {}}
        require(self.state.get("format") == 1, "未知存档版本，拒绝覆盖")
        self.lock = threading.RLock()
        self.request_ready = threading.Condition(self.lock)
        self.queue_lock = threading.Lock()
        self.pending_moves = 0
        self.sessions = {}
        self.limits = defaultdict(deque)
        self.messages = deque(maxlen=128)
        self.message_id = 0
        self.terrain_factory = terrain_factory or self.make_terrain
        self.nav_cache = {}
        self.mask_cache = {}
        self.gameplay = None
        self.movement_checkpoint = 0.0
        self.save()

    def save(self):
        with self.db:
            self.db.execute("INSERT OR REPLACE INTO state VALUES(1,?)", (json.dumps(self.state, ensure_ascii=False),))
        self.movement_checkpoint = time.monotonic()

    def audit(self, account, action, target=""):
        # Only fixed operation names and server-owned IDs, never request bodies.
        with (self.root/"Logs"/"audit.jsonl").open("a", encoding="utf-8") as f:
            f.write(json.dumps({"at": time.time(), "actor": account, "action": action, "target": target})+"\n")

    def backup(self):
        stem = self.root/"Backups"/str(time.time_ns())
        snapshot = stem.with_suffix(".sqlite3.tmp")
        target = stem.with_suffix(".zip")
        dest = sqlite3.connect(snapshot)
        try:
            self.db.backup(dest)
        finally:
            dest.close()
        try:
            with zipfile.ZipFile(target,"w",zipfile.ZIP_DEFLATED) as archive:
                archive.write(snapshot,"state.sqlite3")
                for folder in ("Accounts","Worlds"):
                    for file in (self.root/folder).rglob("*"):
                        if file.is_file():archive.write(file,file.relative_to(self.root))
                if (self.root/"server-public.crt").exists():archive.write(self.root/"server-public.crt","server-public.crt")
        except BaseException:
            target.unlink(missing_ok=True)
            raise
        finally:
            snapshot.unlink(missing_ok=True)
        return target.name

    def initialize(self):
        with self.lock:
            require(not self.state["accounts"], "服务器已初始化；不会重新生成凭证")
            require(not (self.root/"Accounts"/"FIRST-ACTIVATION.private.json").exists(), "本机激活凭证文件已存在，请检查数据目录")
            credentials = []
            for account_id in [f"TEST-{i:03}" for i in range(1,9)]+["ADMIN-001"]:
                token = secrets.token_urlsafe(24)
                self.state["accounts"][account_id] = {
                    "id": account_id, "player_id": identifier(), "role": "admin" if account_id == "ADMIN-001" else "player",
                    "activation": hashlib.sha256(token.encode()).hexdigest(), "username": "", "password": None,
                    "nickname": "", "nickname_uses": 0, "nickname_request": "", "avatar": "", "enabled": True,
                    "world_id": ""}
                credentials.append({"account": account_id, "activation": token})
            self.save()
            private = self.root/"Accounts"/"FIRST-ACTIVATION.private.json"
            with private.open("x", encoding="utf-8") as f:
                json.dump(credentials, f, ensure_ascii=False, indent=2)
            return private

    def rate(self, key, count, seconds):
        now = time.monotonic()
        q = self.limits[key]
        while q and q[0] < now-seconds:
            q.popleft()
        require(len(q) < count, "操作过快，请稍后重试")
        q.append(now)

    def profile(self, a):
        return {k:a[k] for k in ("id", "player_id", "username", "role", "nickname", "nickname_uses", "nickname_request", "avatar", "world_id")}

    def account(self, token):
        s = self.sessions.get(token)
        require(s is not None and s["expires"] > time.monotonic(), "会话已过期，请重新登录")
        a = self.state["accounts"][s["account"]]
        require(a["enabled"], "账号已禁用")
        s["seen"] = time.monotonic()
        s["expires"] = time.monotonic()+3600*12
        return a, s

    def nickname(self, a, value, admin=False):
        require(isinstance(value, str), "昵称格式错误")
        require(value == unicodedata.normalize("NFKC", value), "昵称含容易混淆的字符")
        require(2 <= len(value) <= 12 and all(c.isascii() and c.isalnum() or '\u4e00' <= c <= '\u9fff' for c in value), "昵称须为2至12个汉字、字母或数字")
        require(not any(x in value.lower() for x in ("admin", "gm", "管理员", "官方", "客服")), "昵称不能冒充管理人员")
        require(not any(b["id"] != a["id"] and b["nickname"].casefold() == value.casefold() for b in self.state["accounts"].values()), "昵称已使用")
        require(admin or a["nickname_uses"] < 2, "自助修改次数已用完，请向管理员申请")
        a["nickname"] = value
        if not admin:
            a["nickname_uses"] += 1
        a["nickname_request"] = ""

    def make_terrain(self, world):
        output = self.root/"Worlds"/(world["id"]+".terrain.json")
        if output.exists():
            terrain = json.loads(output.read_text(encoding="utf-8"))
            require(terrain["generator"] == world["generator"] and terrain["width"] == world["map_cells"], "地形缓存版本不一致，请恢复备份")
            return terrain
        require(world["id"] not in self.state["worlds"], "旧世界地形缓存缺失，请从备份恢复，拒绝重新生成")
        exe = self.config["godot"]
        args = [exe, "--headless", "--path", self.config["project"], "--script", "res://scripts/network_terrain_worker.gd", "--", str(world["seed"]), str(world["map_cells"]), str(output)]
        subprocess.run(args, check=True, timeout=180, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        terrain = json.loads(output.read_text(encoding="utf-8"))
        require(terrain["generator"] == world["generator"], "生成器版本不一致")
        return terrain

    def terrain(self, w):
        if w["id"] not in self.nav_cache:
            self.nav_cache[w["id"]] = self.terrain_factory(w)
        return self.nav_cache[w["id"]]

    def inventory(self, c, operation, **data):
        request_id = identifier()
        source = self.root/"Players"/(request_id+".request.tmp")
        output = self.root/"Players"/(request_id+".result.tmp")
        state = {k:c[k] for k in ("slots","equipment","hotbar_equipment")} if c else {}
        try:
            source.write_text(json.dumps({"state":state,"operation":operation,**data}),encoding="utf-8")
            subprocess.run([self.config["godot"],"--headless","--path",self.config["project"],"--script","res://scripts/network_inventory_worker.gd","--",str(source),str(output)],check=True,timeout=20,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            result = json.loads(output.read_text(encoding="utf-8"))
            require(result.get("ok"), "物品操作失败，数量不足或空间不足")
            return result
        finally:
            source.unlink(missing_ok=True)
            output.unlink(missing_ok=True)

    def online(self, world_id=None):
        now = time.monotonic()
        return {s["account"] for s in self.sessions.values() if s["seen"] > now-15 and s.get("entered") and (world_id is None or self.state["accounts"][s["account"]]["world_id"] == world_id)}

    def character(self, a):
        require(a["world_id"] in self.state["worlds"], "请先加入世界")
        return self.state["characters"].get(a["player_id"])

    def release_game_character(self, world, character):
        if not self.config.get("gameplay_preview") or "gameplay" not in character or self.gameplay is None:return
        personal = character["gameplay"]
        combat = personal.get("combat_personal", {})
        combat["attack"] = {}
        duels = world.get("gameplay", {}).get("combat_world", {}).get("duels", {})
        for key in list(duels):
            if character["id"] in key.split(":"):duels.pop(key)
        if personal.get("network_fishing", {}).get("state", "idle") != "idle":
            result = self.gameplay.apply(world, character, "fish_cancel")
            require(result.get("ok"), "钓鱼状态未能结束")
        if personal.get("body", {}).get("sleep_session"):
            result = self.gameplay.apply(world, character, "wake")
            require(result.get("ok"), "睡眠状态未能结束")

    def view_character(self, a, c):
        result = {"sample_time":time.monotonic(),"player_id": a["player_id"], "nickname": a["nickname"], "avatar": a["avatar"], **{k:c[k] for k in ("id", "x", "y", "facing", "moving", "running", "appearance", "equipment")}}
        if "gameplay" in c:
            body = c["gameplay"]["body"]
            result["visual_body"] = {key: body.get(key) for key in ("build", "sleeping", "sleep_session")}
            result["combat"] = c["gameplay"].get("combat_personal", {})
            result["pose"] = c.get("pose", {})
        return result

    def handle(self, op, data, token="", ip="local"):
        if op == "move":
            with self.queue_lock:self.pending_moves += 1
        try:
            with self.request_ready:
                if op == "game_snapshot":
                    # Drain already queued input before another expensive tick.
                    deadline = time.perf_counter()+.2
                    while self.pending_moves and time.perf_counter()<deadline:
                        self.request_ready.wait(.01)
                try:
                    return self.handle_locked(op,data,token,ip)
                finally:
                    monitor = getattr(self, "monitor", None)
                    if monitor:
                        with monitor.lock:
                            now = time.monotonic()
                            monitor.players = [{"name":self.state["accounts"][session["account"]].get("nickname") or self.state["accounts"][session["account"]].get("username", ""),
                                "last":time.time()-(now-session["seen"])}
                                for session in self.sessions.values() if session.get("entered") and session["seen"] > now-15]
        finally:
            if op == "move":
                with self.queue_lock:self.pending_moves -= 1
                with self.request_ready:self.request_ready.notify_all()

    def handle_locked(self, op, data, token="", ip="local"):
        timing = time.perf_counter()
        with self.lock:
            acquired = time.perf_counter()
            if op in ("profile", "poll", "resume", "bag", "avatar_get"):
                return {"ok": True, **copy.deepcopy(self.dispatch(op, data, token, ip))}
            before = self.state
            if op == "move" and token in self.sessions:
                # Movement touches one character and the world's explored cells.
                # Stage just those rows; retain atomic save/rollback without copying
                # every player's inventory and the entire simulation ten times/sec.
                account = before["accounts"][self.sessions[token]["account"]]
                self.state = {**before, "characters":dict(before["characters"]), "worlds":dict(before["worlds"])}
                cid, wid = account["player_id"], account["world_id"]
                if cid in before["characters"]:self.state["characters"][cid] = copy.deepcopy(before["characters"][cid])
                if wid in before["worlds"]:self.state["worlds"][wid] = {**before["worlds"][wid], "exploration":list(before["worlds"][wid]["exploration"])}
            else:
                before = copy.deepcopy(self.state)
            movement_before = copy.deepcopy(self.sessions.get(token)) if op in ("move", "game_snapshot", "game_command") else None
            gameplay_clocks_before = copy.deepcopy(getattr(self.gameplay, "clocks", {}))
            gameplay_ready_before = copy.deepcopy(getattr(self.gameplay, "tick_ready", {}))
            try:
                result = self.dispatch(op, data, token, ip)
                dispatched = time.perf_counter()
                if self.state != before and (op != "move" or time.monotonic()-self.movement_checkpoint >= .5):
                    self.save()
                if os.environ.get("WINDREST_PROFILE_NETWORK")=="1":print("SERVICE_PARTS",op,"lock",round((acquired-timing)*1000),"dispatch",round((dispatched-acquired)*1000),"save",round((time.perf_counter()-dispatched)*1000),flush=True)
                return {"ok": True, **copy.deepcopy(result)}
            except BaseException:
                self.state = before
                if movement_before is not None:self.sessions[token] = movement_before
                if self.gameplay is not None:self.gameplay.clocks = gameplay_clocks_before
                if self.gameplay is not None:self.gameplay.tick_ready = gameplay_ready_before
                raise

    def dispatch(self, op, d, token, ip):
        require(isinstance(d, dict), "请求格式错误")
        require(d.get("protocol") == PROTOCOL and d.get("version") == VERSION, "客户端与服务器版本不兼容")
        if op in ("activate", "login"):
            self.rate(("login-ip", ip), 20, 60)
            username = d.get("username", "")
            require(isinstance(username, str) and re.fullmatch(r"[a-zA-Z0-9_]{3,24}", username), "用户名须为3至24位字母、数字或下划线")
            self.rate(("login-user", username.casefold()), 8, 60)
            if op == "activate":
                a = self.state["accounts"].get(d.get("account"))
                require(a and a["enabled"] and a["activation"] and isinstance(d.get("activation"), str) and hmac.compare_digest(a["activation"], hashlib.sha256(d["activation"].encode()).hexdigest()), "账号或激活凭证无效")
                require(not a["username"] or a["username"].casefold() == username.casefold(), "重置密码须使用原登录用户名")
                require(not any(b["id"] != a["id"] and b["username"].casefold() == username.casefold() for b in self.state["accounts"].values()), "登录用户名已使用")
                a["password"] = digest(d.get("password"))
                a["username"] = username
                a["activation"] = ""
            else:
                a = next((b for b in self.state["accounts"].values() if b["username"].casefold() == username.casefold()), None)
                require(a is not None, "账号不存在")
                require(a["enabled"], "账号已禁用")
                require(verifies(d.get("password"), a["password"]), "密码错误")
            # A new login revokes old sessions; one authority for each character.
            for key in list(self.sessions):
                if self.sessions[key]["account"] == a["id"]:
                    del self.sessions[key]
            now = time.monotonic()
            for expired in [k for k,s in self.sessions.items() if s["seen"] < now-60]:
                del self.sessions[expired]
            require(len(self.sessions) < self.config.get("max_players",16), "服务器人数已满")
            key = secrets.token_urlsafe(32)
            self.sessions[key] = {"account": a["id"], "seen": time.monotonic(), "expires": time.monotonic()+43200, "entered": False, "move_at": time.monotonic(), "seq": -1}
            return {"token": key, "profile": self.profile(a), "chat_cursor": self.message_id}

        a, session = self.account(token)
        if op == "logout":
            character = self.state["characters"].get(a["player_id"])
            if character:self.release_game_character(self.state["worlds"][character["world_id"]], character)
            del self.sessions[token]
            return {}
        if op == "profile":
            return {"profile": self.profile(a)}
        if op == "password":
            self.rate(("password", a["id"]), 5, 60)
            require(verifies(d.get("current"), a["password"]), "当前密码错误")
            a["password"] = digest(d.get("password"))
            for key in list(self.sessions):
                if key != token and self.sessions[key]["account"] == a["id"]:
                    del self.sessions[key]
            self.audit(a["id"], "password_changed")
            return {}
        if op == "nickname":
            self.nickname(a, d.get("nickname"))
            return {"profile": self.profile(a)}
        if op == "nickname_request":
            value = d.get("nickname", "")
            probe = copy.deepcopy(a)
            self.nickname(probe, value, True)
            a["nickname_request"] = value
            return {"profile": self.profile(a)}
        if op == "avatar":
            self.rate(("avatar",a["id"]),5,60)
            from PIL import Image
            try:
                raw = base64.b64decode(d.get("image", ""), validate=True)
                require(0 < len(raw) <= 512*1024, "头像最大512KB")
                with Image.open(io.BytesIO(raw)) as image:
                    require(image.format in ("PNG", "JPEG", "WEBP") and max(image.size) <= 2048 and min(image.size) >= 16, "头像格式或尺寸不符合要求")
                    image.load()
                    image = image.convert("RGBA")
                    image.thumbnail((128,128))
                    out = io.BytesIO()
                    image.save(out, format="PNG")
                content = out.getvalue()
            except Rejected:
                raise
            except Exception:
                raise Rejected("无法解码头像图片")
            avatar = hashlib.sha256(content).hexdigest()
            target = self.root/"Accounts"/(avatar+".png")
            if not target.exists():
                temp = target.with_suffix(".tmp")
                temp.write_bytes(content)
                os.replace(temp, target)
            a["avatar"] = avatar
            return {"profile": self.profile(a)}
        if op == "avatar_get":
            key = d.get("avatar", "")
            require(isinstance(key,str) and re.fullmatch(r"[a-f0-9]{64}",key), "头像不存在")
            path = self.root/"Accounts"/(key+".png")
            require(path.is_file(), "头像不存在")
            return {"image": base64.b64encode(path.read_bytes()).decode()}

        require(a["nickname"], "请先设置昵称")
        if op.startswith("admin_"):
            require(a["role"] == "admin", "没有管理员权限")
            self.rate(("admin",a["id"]), 60, 60)
            target = self.state["accounts"].get(d.get("account"))
            if op == "admin_list":
                return {"accounts": [{**self.profile(b), "enabled": b["enabled"], "activated": bool(b["username"])} for b in self.state["accounts"].values()], "worlds": list(self.state["worlds"].values()), "online": list(self.online()), "version": VERSION}
            if op == "admin_create":
                aid = "TEST-"+identifier()[:8].upper()
                self.state["accounts"][aid] = {**copy.deepcopy(a), "id":aid,"player_id":identifier(),"role":"player","username":"","password":None,"nickname":"","nickname_uses":0,"nickname_request":"","avatar":"","world_id":"","enabled":True,"activation":""}
                target = self.state["accounts"][aid]
                op = "admin_reset"
            if op in ("admin_reset", "admin_enabled", "admin_nickname", "admin_reject"):
                require(target is not None, "账号不存在")
                require(target["role"] != "admin", "管理员身份仅通过本机流程维护")
                result = {}
                if op == "admin_reset":
                    activation = secrets.token_urlsafe(24)
                    target["activation"] = hashlib.sha256(activation.encode()).hexdigest()
                    target["password"] = None
                    result = {"account": target["id"], "activation": activation,"username":target["username"]}
                elif op == "admin_enabled":
                    require(type(d.get("enabled")) is bool, "状态格式错误")
                    target["enabled"] = d["enabled"]
                elif op == "admin_nickname":
                    self.nickname(target, d.get("nickname",target["nickname_request"]),True)
                else:
                    target["nickname_request"] = ""
                if op in ("admin_reset","admin_enabled"):
                    for key in list(self.sessions):
                        if self.sessions[key]["account"] == target["id"]:
                            del self.sessions[key]
                self.audit(a["id"],op,target["id"])
                return result
            if op == "admin_delete_world":
                wid = d.get("world_id")
                require(wid in self.state["worlds"] and not self.online(wid), "世界不存在或仍有在线玩家")
                require(d.get("confirm") == wid, "请确认完整世界ID")
                backup = self.backup()
                for b in self.state["accounts"].values():
                    if b["world_id"] == wid:
                        self.state["characters"].pop(b["player_id"],None)
                        b["world_id"] = ""
                del self.state["worlds"][wid]
                self.audit(a["id"],op,wid)
                return {"backup":backup}
            raise Rejected("未知管理员操作")

        if op == "worlds":
            return {"worlds": [{k:w[k] for k in ("id","name","seed","map_cells","generator")} | {"online":len(self.online(w["id"]))} for w in self.state["worlds"].values()], "profile":self.profile(a)}
        if op in ("create_world", "join_world"):
            require(not a["world_id"], "已有所属世界，请继续进入或永久退出后再加入")
            if op == "create_world":
                name = d.get("name", "原野")
                require(isinstance(name,str) and 1 <= len(name.strip()) <= 20 and not any(unicodedata.category(c).startswith("C") for c in name), "世界名称不合法")
                self.rate(("world",a["id"]), 5, 60)
                wid = identifier()
                w = {"id":wid,"name":name.strip(),"seed":secrets.randbelow(2147483646)+1,"map_cells":self.config.get("world_cells",1536),"generator":"windrest-continent-0.6.0","format":1,"clock":0.0,"weather":"clear","storage":{},"drops":{},"legacies":{},"exploration":[],"systems": {"buildings":{},"resources":{},"animals":{},"crops":{},"fish":{},"merchant":{}}}
                nav = self.terrain_factory(w)
                self.nav_cache[wid] = nav
                w["spawn"] = nav["spawn"]
                self.state["worlds"][wid] = w
            else:
                wid = d.get("world_id")
                require(wid in self.state["worlds"], "世界不存在")
                self.rate(("world",a["id"]), 5, 60)
            a["world_id"] = wid
            return {"profile":self.profile(a), "world":self.state["worlds"][wid]}
        if op == "character":
            if self.config.get("gameplay_preview") is True:require(d.get("gameplay_revision") == 1, "请更新完整联机客户端后再进入世界")
            c = self.character(a)
            w = self.state["worlds"][a["world_id"]]
            if c is None:
                appearance = d.get("appearance")
                require(isinstance(appearance,dict), "请创建人物")
                gender = appearance.get("gender")
                hairs = {"male":["male_short","male_parted","male_messy","male_cropped"],"female":["female_bob","female_long","female_ponytail","female_bun"]}
                # Catalog IDs are supplied in config from the existing catalog.
                hairs = self.config.get("hair_ids",hairs)
                available_hair = {hair for group in hairs.values() for hair in group}
                require(gender in ["male","female"] and appearance.get("hair_id") in available_hair and appearance.get("skin_id") in [f"skin_{i}" for i in range(1,7)], "人物外观选项无效")
                initial = self.inventory(None,"create")
                c = {"id":identifier(),"world_id":w["id"],"x":w["spawn"][0],"y":w["spawn"][1],"facing":"front","moving":False,"running":False,"appearance":{k:appearance[k] for k in ("gender","hair_id","skin_id")},"slots":initial["slots"],"equipment":initial["equipment"],"hotbar_equipment":initial["hotbar_equipment"],"body":{"health":100,"hunger":100,"energy":100},"outfit_granted":True}
                self.state["characters"][a["player_id"]] = c
                c["guide_stage"] = 0
            session["entered"] = True
            session["seq"] = -1
            session["move_at"] = time.monotonic()
            session["input_ack"] = 0
            session["move_credit"] = .15
            session["game_fresh"] = True
            return {"world":w,"character":c, "profile":self.profile(a), "movement_revision":2, "gameplay_enabled":self.config.get("gameplay_preview") is True}
        if op == "resume":
            c = self.character(a)
            return {"world":self.state["worlds"][a["world_id"]],"character":c}
        if op in ("game_snapshot", "game_command"):
            # Staging only until the complete client, simulation and multiplayer
            # acceptance tests pass. Existing deployed configurations stay V0.1.
            require(self.config.get("gameplay_preview") is True, "完整玩法联机尚在接入，当前服务器未开放")
            require(session.get("entered"), "请先进入世界")
            c = self.character(a)
            require(c is not None, "人物不存在")
            w = self.state["worlds"][a["world_id"]]
            if self.gameplay is None:
                try:
                    from .gameplay import Gameplay
                except ImportError:
                    from gameplay import Gameplay
                self.gameplay = Gameplay(self.config)
            if session.get("game_fresh"):
                self.release_game_character(w, c)
                session["game_fresh"] = False
            # One wall-clock interval per world, and one personal interval per
            # present character. Never advance shared machines once per player.
            now = time.monotonic()
            last = getattr(self.gameplay, "clocks", {}).get(w["id"], now)
            if not hasattr(self.gameplay, "clocks"):self.gameplay.clocks = {}
            elapsed = min(5.0, max(0.0, now-last))
            # Several clients may ask for the same world update together. Reuse
            # committed state between ticks instead of simulating everyone again.
            combat_pending = any(p.get("gameplay", {}).get("combat_personal", {}).get("attack") or p.get("gameplay", {}).get("combat_personal", {}).get("phase", "alive") != "alive"
                                 for p in self.state["characters"].values() if p["world_id"] == w["id"])
            combat_pending = combat_pending or any(b.get("mode") in ("alert", "attack", "chase") for b in w.get("gameplay", {}).get("combat_world", {}).get("boars", {}).values())
            tick_due = w["id"] not in self.gameplay.clocks or (elapsed >= (.2 if combat_pending else .75) and now >= getattr(self.gameplay,"tick_ready",{}).get(w["id"],0))
            if op == "game_snapshot" and not tick_due and "gameplay" in w and "gameplay" in c:
                selected = d.get("selected", c.get("selected", 0))
                require(type(selected) is int and 0 <= selected < 8, "快捷栏无效")
                c["selected"] = c["gameplay"]["selected"] = selected
                return {"gameplay_revision":1,"snapshot":self.gameplay.snapshot(w,c),"events":[]}
            if tick_due:self.gameplay.clocks[w["id"]] = now
            else:elapsed = 0.0
            present = [self.state["characters"][self.state["accounts"][aid]["player_id"]]
                       for aid in self.online(w["id"]) if self.state["accounts"][aid]["player_id"] in self.state["characters"]]
            present_ids = {person["id"] for person in present}
            self.gameplay.combat_characters = present
            tick_events = []
            for person in self.state["characters"].values():
                if person["world_id"] == w["id"] and person["id"] not in present_ids:self.release_game_character(w, person)
            others = [person for person in present if person["id"] != c["id"]]
            if elapsed > 0 and "gameplay" in w:
                for index, person in enumerate(others):
                    tick = self.gameplay.apply(w, person, elapsed=elapsed, shared=index==0)
                    require(tick.get("ok"), tick.get("error", "世界计时失败"))
            rid = d.get("request_id", "")
            replayed = False
            if op == "game_command":
                require(isinstance(rid, str) and re.fullmatch(r"[a-f0-9]{32}", rid), "操作编号无效")
                key = "game:"+c["id"]+":"+rid
                if key in self.state["receipts"]:
                    replayed = True
                else:self.rate(("gameplay", a["id"]), 30, 5)
            selected = d.get("selected", c.get("selected", 0))
            require(type(selected) is int and 0 <= selected < 8, "快捷栏无效")
            c["selected"] = selected
            if "gameplay" in c:
                c["gameplay"]["selected"] = selected
            try:
                result = self.gameplay.apply(w, c, d.get("operation", "snapshot") if op == "game_command" and not replayed else "snapshot", d.get("args", []) if op == "game_command" and not replayed else [], elapsed=elapsed, shared=not others, station=d.get("station"), expected=d.get("expected"))
            except ValueError as error:
                raise Rejected(str(error)) from error
            require(result.get("ok"), result.get("error", "玩法操作失败"))
            if tick_due:
                # Leave room for the queued movement requests after a simulation
                # tick. Its processing time remains in clocks, so the next tick
                # catches up real elapsed time instead of slowing the world.
                if not hasattr(self.gameplay,"tick_ready"):self.gameplay.tick_ready = {}
                self.gameplay.tick_ready[w["id"]] = time.monotonic()+(.05 if combat_pending else .15)
            response = {"gameplay_revision": 1, "snapshot": result["snapshot"], "events": tick_events+result.get("events", [])}
            if op == "game_command":
                # Store the acknowledgment, not a complete copy of the world per
                # click. Retries return the latest committed snapshot.
                self.state["receipts"][key] = {"accepted": True}
            return response
        if op == "leave_lobby":
            session["entered"] = False
            c = self.state["characters"].get(a["player_id"])
            if c:
                self.release_game_character(self.state["worlds"][c["world_id"]], c)
                c["moving"] = False
            return {}
        if op == "permanent_leave":
            wid = a["world_id"]
            require(wid in self.state["worlds"], "没有所属世界")
            require(d.get("confirm") == wid, "请确认永久退出世界")
            c = self.state["characters"].pop(a["player_id"],None)
            if c:
                self.release_game_character(self.state["worlds"][wid], c)
                self.state["worlds"][wid]["legacies"][c["id"]] = {k:c[k] for k in ("x","y","slots","equipment","hotbar_equipment")}
            a["world_id"] = ""
            session["entered"] = False
            return {"profile":self.profile(a)}
        if op == "chat":
            self.rate(("chat",a["id"]), 3, 5)
            text = d.get("text")
            require(isinstance(text,str) and 1 <= len(text.strip()) <= 120 and not any(unicodedata.category(c).startswith("C") for c in text), "消息须为1至120个可见字符")
            self.message_id += 1
            self.messages.append({"id":self.message_id,"player_id":a["player_id"],"nickname":a["nickname"],"avatar":a["avatar"],"text":text.strip(),"at":time.monotonic()})
            return {}
        if op == "poll":
            cursor = int(d.get("cursor", self.message_id))
            now = time.monotonic()
            messages = [{k:v for k,v in m.items() if k != "at"} for m in self.messages if m["id"] > cursor and m["at"] > now-5]
            players = []
            if session["entered"]:
                for aid in self.online(a["world_id"]):
                    b = self.state["accounts"][aid]
                    c = self.state["characters"].get(b["player_id"])
                    if c:
                        players.append(self.view_character(b,c))
            objects = []
            if session["entered"]:
                c = self.character(a)
                w = self.state["worlds"][a["world_id"]]
                for kind in ("drops","storage"):
                    objects.extend({"id":key,"kind":kind,**obj} for key,obj in w[kind].items() if math.hypot(obj["x"]-c["x"],obj["y"]-c["y"])<1800 and (kind == "storage" or any(obj["contents"])))
                for key,legacy in w["legacies"].items():
                    if math.hypot(legacy["x"]-c["x"],legacy["y"]-c["y"])<1800:
                        objects.append({"id":"legacy:"+key,"kind":"storage","x":legacy["x"],"y":legacy["y"],"contents":legacy["slots"]+[v for v in legacy["equipment"].values() if v]})
            return {"players_sample_time":time.monotonic(),"players":players,"objects":objects,"messages":messages,"cursor":self.message_id,"profile":self.profile(a)}
        if op == "move":
            require(session["entered"], "请先进入世界")
            c = self.character(a)
            require(c is not None, "人物不存在")
            seq = d.get("seq")
            require(type(seq) is int and seq > session["seq"], "重复移动请求")
            if self.config.get("gameplay_preview") is True and "pose" in d:
                pose = d["pose"]
                require(isinstance(pose, dict) and pose.get("action") in ("", "chop", "mine", "dig", "demolish", "pickup", "shear", "fertilize", "feed", "throw"), "人物动作无效")
                require(type(pose.get("clock")) in (int,float) and math.isfinite(pose["clock"]) and 0 <= pose["clock"] <= 10, "人物动作时序无效")
                require(pose.get("facing") in ("front", "back", "left", "right"), "人物方向无效")
                c["pose"] = {key:pose[key] for key in ("action", "clock", "facing")}
                c["facing"] = pose["facing"]
            x,y = d.get("dx",0),d.get("dy",0)
            require(type(x) in (int,float) and type(y) in (int,float) and math.isfinite(x) and math.isfinite(y) and abs(x)<=1 and abs(y)<=1, "无效移动输入")
            now = time.monotonic()
            elapsed = min(1.0, max(0,now-session["move_at"]))
            inputs = d.get("inputs")
            ack = session.get("input_ack",0)
            credit = min(1.75, session.get("move_credit",.15)+max(0,now-session["move_at"]))
            if inputs is not None:
                require(isinstance(inputs,list) and len(inputs)<=90, "Invalid movement batch")
                total = 0.0
                previous_id = 0
                fresh = []
                for item in inputs:
                    require(isinstance(item,dict) and type(item.get("id")) is int and item["id"]>previous_id, "Invalid movement order")
                    previous_id = item["id"]
                    require(type(item.get("dt")) in (int,float) and math.isfinite(item["dt"]) and 0<item["dt"]<=.05, "Invalid movement duration")
                    require(all(type(item.get(k)) in (int,float) and math.isfinite(item[k]) and abs(item[k])<=1 for k in ("dx","dy")), "Invalid movement direction")
                    if item["id"]>ack:
                        total += item["dt"];ack=item["id"];fresh.append(item)
                # A delayed batch can exceed the current clock budget. Consume
                # only its affordable prefix; leave the suffix unacknowledged so
                # the existing client retries it without losing movement or
                # repeatedly rejecting the complete queue. Never grant extra time.
                if total > credit+.002:
                    affordable = []
                    total = 0.0
                    ack = session.get("input_ack", 0)
                    for item in fresh:
                        if total+item["dt"] > credit+.002:break
                        total += item["dt"]
                        ack = item["id"]
                        affordable.append(item)
                    fresh = affordable
                inputs = fresh
                session["move_credit"] = max(0,credit-total)
                session["input_ack"] = ack
            session["move_at"],session["seq"] = now,seq
            length = max(1,math.hypot(x,y))
            speed = 310 if d.get("run") is True else 200
            w = self.state["worlds"][a["world_id"]]
            nav = self.terrain(w)
            mask = self.mask_cache.get(w["id"])
            if mask is None:
                mask = base64.b64decode(nav["mask"]);self.mask_cache[w["id"]] = mask
            def safe(px,py):
                ix,iy = math.floor(px/nav["step"]),math.floor(py/nav["step"])
                return 0<=ix<nav["width"] and 0<=iy<nav["width"] and mask[iy*nav["width"]+ix] == 1
            steps = inputs if inputs is not None else [{"dx":x,"dy":y,"dt":elapsed,"run":d.get("run")}]
            formal_movement = self.config.get("gameplay_preview") is True and "gameplay" in w and "gameplay" in c
            if formal_movement and any(item["dx"] or item["dy"] for item in steps):
                position = self.gameplay.hosts[w["id"]].movement(w, c, steps)
                c["x"],c["y"] = position["x"],position["y"]
            for item in steps:
                x,y = item["dx"],item["dy"]
                length = max(1,math.hypot(x,y))
                speed = 310 if item.get("run") is True else 200
                if formal_movement:continue
                count = max(1,math.ceil(speed*item["dt"]/12))
                for _ in range(count):
                    nx,ny = c["x"]+x/length*speed*item["dt"]/count,c["y"]+y/length*speed*item["dt"]/count
                    if safe(nx,c["y"]):c["x"] = nx
                    if safe(c["x"],ny):c["y"] = ny
            c["moving"] = bool(x or y)
            c["running"] = steps[-1].get("run") is True if steps else False
            if x or y:
                c["facing"] = ("right" if x>0 else "left") if abs(x)>abs(y) else ("front" if y>0 else "back")
            cell = int(c["y"]/48)*w["map_cells"]+int(c["x"]/48)
            if cell not in w["exploration"]:
                w["exploration"].append(cell)
            players = []
            for aid in self.online(w["id"]):
                person = self.state["accounts"][aid]
                other = self.state["characters"].get(person["player_id"])
                if other:players.append(self.view_character(person,other))
            return {"character":{k:c[k] for k in ("id","x","y","facing","moving","running")},"input_ack":session.get("input_ack",0),"movement_revision":2,"players_sample_time":time.monotonic(),"players":players}
        if op in ("pickup", "storage", "inventory", "bag"):
            require(session["entered"], "请先进入世界")
            c = self.character(a)
            w = self.state["worlds"][a["world_id"]]
            require(c is not None, "人物不存在")
            if op == "bag":
                return {"character":c}
            require(not (self.config.get("gameplay_preview") is True and "gameplay" in c), "请使用新版客户端的原版背包操作")
            rid = d.get("request_id")
            require(isinstance(rid,str) and re.fullmatch(r"[a-f0-9]{32}",rid), "缺少事务ID")
            key = a["player_id"]+":"+rid
            if key in self.state["receipts"]:
                return self.state["receipts"][key]
            if op == "inventory":
                action = d.get("action")
                require(action in ("equip","unequip","move","drop"), "物品操作无效")
                index = d.get("index")
                require(type(index) is int and 0<=index<48, "物品格无效")
                if action == "move":
                    require(type(d.get("to")) is int and 0<=d["to"]<48, "物品格无效")
                amount = d.get("amount",1)
                require(type(amount) is int and 1<=amount<=99, "数量错误")
                updated = self.inventory(c,action,index=index,to=d.get("to",0),amount=amount)
                for field in ("slots","equipment","hotbar_equipment"):
                    c[field] = updated[field]
                if action == "drop":
                    w["drops"][rid] = {"x":c["x"],"y":c["y"]+16,"contents":[updated["dropped"]]}
                result = {"character":copy.deepcopy(c)}
                self.state["receipts"][key] = result
                return result
            object_id = d.get("object_id", "")
            legacy_key = object_id.removeprefix("legacy:") if isinstance(object_id,str) and object_id.startswith("legacy:") else ""
            if legacy_key and op == "storage":
                legacy = w["legacies"].get(legacy_key)
                require(legacy is not None and d.get("taking") is True, "遗产只能取出")
                # Normalize equipment into physical slots once, preserving instances.
                if legacy["equipment"]:
                    legacy["slots"].extend(v for v in legacy["equipment"].values() if v)
                    legacy["equipment"] = {}
                obj = {"x":legacy["x"],"y":legacy["y"],"contents":legacy["slots"]}
            else:
                obj = w["drops" if op == "pickup" else "storage"].get(object_id)
            require(obj is not None and math.hypot(obj["x"]-c["x"],obj["y"]-c["y"])<=120, "物品不存在或距离太远")
            amount = d.get("amount")
            require(type(amount) is int and 1<=amount<=999, "数量错误")
            index = d.get("index")
            require(type(index) is int and 0<=index<64, "物品格无效")
            taking = op == "pickup" or d.get("taking") is True
            updated = self.inventory(c,"transfer",index=index,amount=amount,taking=taking,contents=obj["contents"])
            for field in ("slots","equipment","hotbar_equipment"):
                c[field] = updated[field]
            obj["contents"] = updated["contents"]
            if legacy_key:
                legacy["slots"] = updated["contents"]
            result = {"character":copy.deepcopy(c),"storage":copy.deepcopy(obj["contents"])}
            self.state["receipts"][key]=result
            return result
        raise Rejected("该功能尚未接入联机服务器")


class TrafficMonitor:
    """Bounded, local-only telemetry; never records tokens or request bodies."""
    def __init__(self, root):
        self.path = root / "server-monitor.json"
        self.lock = threading.Lock()
        self.started = time.time()
        self.active = self.total = self.received = self.sent = self.errors = 0
        self.samples = deque(maxlen=1000)
        self.events = deque(maxlen=80)
        self.clients = {}
        self.players = []
        threading.Thread(target=self.publish, daemon=True).start()

    def begin(self):
        with self.lock:self.active += 1

    def finish(self, ip, op, status, received, sent, elapsed):
        with self.lock:
            self.active -= 1
            self.total += 1
            self.received += received
            self.sent += sent
            self.errors += status >= 400
            now = time.time()
            self.samples.append((now, elapsed))
            row = self.clients.setdefault(ip, {"count":0})
            row.update(last=now, operation=op, milliseconds=elapsed, status=status)
            row["count"] += 1
            self.events.append({"time":now,"ip":ip,"operation":op,"status":status,"ms":elapsed})
            self.clients = {k:v for k,v in self.clients.items() if now-v["last"] < 300}

    def publish(self):
        while True:
            try:
                with self.lock:
                    now = time.time()
                    recent = sorted(ms for stamp,ms in self.samples if now-stamp <= 30)
                    value = dict(pid=os.getpid(), updated=now, started=self.started,
                        active=self.active,total=self.total,received=self.received,sent=self.sent,
                        errors=self.errors, rate=sum(now-t <= 5 for t,_ in self.samples)/5,
                        p50=recent[len(recent)//2] if recent else 0,
                        p95=recent[min(len(recent)-1,int(len(recent)*.95))] if recent else 0,
                        players=list(self.players),clients=dict(self.clients),events=list(self.events))
                temporary = self.path.with_suffix(".tmp")
                temporary.write_text(json.dumps(value), encoding="utf-8")
                os.replace(temporary,self.path)
            except OSError:
                pass
            time.sleep(1)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        # Public releases only. Never expose Data, configuration or private keys.
        name = self.path.removeprefix("/updates/")
        if not self.path.startswith("/updates/") or not (name == "latest.json" or re.fullmatch(r"client-[a-f0-9]{64}\.zip", name)):
            self.send_error(404); return
        path = self.server.service.root.parent/"Updates"/name
        try:
            with path.open("rb") as source:
                self.connection.settimeout(60)
                self.send_response(200)
                self.send_header("Content-Type", "application/json" if name == "latest.json" else "application/zip")
                self.send_header("Content-Length", str(os.fstat(source.fileno()).st_size))
                self.send_header("Cache-Control", "no-store" if name == "latest.json" else "public, max-age=31536000, immutable")
                self.end_headers()
                shutil.copyfileobj(source, self.wfile, 1024*1024)
        except FileNotFoundError:
            self.send_error(404)
        except (ConnectionError, OSError):
            pass

    def do_POST(self):
        monitor = getattr(self.server, "monitor", None)
        started = time.perf_counter()
        self.monitor_received = self.monitor_sent = 0
        self.monitor_status = 500
        if monitor:monitor.begin()
        try:
            self.post_request()
        finally:
            if monitor:
                # Only retain known endpoint labels, never arbitrary URL content.
                op = self.path.removeprefix("/api/")
                if not re.fullmatch(r"[a-z_]{1,40}", op):op = "unknown"
                monitor.finish(self.client_address[0],op,self.monitor_status,
                    self.monitor_received,self.monitor_sent,(time.perf_counter()-started)*1000)

    def post_request(self):
        try:
            self.connection.settimeout(8)
            length = int(self.headers.get("Content-Length", "0"))
            require(0 < length <= 750000, "请求体过大或为空")
            raw = self.rfile.read(length)
            self.monitor_received = len(raw)
            data = json.loads(raw)
            op = self.path.removeprefix("/api/")
            token = self.headers.get("Authorization", "").removeprefix("Bearer ")
            result = self.server.service.handle(op,data,token,self.client_address[0])
            status = 200
        except (Rejected,ValueError,TypeError,KeyError) as exc:
            result,status = {"ok":False,"error":str(exc) if isinstance(exc,Rejected) else "请求格式错误"},400
        except Exception:
            result,status = {"ok":False,"error":"服务器操作失败，数据未提交"},500
        body = json.dumps(result,ensure_ascii=False).encode()
        compressed = False
        # Exploration is mostly unchanged zero-filled map data. Compress large
        # gameplay replies outside the transaction lock, preserving old clients.
        encodings = [part.strip().lower().replace(" ", "") for part in self.headers.get("Accept-Encoding", "").split(",")]
        gzip_allowed = any(part.split(";")[0] == "gzip" and not re.search(r";q=0(?:\.0*)?$",part) for part in encodings)
        if self.path in ("/api/game_snapshot", "/api/game_command", "/api/move", "/api/poll") and len(body) >= 2048 and gzip_allowed:
            packed = gzip.compress(body, compresslevel=1, mtime=0)
            if len(packed) < len(body):body = packed;compressed = True
        self.monitor_status = status
        self.monitor_sent = len(body)
        self.send_response(status)
        self.send_header("Content-Type","application/json; charset=utf-8")
        if compressed:self.send_header("Content-Encoding", "gzip")
        self.send_header("Vary", "Accept-Encoding")
        self.send_header("Content-Length",str(len(body)))
        self.send_header("Cache-Control","no-store")
        self.end_headers()
        self.wfile.write(body)


def certificate(root):
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.x509.oid import NameOID
    cert_path,key_path = root/"server-public.crt",root/"Accounts"/"server-key.private.pem"
    if cert_path.exists() and key_path.exists():
        return cert_path,key_path
    require(not cert_path.exists() and not key_path.exists(), "证书或私钥缺失，请从备份恢复，拒绝静默换证")
    key = rsa.generate_private_key(public_exponent=65537,key_size=3072)
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,"windrest-server")])
    now = dt.datetime.now(dt.timezone.utc)
    cert = x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key()).serial_number(x509.random_serial_number()).not_valid_before(now-dt.timedelta(minutes=5)).not_valid_after(now+dt.timedelta(days=730)).add_extension(x509.SubjectAlternativeName([x509.DNSName("windrest-server")]),critical=False).add_extension(x509.BasicConstraints(ca=True,path_length=0),critical=True).sign(key,hashes.SHA256())
    key_path.write_bytes(key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
    cert_path.write_bytes(cert.public_bytes(serialization.Encoding.PEM))
    return cert_path,key_path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config",required=True)
    parser.add_argument("--initialize",action="store_true")
    parser.add_argument("--backup",action="store_true")
    args = parser.parse_args()
    path = Path(args.config).resolve()
    config = json.loads(path.read_text(encoding="utf-8-sig"))
    config["data_dir"] = str((path.parent/config["data_dir"]).resolve())
    config["project"] = str((path.parent/config.get("project","..")).resolve())
    if not Path(config["godot"]).is_absolute():
        config["godot"] = str((path.parent/config["godot"]).resolve())
    service = Service(config)
    cert,key = certificate(service.root)
    if os.name == "nt":
        # Protect credentials and private key from other Windows users on this PC.
        # SID is ASCII regardless of the Windows account name / console code page.
        identity = subprocess.check_output(["whoami", "/user", "/fo", "csv", "/nh"])
        sid = re.search(rb'S-1-\d+(?:-\d+)+', identity)
        require(sid is not None, "无法确定当前Windows账户SID")
        user = "*" + sid.group().decode("ascii")
        subprocess.run(["icacls",str(service.root),"/inheritance:r","/grant:r",f"{user}:(OI)(CI)F","SYSTEM:(OI)(CI)F"],check=True,stdout=subprocess.DEVNULL)
    if args.initialize:
        private = service.initialize()
        print("初始化完成。一次性凭证仅保存于本机受保护文件：",private)
        print("仅将 server-public.crt 分发给客户端。")
        return
    require(service.state["accounts"], "请先在本机执行 --initialize")
    if args.backup:
        print(service.backup())
        return
    service.backup()
    server = ConcurrentTLSServer((config.get("bind","0.0.0.0"),config.get("port",24870)),Handler)
    server.daemon_threads = True
    server.service = service
    server.monitor = TrafficMonitor(service.root)
    service.monitor = server.monitor
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(cert,key)
    server.tls_context = context
    print(f"Windrest {VERSION} LAN server listening on {config.get('bind')}:{config.get('port')}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        if service.gameplay is not None:service.gameplay.close()
        service.save()
        service.db.close()


if __name__ == "__main__":
    main()
