"""Two real clients against a private full-game HTTPS server; no player saves."""
import argparse
import importlib.util
import json
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile
import time
import socket
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools/network"))
ENGINE = Path("D:/Godot/Godot_v4.7.2-stable_win64.exe")
PRIVATE = ROOT/"reports/mine-collision-clues-v4/network/private"
spec = importlib.util.spec_from_file_location("gameplay_native_server", ROOT/"tools/network/server.py")
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


def main():
    parser=argparse.ArgumentParser();parser.add_argument("--lake",action="store_true");parser.add_argument("--delay",type=float,default=0);parser.add_argument("--runtime",type=Path);parser.add_argument("--cells",type=int,default=1024)
    options=parser.parse_args()
    global PRIVATE
    if options.lake:PRIVATE=ROOT/"reports/exploration-waits-v2/network-lake/private"
    PRIVATE.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="native-", dir=PRIVATE) as temporary:
        folder = Path(temporary)
        config = json.loads((ROOT/"config/network-server.json").read_text())
        config.update(data_dir=str(folder/"Data"), godot=str(ENGINE), project=str(ROOT),
                      world_cells=options.cells, port=24872, bind="127.0.0.1", gameplay_preview=True)
        engine=options.runtime.resolve()/"Client/Windrest.exe" if options.runtime else ENGINE
        if options.runtime:config.update(godot=str(options.runtime.resolve()/"Server/WorldWorker.exe"),project=str(options.runtime.resolve()/"Server"))
        service = server.Service(config)
        keys = json.loads(service.initialize().read_text())
        service.terrain_factory=lambda world: (world.update(seed=271828) or service.make_terrain(world))
        fixtures = []
        tokens = []
        for i in range(2):
            password = secrets.token_urlsafe(20)
            data = {"protocol": 1, "version": "0.1.0", **keys[i], "username": "formal"+str(i), "password": password}
            response = service.handle("activate", data)
            token = response["token"]; tokens.append(token)
            service.handle("nickname", {"protocol": 1, "version": "0.1.0", "nickname": "Formal"+str(i)}, token)
            fixtures.append({"username": data["username"], "password": password, "index": i})
        world = service.handle("create_world", {"protocol": 1, "version": "0.1.0", "name": "PrivateFullGame"}, tokens[0])["world"]
        service.handle("join_world", {"protocol": 1, "version": "0.1.0", "world_id": world["id"]}, tokens[1])
        for token in tokens:
            result = service.handle("character", {"protocol": 1, "version": "0.1.0", "gameplay_revision":1,"appearance": {"gender": "male", "hair_id": "male_natural", "skin_id": "skin_2"}}, token)
            character = service.character(service.state["accounts"][service.sessions[token]["account"]])
            for index, item in enumerate(("branch", "flint", "plant_fiber", "wood", "stone", "wild_berry")):
                character["slots"][index+8] = {"item_id": item, "count": 20}
        service.handle('game_snapshot', {'protocol':1,'version':'0.1.0'}, tokens[0])
        world = service.state['worlds'][world['id']]
        actual_spawn = world['gameplay']['combat_world']['spawn']
        for token in tokens:
            service.handle('game_snapshot', {'protocol':1,'version':'0.1.0'}, token)
        saved=json.loads((ROOT/'reports/.tmp/mine-ready.json').read_text(encoding='utf-8'))
        chapter=saved['exploration_chapter']
        chapter['mine'].update(phase='open',recipe=True,investigated=True,fuse_due=0,opened_at=0,entered=True,fuse_remaining_seconds=0)
        chapter['mine'].pop('puzzle',None)
        world['gameplay']['exploration_chapter']=chapter
        world['gameplay']['body_environment']=saved['body_environment']
        world['gameplay']['combat_world']['boars']={}
        for index,token in enumerate(tokens):
            c=service.character(service.state['accounts'][service.sessions[token]['account']])
            cfg=json.loads((ROOT/'data/mine_puzzle.json').read_text(encoding='utf-8'));point={'x':saved['player_position']['x']+cfg['lamps'][0][0],'y':4096+cfg['lamps'][0][1]}
            c['x']=point['x']+index*12;c['y']=point['y']+55
            for i in range(40):c['slots'][i]={}
            c['slots'][8]={'item_id':'miner_blast_pack','count':1}
            c['gameplay']['slots']=c['slots']
            c['gameplay']['mine_travel']={'inside':True,'serial':1}
            c['gameplay']['player_position']={'x':c['x'],'y':c['y']}
            c['gameplay']['combat_personal'].update(phase='alive',clock=0)
            c['gameplay']['body'].update(health=100,energy=100,hunger=100)
        service.save()
        cert, unused = server.certificate(service.root)
        service.gameplay.close()
        service.db.close()
        (folder/"server.json").write_text(json.dumps(config), encoding="utf-8")
        client_config = {"server_url": "https://localhost:24872", "certificate": str(cert), "server_name": "windrest-server", "protocol": 1, "version": "0.1.0"}
        (folder/"client.json").write_text(json.dumps(client_config), encoding="utf-8")
        children = []
        with (PRIVATE/"server.log").open("w", encoding="utf-8") as log:
            server_command=[str(options.runtime.resolve()/"Server/WindrestServer.exe"),"--config",str(folder/"server.json")] if options.runtime else [sys.executable, str(ROOT/"tests/network_gameplay_delay_server.py"), "--delay", str(options.delay), "--config", str(folder/"server.json")]
            process = subprocess.Popen(server_command, stdout=log, stderr=log)
            try:
                deadline=time.monotonic()+30
                while True:
                    try:
                        with socket.create_connection(("127.0.0.1",24872),timeout=.5):pass
                        break
                    except OSError:
                        if process.poll() is not None or time.monotonic()>deadline:raise RuntimeError("Private test server did not start listening")
                        time.sleep(.2)
                for i, fixture in enumerate(fixtures):
                    fixture_path = folder/(str(i)+".json")
                    fixture_path.write_text(json.dumps(fixture), encoding="utf-8")
                    output = (PRIVATE/("client"+str(i)+".log")).open("w", encoding="utf-8")
                    child = subprocess.Popen([str(engine), "--path", str(engine.parent if options.runtime else ROOT), "--script", str(ROOT/("tests/exploration_network_lake_v1.gd" if options.lake else "tests/mine_rules_network_v4.gd")), "--", "--network-config="+str(folder/"client.json"), "--fixture="+str(fixture_path)], stdout=output, stderr=output)
                    children.append((child, output))
                codes = [child.wait(timeout=140) for child, output in children]
                print("FULL_GAME_NATIVE_EXIT_CODES", codes)
                if any(codes):raise SystemExit(1)
                for i in range(2):
                    if "MINE SCENE NETWORK" not in (PRIVATE/("client"+str(i)+".log")).read_text(encoding="utf-8"):raise RuntimeError("Client exited without completing checks")
                evidence=ROOT/'reports/mine-collision-clues-v4/network'
                results=[json.loads((evidence/('client'+str(i)+'.json')).read_text(encoding='utf-8')) for i in range(2)]
                assert all(r['solved'] for r in results), 'shared solve on both clients'
                assert all(r['inside'] for r in results), 'both clients remain in original mine region'
                print('MINE SCENE GLOBAL: shared lamps, simultaneous solve, new art, reconnect preserved')
            finally:
                for child, output in children:
                    if child.poll() is None:child.terminate();child.wait(timeout=10)
                    output.close()
                for index,host_log in enumerate((folder/"Data/Runtime").glob("*/host.log")):
                    shutil.copy2(host_log,PRIVATE/("host"+str(index)+".log"))
                process.terminate()
                process.wait(timeout=10)
                # The private service may have a running Godot child. Only stop
                # processes whose command line contains this exact test folder.
                subprocess.run(["powershell", "-NoProfile", "-Command", "$prefix='"+str(folder).replace("'", "''")+"'; Get-CimInstance Win32_Process | Where-Object { $_.Name -in @('Godot_v4.7.2-stable_win64.exe','WorldWorker.exe','WindrestServer.exe') -and $_.CommandLine -like ('*'+$prefix+'*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }; Start-Sleep -Milliseconds 500"], check=True)


if __name__ == "__main__":main()
