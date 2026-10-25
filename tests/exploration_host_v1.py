"""Isolated real rules host: restarts, shared-personal projection and replay."""
import copy
import json
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/network"))
from game_host import GameHost
from gameplay import PERSONAL, validate

OUT = ROOT / "reports/exploration-waits-v2/host"
OUT.mkdir(parents=True, exist_ok=True)
checks = []

def check(ok, name):
    checks.append({"name": name, "pass": bool(ok)})
    assert ok, name

source = json.loads((ROOT / "reports/.tmp/exploration-v1/items-isolated.json").read_text(encoding="utf-8"))
with tempfile.TemporaryDirectory(prefix="private-", dir=OUT) as directory:
    config = {"data_dir": directory, "godot": "D:/Godot/Godot_v4.7.2-stable_win64.exe", "project": str(ROOT)}
    identity = {"id": "chapter-isolated", "seed": 271828, "map_cells": 1024}
    host = GameHost(config, identity)
    try:
        state = host.execute()["snapshot"]
        check(state['exploration_chapter']['stage'] == 0, 'new independent world dormant')
        old = copy.deepcopy(state)
        old.pop('exploration_chapter')
        migrated = host.execute(old)['snapshot']
        check(migrated['exploration_chapter']['stage'] == 0, 'old save optional field migration')
        invalid = copy.deepcopy(state)
        invalid['exploration_chapter']['version'] = 99
        check(not host.execute(invalid)['ok'], 'unknown chapter rejects source snapshot')
        state['exploration_chapter'] = copy.deepcopy(source['exploration_chapter'])
        state['exploration_chapter']['stage'] = 2
        state['combat_personal']['phase'] = 'alive'
        state['combat_world']['boars'] = {}
        site = state['exploration_chapter']['site']
        state['player_position'] = {'x': site['x'], 'y': site['y']+60}
        response = host.execute(state, operation='chapter', args=['remains'])
        check(response['ok'], 'authority accepts in-range investigation')
        state = response['snapshot']
        check(state['exploration_chapter']['stage'] == 3, 'authority advances shared chapter')
        check(any(e['kind'] == 'chapter_page' for e in response['events']), 'reading content travels as confirmed server event')
        check(sum(x.get('count', 0) for x in state['slots'] if x.get('item_id') == 'predecessor_map') == 1, 'one awarded map')
        replay = host.execute(state, operation='chapter', args=['remains'])
        check(replay['ok'] and replay['snapshot']['slots'] == state['slots'], 'replay reads without duplicate inventory')
        personal_b = copy.deepcopy(migrated)
        second = {**copy.deepcopy(state), **{k: copy.deepcopy(v) for k, v in personal_b.items() if k in PERSONAL}}
        second['combat_personal']['phase'] = 'alive'
        second['player_position'] = state['player_position']
        response_b = host.execute(second, operation='chapter', args=['belongings'], player_id='second')
        check(response_b['ok'] and not any(x.get('item_id') == 'predecessor_map' for x in response_b['snapshot']['slots']), 'second player shares progress without second reward')
        check('exploration_chapter' not in PERSONAL, 'chapter belongs to world not character projection')
        far = copy.deepcopy(state)
        far['player_position'] = {'x': 0, 'y': 0}
        check(not host.execute(far, operation='chapter', args=['shore'])['ok'], 'authority rejects distant forged intent')
        check(not host.execute(state, operation='chapter_read', args=['mysterious_bottle'])['ok'], 'unowned bottle cannot be read')
        state['exploration_chapter'].update(stage=4, attempts=2, bottle_claimed=True,dialogue_at=4800.0,fishing_due=6240.0)
        state['slots'][8] = {'item_id': 'mysterious_bottle', 'count': 1}
        read = host.execute(state, operation='chapter_read', args=['mysterious_bottle'])
        check(read['ok'] and read['snapshot']['exploration_chapter']['bottle_read'], 'authority inventory ownership and bottle opening')
        state = read['snapshot']
        repeated = host.execute(state, operation='chapter_read', args=['mysterious_bottle'])
        check(repeated['snapshot']['slots'] == state['slots'], 'opening replay no consumption no reward')
        companion = {**copy.deepcopy(state), **{k: copy.deepcopy(v) for k, v in personal_b.items() if k in PERSONAL}}
        companion['combat_personal']['phase'] = 'alive'
        ready=json.loads((ROOT/'reports/.tmp/exploration-waits-v2/ready.json').read_text(encoding='utf-8'))
        companion['exploration_chapter'].update(elder=ready['exploration_chapter']['elder'],river_fish=ready['exploration_chapter']['river_fish'],elder_spawned=True)
        companion['body_environment']['day']=9
        companion['player_position'] = copy.deepcopy(companion['exploration_chapter']['elder'])
        shared_read = host.execute(companion, operation='chapter', args=['shore'])
        check(shared_read['ok'] and any('废弃矿洞' in event.get('text', '') for event in shared_read['events']), 'companion can reread shared mine clue without taking owner bottle')
        path = OUT/'snapshot.json'
        path.write_text(json.dumps(state), encoding='utf-8')
    finally:
        folder = host.folder
        host.close()
        (OUT/'first-host.log').write_bytes((folder/'host.log').read_bytes())
    host = GameHost(config, identity)
    try:
        restored = host.execute(json.loads(path.read_text()))['snapshot']
        check(restored['exploration_chapter'] == state['exploration_chapter'], 'process restart exact world state')
        check(restored['slots'] == state['slots'], 'process restart exact inventory')
    finally:
        folder = host.folder
        host.close()
        (OUT/'restart-host.log').write_bytes((folder/'host.log').read_bytes())
validate('chapter', ['remains'])
validate('chapter_read', ['mysterious_bottle'])
check(True, 'command schema accepts explicit operations')
(OUT/'checks.json').write_text(json.dumps(checks, indent=2), encoding='utf-8')
print('EXPLORATION HOST', len(checks), 'passed')
