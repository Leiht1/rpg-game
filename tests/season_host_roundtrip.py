"""Actual isolated Godot rule-host restarts; no deployed service or player data."""
from pathlib import Path
import copy
import json
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/network"))
from game_host import GameHost

OUT = ROOT / "reports/seasons-v1/host"
OUT.mkdir(parents=True, exist_ok=True)
checks = []

def check(value, name):
    checks.append({"name": name, "pass": bool(value)})
    assert value, name

with tempfile.TemporaryDirectory(prefix="private-", dir=OUT) as temporary:
    config = {"data_dir": temporary, "godot": "D:/Godot/Godot_v4.7.2-stable_win64.exe", "project": str(ROOT)}
    world = {"id": "season-restart-fixture", "seed": 271828, "map_cells": 128}
    host = GameHost(config, world)
    try:
        state = host.execute()["snapshot"]
        env = state["body_environment"]
        env.update(day=350, minute=1439.5, weather_remaining=9000)
        env.pop("season")
        original_body = copy.deepcopy(state["body"])
        migrated = host.execute(state)["snapshot"]
        check(migrated["body_environment"]["day"] == 350 and migrated["body_environment"]["minute"] == 1439.5, "old world retains exact date and time")
        check(migrated["body_environment"]["season"] == {"version": 1, "origin_day": 350}, "old world anchored once at spring day one")
        check(migrated["body"] == original_body, "migration does not alter personal survival")
        migrated["body_environment"].update(day=356, minute=1439.5)
        first = host.execute(migrated, elapsed=2, shared=True)["snapshot"]
        check(first["body_environment"]["day"] == 357 and abs(first["body_environment"]["minute"] - .3) < 1e-7, "shared authority crosses into summer")
        second = host.execute(first, elapsed=2, shared=False)["snapshot"]
        check(second["body_environment"] == first["body_environment"], "second player never advances shared clock")
        second["body_environment"]["paused"] = True
        paused = host.execute(second, elapsed=5)["snapshot"]
        check(paused["body_environment"] == second["body_environment"], "paused host keeps calendar frozen")
        check(all(paused["body"][key] == second["body"][key] for key in ("health", "hunger", "energy", "weather_body")), "paused health hunger energy and weather remain unchanged")
        paused["body_environment"]["paused"] = False
        path = OUT / "isolated-snapshot.json"
        path.write_text(json.dumps(paused), encoding="utf-8")
    finally:
        folder = host.folder
        host.close()
        (OUT / "first-host.log").write_bytes((folder / "host.log").read_bytes())
    time.sleep(.3)
    restored = json.loads(path.read_text(encoding="utf-8"))
    host = GameHost(config, world)
    try:
        after = host.execute(restored)["snapshot"]
        check(after["body_environment"] == restored["body_environment"], "new host reload has no offline catchup or repeated seasonal switch")
        check(after["body"] == restored["body"], "new host preserves survival state")
        check(after["buildings"] == restored["buildings"], "new host preserves planting and facilities")
        resumed = host.execute(after, elapsed=1)["snapshot"]
        check(resumed["body_environment"]["day"] == 357 and abs(resumed["body_environment"]["minute"] - .7) < 1e-7, "resumed authority continues exactly once")
    finally:
        folder = host.folder
        host.close()
        (OUT / "second-host.log").write_bytes((folder / "host.log").read_bytes())
(OUT / "checks.json").write_text(json.dumps(checks, indent=2), encoding="utf-8")
print("SEASON HOST RESTART", len(checks), "passed")
