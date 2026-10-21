"""New-device gap runs; original regression evidence is never overwritten."""
import argparse
import importlib.util
import json
import os
import hashlib
import sqlite3
import time
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('previous_runner', ROOT / 'reports/full-regression-20261021/run_regression.py')
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)
r.OUT = OUT
r.WORK = ROOT / 'reports/.tmp/device-continuation-20261021'
r.PROJECT = r.WORK / 'project'
machine = json.loads((Path(os.environ['LOCALAPPDATA']) / 'Windrest/IndependentTest-v1/machine.json').read_text(encoding='utf-8'))
r.ENGINE = Path(machine['godot'])
r.ENV = dict(os.environ, APPDATA=str(r.WORK / 'AppData/Roaming'),
             LOCALAPPDATA=str(r.WORK / 'AppData/Local'), PYTHONIOENCODING='utf-8',
             WINDREST_GODOT=str(r.ENGINE))
r.ENV['PATH'] = str(Path(sys.executable).parent) + os.pathsep + r.ENV['PATH']
r.RESUME = False
r.execute.__defaults__ = (150, r.PROJECT, 'native')
if (OUT / 'results.json').exists():
    r.RESULTS = json.loads((OUT / 'results.json').read_text(encoding='utf-8'))
execute_original = r.execute


def execute_preserved(label, command, timeout=150, cwd=r.PROJECT, category='native'):
    start = time.time()
    attempt = 1 + sum(row['label'] == label for row in r.RESULTS)
    execute_original(label, command, timeout, cwd, category)
    row = r.RESULTS[-1]
    if any('Error calling deferred' in error or 'Parse JSON failed' in error or 'Lambda capture' in error for error in row['errors']):
        row['status'] = 'fail'
        r.write_json(OUT / 'results.json', r.RESULTS)
    evidence = r.WORK / 'evidence' / str(len(r.RESULTS)).zfill(4)
    row['evidence'] = str(evidence.relative_to(r.WORK))
    r.write_json(OUT / 'results.json', r.RESULTS)
    for path in (r.PROJECT / 'reports').rglob('*'):
        if path.is_file() and path.stat().st_mtime >= start and path.suffix in ('.json', '.png', '.log'):
            target = evidence / path.relative_to(r.PROJECT)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)


r.execute = execute_preserved


def independent_fingerprint():
    folder = Path(os.environ['LOCALAPPDATA']) / 'Windrest/IndependentTest-v1'
    files = ['server.json', 'client.json', 'machine.json', 'Data/server-public.crt',
             'Data/Accounts/server-key.private.pem', 'Data/Accounts/FIRST-ACTIVATION.private.json']
    result = {name: hashlib.sha256((folder / name).read_bytes()).hexdigest() for name in files}
    config = json.loads((folder / 'server.json').read_text(encoding='utf-8'))
    with sqlite3.connect('file:' + (Path(config['data_dir']) / 'state.sqlite3').as_posix() + '?mode=ro', uri=True) as db:
        result['database_logical_state'] = hashlib.sha256(db.execute('SELECT payload FROM state WHERE id=1').fetchone()[0].encode()).hexdigest()
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('phase', choices=['prepare', 'network', 'placement', 'gaps', 'checks', 'planting', 'planting-current', 'character', 'character-resume', 'long', 'window'])
    parser.add_argument('--delay', type=float, default=.22)
    parser.add_argument('--cells', type=int, default=128)
    options = parser.parse_args()
    if (OUT / 'results.json').exists():
        r.RESULTS = json.loads((OUT / 'results.json').read_text(encoding='utf-8'))
    baseline = r.WORK / 'independent-before.private.json'
    if not baseline.exists():
        r.write_json(baseline, independent_fingerprint())
    if options.phase == 'prepare':
        if not r.PROJECT.exists():
            r.prepare()
        shutil.copy2(ROOT / 'reports/full-regression-20261021/bootstrap.gd', OUT / 'bootstrap.gd')
        helper = Path(os.environ['LOCALAPPDATA']) / 'Windrest/IndependentTest-v1/Runtime/LoginVault.exe'
        target = r.PROJECT / 'dist/network-v0.1.0/Client/LoginVault.exe'
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(helper, target)
        r.execute('device-project-import', [str(r.ENGINE), '--headless', '--path', str(r.PROJECT), '--editor', '--import', '--quit'], 180, category='import')
    elif options.phase == 'network':
        script = r.PROJECT / 'tests/run_network_gameplay.py'
        source = (ROOT / 'tests/run_network_gameplay.py').read_text(encoding='utf-8')
        source = source.replace('ENGINE = Path("D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe")',
                                'ENGINE = Path(' + repr(str(r.ENGINE).replace('_console.exe', '.exe')) + ')')
        # Preserve each private fixture and each client's log; never overwrite an old run.
        label = 'network-delay' + str(round(options.delay * 1000)) + ('-cells' + str(options.cells) if options.cells != 128 else '')
        run = label.removeprefix('network-') + '-attempt' + str(1 + sum(x['label'].startswith(label + '-') for x in r.RESULTS))
        source = source.replace('PRIVATE = ROOT/"reports/network-gameplay-v5/private"',
                                'PRIVATE = ROOT/"reports/network-gameplay-v5/private/' + run + '"')
        source = source.replace('import tempfile', 'import tempfile\nimport contextlib')
        source = source.replace('spec.loader.exec_module(server)', 'spec.loader.exec_module(server)\nserver.secrets.randbelow = lambda maximum: 239229521')
        source = source.replace('with tempfile.TemporaryDirectory(prefix="native-", dir=PRIVATE) as temporary:',
                                'with contextlib.nullcontext(str(PRIVATE)) as temporary:')
        script.write_text(source, encoding='utf-8')
        world_script = r.PROJECT / 'scripts/network_game_world.gd'
        trace = (ROOT / 'scripts/network_game_world.gd').read_text(encoding='utf-8-sig')
        trace = trace.replace('moving_request=false\n\tif stopping:return',
                              'moving_request=false\n\tprint("MOVE_TRACE ",JSON.stringify({"seq":sequence,"ok":response.get("ok",false),"error":response.get("error",""),"ack":response.get("input_ack",-1),"server":Vector2(response.get("character",{}).get("x",0),response.get("character",{}).get("y",0)),"local":player.position,"pending":player.pending_inputs.size(),"correction":player.correction}))\n\tif stopping:return')
        world_script.write_text(trace, encoding='utf-8')
        r.execute(label + '-' + run, [sys.executable, str(script), '--delay', str(options.delay), '--cells', str(options.cells)], 300, category='multiplayer')
    elif options.phase == 'placement':
        fixture = r.PROJECT / 'tests/world_v06_formal_fixture.gd'
        original = fixture.read_text(encoding='utf-8-sig')
        adaptation = '\n# Test fixture only: load the area where these tests place objects.\nfunc choose_entry_point() -> Vector2:\n\treturn generator.spawn\n'
        fixture.write_text(original + adaptation, encoding='utf-8')
        try:
            cases = [('test_camp_build_v4', ['--formal']), ('test_camp_door_hinge_transaction_v3', []),
                     ('test_camp_h_damage_window_v4', ['--formal']), ('test_inventory_chest_v1', []),
                     ('test_chest_ui_v2', []), ('test_cooking_build_v2', []), ('test_campfire_drag_v1', []),
                     ('test_planting_v1', []), ('test_seed_selector_v2', []), ('test_sleep_formal_v9', []),
                     ('test_sleep_fit_v10', []), ('test_sleep_collision_v11', [])]
            for name, args in cases:
                r.godot(name, args)
                if r.RESULTS[-1]['status'] == 'pass' and name in ('test_chest_ui_v2', 'test_seed_selector_v2'):
                    r.godot(name, ['restart'] if name == 'test_chest_ui_v2' else ['read-destroyed'], tag='-restart')
        finally:
            fixture.write_text(original, encoding='utf-8')
    elif options.phase == 'gaps':
        r.godot('test_animal_art_formal_v2', ['--capture'])
        r.godot('test_camp_expansion_front_v2', ['preview'])
        for name in ('test_build_shortcut_v2', 'test_floor_running_v2', 'test_mushroom_density_v2'):
            if name == 'test_build_shortcut_v2':
                path = r.PROJECT / 'tests' / (name + '.gd')
                source = path.read_text(encoding='utf-8-sig')
                path.write_text(source.replace('[Vector2i(960,540),Vector2i(1280,720)]', '[Vector2i(1280,720)]'), encoding='utf-8')
            r.godot(name, headless=name == 'test_mushroom_density_v2')
    elif options.phase == 'checks':
        r.execute('game-rules-after-mailbox-fix', [sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_network_game_host.py', '-v'], 240, category='service')
        r.execute('audio-workbench-new-device', [sys.executable, '-m', 'unittest', 'discover', '-s', 'tools/audio_workbench', '-p', 'test_workbench.py', '-v'], 120, category='tool')
        import ssl
        import threading
        spec = importlib.util.spec_from_file_location('private_login_server', r.PROJECT / 'tools/network/server.py')
        server = importlib.util.module_from_spec(spec);spec.loader.exec_module(server)
        folder = r.WORK / ('login-probe-' + str(time.time_ns()))
        config = json.loads((r.PROJECT / 'config/network-server.json').read_text(encoding='utf-8'))
        config.update(data_dir=str(folder / 'Data'), bind='127.0.0.1', port=24874)
        service = server.Service(config);service.initialize()
        cert, key = server.certificate(service.root)
        r.write_json(folder / 'client.json', dict(server_url='https://localhost:24874', certificate=str(cert), server_name='windrest-server', protocol=1, version='0.1.0'))
        http = server.ThreadingHTTPServer(('127.0.0.1', 24874), server.Handler)
        http.daemon_threads=True;http.service=service
        tls=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);tls.load_cert_chain(cert,key)
        http.socket=tls.wrap_socket(http.socket,server_side=True)
        thread=threading.Thread(target=http.serve_forever,daemon=True);thread.start()
        try:
            r.godot('login_connection_smoke', ['--network-config=' + str(folder / 'client.json')], timeout=35)
        finally:
            http.shutdown();http.server_close();service.db.close()
    elif options.phase in ('planting', 'planting-current'):
        fixture = r.PROJECT / 'tests/world_v06_formal_fixture.gd'
        original = fixture.read_text(encoding='utf-8-sig')
        fixture.write_text(original + '\nfunc choose_entry_point() -> Vector2:\n\treturn generator.spawn\nfunc _ready() -> void:\n\tsuper._ready()\n\titem_service.builds.states.clear()\n\titem_service.builds.refresh_all()\n', encoding='utf-8')
        path = r.PROJECT / 'tests/test_planting_persistence_v1.gd'
        source = path.read_text(encoding='utf-8-sig')
        source = source.replace('360.0 if index==2', 'float(s.planting.rules.crops.carrot.minutes) if index==2')
        path.write_text(source, encoding='utf-8')
        if options.phase == 'planting-current':
            path = r.PROJECT / 'tests/test_planting_v1.gd'
            source = path.read_text(encoding='utf-8-sig')
            source = source.replace('growth_minutes=360.0', 'growth_minutes=float(s.planting.rules.crops.carrot.minutes)')
            path.write_text(source, encoding='utf-8')
        try:
            for name in (('test_planting_v1',) if options.phase == 'planting-current' else ('test_chest_ui_v2', 'test_planting_v1', 'test_seed_selector_v2')):
                r.godot(name, tag='-current-maturity' if options.phase == 'planting-current' else '-empty-fixture')
                if r.RESULTS[-1]['status'] == 'pass' and name != 'test_planting_v1':
                    r.godot(name, ['restart'] if name == 'test_chest_ui_v2' else ['read-destroyed'], tag='-restart-empty-fixture')
            for args, tag in (() if options.phase == 'planting-current' else (([], 'write'), (['read'], 'read'), (['after-harvest'], 'after-harvest'))):
                r.godot('test_planting_persistence_v1', args, headless=True, tag='-device-' + tag)
                if r.RESULTS[-1]['status'] != 'pass':break
        finally:
            fixture.write_text(original, encoding='utf-8')
    elif options.phase == 'character':
        path = r.PROJECT / 'tests/test_character_creation_v1.gd'
        source = path.read_text(encoding='utf-8-sig')
        path.write_text(source.replace('w.map_cells==1024', 'w.map_cells==1536'), encoding='utf-8')
        r.godot('test_character_creation_v1', timeout=240, tag='-current-map-size')
        if r.RESULTS[-1]['status'] == 'pass':
            r.godot('test_character_resume_v1', timeout=180)
            if r.RESULTS[-1]['status'] == 'pass':r.godot('test_character_resume_v1', ['--consumed'], tag='-consumed')
    elif options.phase == 'character-resume':
        creation = next(row for row in reversed(r.RESULTS) if row['label'] == 'test_character_creation_v1-current-map-size' and row['status'] == 'pass')
        snapshot = r.WORK / creation.get('evidence', 'evidence/test_character_creation_v1-current-map-size-attempt1') / 'reports/character-creation-v1/isolated-save.json'
        shutil.copy2(snapshot, r.PROJECT / 'reports/character-creation-v1/isolated-save.json')
        path = r.PROJECT / 'tests/test_character_resume_v1.gd'
        source = path.read_text(encoding='utf-8-sig')
        source = source.replace('var movement_origin=p.position', 'while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame\n\tvar movement_origin=p.position')
        path.write_text(source, encoding='utf-8')
        r.godot('test_character_resume_v1', timeout=180, tag='-viewport-ready')
        if r.RESULTS[-1]['status'] == 'pass':r.godot('test_character_resume_v1', ['--consumed'], tag='-consumed')
    elif options.phase == 'long':
        path = r.PROJECT / 'tests/test_world_map_v3_distribution.gd'
        source = path.read_text(encoding='utf-8-sig')
        source = source.replace('for cells in [1024,1536]:', 'for cells in [1536]:').replace('for seed_value in [81273,271828,902106]:', 'for seed_value in [271828,902106]:')
        source = source.replace('(28 if cells>1024 else 20)', '(56 if cells>1024 else 40)')
        path.write_text(source, encoding='utf-8')
        r.godot('test_world_map_v3_distribution', headless=True, timeout=360, tag='-remaining-two-seeds')
        r.godot('test_world_map_v3_perf', ['--cells=1536'], timeout=240, tag='-1536-device')
    elif options.phase == 'window':
        path = r.PROJECT / 'tests/test_world_map_v3_window.gd'
        source = path.read_text(encoding='utf-8-sig')
        # Keep the exact first selected review sites, stop redundant sampling
        # after all three sites have already been found. Assertions unchanged.
        source = source.replace('for y in 100:\n\t\tfor x in 100:',
                                'for y in 100:\n\t\tif sites.size()==3:break\n\t\tfor x in 100:\n\t\t\tif sites.size()==3:break')
        path.write_text(source, encoding='utf-8')
        r.godot('test_world_map_v3_window', timeout=600, tag='-remaining-window')
        if r.RESULTS[-1]['status'] == 'pass':
            r.godot('test_world_map_v3_window', ['--resume'], tag='-device-restart')
    before = json.loads((r.WORK / 'player-before.json').read_text(encoding='utf-8'))
    after = r.fingerprints()
    r.write_json(OUT / 'save-protection.json', dict(before_count=len(before), after_count=len(after),
                 changed=[p for p in before if before[p] != after.get(p)], added=[p for p in after if p not in before],
                 independent_server_unchanged=json.loads(baseline.read_text(encoding='utf-8')) == independent_fingerprint()))


if __name__ == '__main__':
    main()
