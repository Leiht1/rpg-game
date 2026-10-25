"""Transactional projection of original game saves into shared and personal state."""
import copy
import math
import threading

try:
    from .game_host import GameHost
except ImportError:
    from game_host import GameHost

PERSONAL = frozenset(("slots", "equipment", "equipment_quarantine", "hotbar_equipment",
                      "mine_travel", "selected", "body", "player_position", "lantern_remaining", "guide_stage",
                      "combat_personal", "network_craft_job", "network_craft_station", "network_active_lamp", "network_lamp_on", "network_fishing", "network_light_clock"))
ARITY = {"mine":1,"chapter":1,"chapter_read":1,"guide":1,"combat_duel":2,"combat_attack":1,"relic_claim":3,"snapshot": 0, "organize": 0, "craft": 2, "craft_cancel": 0, "station": 1,
         "discard": 2, "inventory": None, "camp_act": 4, "camp_feed": 4,
         "camp_place": 3, "camp_build": 3, "building_place": 2,
         "building_toggle": 1, "building_open": 2, "building_bag": 3,
         "building_transfer": 5, "building_edit": 6, "plant": 2, "fertilize": 1,
         "industry": 6, "expansion": 6, "animal_feed": 3, "buy": 1,
         "sleep": 2, "wake": 0, "lamp": 1, "interact": 1,
         "fish_start": 0, "fish_judge": 0, "fish_cancel": 0}


def validate(operation, args):
    if not isinstance(operation, str) or operation not in ARITY or not isinstance(args, list):
        raise ValueError("Unknown gameplay command")
    if ARITY[operation] is not None and len(args) != ARITY[operation]:
        raise ValueError("Invalid gameplay command arguments")
    def visit(value, depth=0):
        if depth > 8:
            raise ValueError("Gameplay command is too deeply nested")
        if isinstance(value, float) and not math.isfinite(value):
            raise ValueError("Non-finite gameplay value")
        if isinstance(value, str) and len(value) > 256:
            raise ValueError("Gameplay text is too long")
        if isinstance(value, (list, dict)):
            if len(value) > 80:
                raise ValueError("Gameplay command is too large")
            for child in (value.values() if isinstance(value, dict) else value):
                visit(child, depth+1)
        elif not isinstance(value, (str, int, float, bool, type(None))):
            raise ValueError("Invalid gameplay value")
    visit(args)
    signatures = {"mine":(str,),"chapter":(str,),"chapter_read":(str,),"combat_duel":(str,bool),"combat_attack":(dict,),"relic_claim":(str,int,dict),
        "guide": (int,), "craft": (str, int), "station": (str,), "discard": (int, int),
        "camp_act": (str, str, str, dict), "camp_feed": (str, int, dict, int),
        "camp_place": (dict, int, dict), "camp_build": (dict, str, list),
        "building_place": (dict, list), "building_bag": (dict, int, dict),
        "building_toggle": (str,), "building_open": (str, bool),
        "building_transfer": (str, int, int, dict, dict),
        "building_edit": (str, int, dict, str, int, int),
        "industry": (str, str, int, str, int, dict),
        "expansion": (str, str, int, dict, str, int),
        "animal_feed": (str, int, dict), "plant": (str, str),
        "fertilize": (str,), "buy": (str,), "sleep": (str, str), "lamp": (int,), "interact": (dict,),
    }
    if operation in signatures and any(type(value) is not kind for value, kind in zip(args, signatures[operation])):
        raise ValueError("Invalid gameplay argument type")
    if operation == "combat_attack":
        direction = args[0]
        if set(direction) != {"x", "y"} or any(type(direction[k]) not in (int, float) or not math.isfinite(direction[k]) or abs(direction[k])>1 for k in ("x", "y")):
            raise ValueError("Invalid attack direction")
        if direction["x"]**2+direction["y"]**2 < .001:
            raise ValueError("Empty attack direction")
    for value in args:
        if type(value) is int and not -1 <= value <= 10000:
            raise ValueError("Gameplay quantity or index is out of range")
    if operation in ("camp_place", "camp_build", "building_place", "building_bag"):
        row = args[0]
        if any(type(row.get(axis)) not in (int, float) or not math.isfinite(row[axis])
               or not 0 <= row[axis] <= 100000 for axis in ("x", "y")):
            raise ValueError("Invalid placement coordinates")
        if operation == "building_place":
            if type(row.get("kind")) is not str or type(row.get("facing", 0)) is not int or row.get("facing", 0) not in (0, 1, 2, 3):
                raise ValueError("Invalid building kind or direction")
            if any(type(row.get(key, False)) is not bool for key in ("vertical", "inward")):
                raise ValueError("Invalid building orientation")
    if operation == "inventory":
        methods = {"equip": 1, "unequip": 1, "move_slot": 2, "split_slot": 2,
                   "destroy_slot": 1, "use_slot": 1, "equip_hotbar": 2}
        if not args or args[0] not in methods or len(args) != methods[args[0]]+1:
            raise ValueError("Invalid inventory command")
        if not all(type(value) is int and 0 <= value <= 10000 for value in args[1:]):
            raise ValueError("Invalid inventory index or quantity")
    if operation == "interact":
        if not isinstance(args[0], dict) or len(args[0]) != 1 or next(iter(args[0])) not in (
                "animal_id", "building_id", "camp_id", "drop_id", "prop_id", "ore_id", "tree_id"):
            raise ValueError("Invalid target identity")


class Gameplay:
    def __init__(self, config):
        self.config = config
        self.hosts = {}
        self.defaults = {}
        self.combat_characters = []
        self.start_lock = threading.Lock()

    def prepare(self, world):
        """Start a rules process without holding the service transaction lock.

        Bootstrap only creates immutable defaults; authoritative state is restored
        by apply inside the normal transaction after authentication is rechecked.
        Concurrent entrants must share exactly one process and private channel.
        """
        wid = world["id"]
        host = self.hosts.get(wid)
        if host is not None and host.process is not None and host.process.poll() is None and wid in self.defaults:
            return host
        with self.start_lock:
            host = self.hosts.get(wid)
            if host is None or host.process is None or host.process.poll() is not None:
                if host is not None:
                    host.close()
                self.hosts.pop(wid, None)
                self.defaults.pop(wid, None)
                host = GameHost(self.config, {k: world[k] for k in ("id", "seed", "map_cells")})
                try:
                    defaults = host.execute()["snapshot"]
                except BaseException:
                    host.close()
                    raise
                self.defaults[wid] = defaults
                self.hosts[wid] = host
            return host

    def close(self):
        for host in self.hosts.values():
            host.close()
        self.hosts.clear()
        self.defaults.clear()

    @staticmethod
    def snapshot(world, character):
        snapshot = copy.deepcopy(world["gameplay"])
        snapshot.update(copy.deepcopy(character["gameplay"]))
        snapshot["player_position"] = {"x": character["x"], "y": character["y"]}
        return snapshot

    def apply(self, world, character, operation="snapshot", args=None, elapsed=0, shared=True, station=None, expected=None, combat_damage=None):
        args = args or []
        validate(operation, args)
        if expected is not None and (not isinstance(expected, dict) or len(expected)>2 or any(not isinstance(key, str) or not key.isdigit() or not 0<=int(key)<48 or not isinstance(value, dict) for key,value in expected.items())):
            raise ValueError("Invalid inventory source snapshot")
        wid = world["id"]
        host = self.prepare(world)
        shared_state = world.get("gameplay")
        personal = character.get("gameplay")
        if shared_state is None:
            baseline = copy.deepcopy(self.defaults[wid])
        else:
            baseline = copy.deepcopy(shared_state)
        if personal is None:
            # New characters inherit world rules, never another player's inventory/body.
            initial = self.defaults[wid]
            personal = {key: copy.deepcopy(initial[key]) for key in PERSONAL if key in initial}
            for key in ("slots", "equipment", "hotbar_equipment"):
                personal[key] = copy.deepcopy(character[key])
            personal["combat_personal"]["phase"] = "entering"
            personal["guide_stage"] = character.get("guide_stage", 2)
            personal["combat_personal"]["clock"] = 0.0
            spawn = baseline.get("combat_world", {}).get("spawn", initial["player_position"])
            character["x"],character["y"] = spawn["x"],spawn["y"]
        baseline.update(copy.deepcopy(personal))
        # Preserve contents from the earlier minimal online scene as ordinary
        # ground items. Stable identities make the migration idempotent.
        migrated = []
        for kind in ("drops", "storage", "legacies"):
            for identity, container in world.get(kind, {}).items():
                entries = container.get("contents", container.get("slots", []))
                if kind == "legacies":entries = entries+[value for value in container.get("equipment", {}).values() if value]
                for index, value in enumerate(entries):
                    if not value:continue
                    key = "online-v1:"+kind+":"+identity+":"+str(index)
                    if key not in baseline["loose"] and key not in baseline["consumed"]:
                        baseline["loose"][key] = {"id":key,"item_id": value["item_id"], "count": value["count"],
                                                   "x": container["x"]+(index%3-1)*18,
                                                   "y": container["y"]+(index//3)*12,
                                                   "instance": copy.deepcopy(value), "mode": "pickup"}
                migrated.append((kind, identity))
        baseline["player_position"] = {"x": character["x"], "y": character["y"]}
        motion = {key: character[key] for key in ("slots", "equipment", "hotbar_equipment", "x", "y")}
        motion.update({"appearance": character.get("appearance", {}), "moving": character.get("moving", False), "running": character.get("running", False), "selected": baseline.get("selected", 0)})
        result = host.execute(baseline, character=motion, operation=operation, args=args, elapsed=elapsed,
                              shared=shared, player_id=character.get("id", "isolated"), station=station, expected=expected,
                              combat_peers=[{"id":p["id"],"x":p["x"],"y":p["y"],"phase":p.get("gameplay",{}).get("combat_personal",{}).get("phase","alive")}
                                            for p in self.combat_characters if p["id"]!=character["id"] and p["world_id"]==world["id"]], combat_damage=combat_damage)
        if "snapshot" not in result:
            raise RuntimeError(result.get("error", "Invalid gameplay rules response"))
        if not result["ok"]:
            return result
        snapshot = result["snapshot"]
        world["gameplay"] = {key: value for key, value in snapshot.items() if key not in PERSONAL}
        character["gameplay"] = {key: value for key, value in snapshot.items() if key in PERSONAL}
        for key in ("slots", "equipment", "hotbar_equipment"):
            character[key] = copy.deepcopy(snapshot[key])
        character["x"], character["y"] = snapshot["player_position"]["x"], snapshot["player_position"]["y"]
        for kind, identity in migrated:world[kind].pop(identity, None)
        for event in result.get("combat_damage", []):
            target = next((p for p in self.combat_characters if p["id"]==event["target"] and p["world_id"]==world["id"]), None)
            if target is not None:
                received = self.apply(world,target,combat_damage=[event],shared=False)
                if not received.get("ok"):raise RuntimeError("Combat target transaction failed")
        result["snapshot"] = self.snapshot(world,character)
        return result
