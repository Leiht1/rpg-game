"""Two real clients against a private full-game HTTPS server; no player saves."""
import argparse
import importlib.util
import json
import re
import statistics
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile
import time
import socket

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path("D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe")
PRIVATE = ROOT/"reports/network-performance-v7/private"
spec = importlib.util.spec_from_file_location("gameplay_native_server", ROOT/"tools/network/server.py")
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


def main():
    parser=argparse.ArgumentParser();parser.add_argument("--delay",type=float,default=0);parser.add_argument("--runtime",type=Path);parser.add_argument("--cells",type=int,default=1536);parser.add_argument("--players",type=int,default=4)
    options=parser.parse_args()
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
        for i in range(options.players):
            password = secrets.token_urlsafe(20)
            data = {"protocol": 1, "version": "0.1.0", **keys[i], "username": "formal"+str(i), "password": password}
            response = service.handle("activate", data)
            token = response["token"]; tokens.append(token)
            service.handle("nickname", {"protocol": 1, "version": "0.1.0", "nickname": "Formal"+str(i)}, token)
            fixtures.append({"username": data["username"], "password": password, "index": i, "players":options.players})
        world = service.handle("create_world", {"protocol": 1, "version": "0.1.0", "name": "PrivateFullGame"}, tokens[0])["world"]
        for token in tokens[1:]:service.handle("join_world", {"protocol": 1, "version": "0.1.0", "world_id": world["id"]}, token)
        for token in tokens:
            result = service.handle("character", {"protocol": 1, "version": "0.1.0", "gameplay_revision":1,"appearance": {"gender": "male", "hair_id": "male_natural", "skin_id": "skin_2"}}, token)
            character = service.character(service.state["accounts"][service.sessions[token]["account"]])
            for index, item in enumerate(("branch", "flint", "plant_fiber", "wood", "stone", "wild_berry")):
                character["slots"][index+8] = {"item_id": item, "count": 20}
        for label in ('sync-first','sync-second'):
            world['drops'][label]={'x':world['spawn'][0]+12,'y':world['spawn'][1], 'contents':[{'item_id':'wood','count':2}]}
        service.save()
        cert, unused = server.certificate(service.root)
        service.db.close()
        (folder/"server.json").write_text(json.dumps(config), encoding="utf-8")
        client_config = {"server_url": "https://localhost:24872", "certificate": str(cert), "server_name": "windrest-server", "protocol": 1, "version": "0.1.0"}
        (folder/"client.json").write_text(json.dumps(client_config), encoding="utf-8")
        children = []
        with (PRIVATE/"server.log").open("w", encoding="utf-8") as log:
            server_command=[str(options.runtime.resolve()/"Server/WindrestServer.exe"),"--config",str(folder/"server.json")] if options.runtime else ["python", str(ROOT/"tests/network_gameplay_delay_server.py"), "--delay", str(options.delay), "--delay-scope", "gameplay", "--config", str(folder/"server.json")]
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
                    child = subprocess.Popen([str(engine), "--path", str(engine.parent if options.runtime else ROOT), "--script", str(ROOT/"tests/network_performance_v7.gd"), "--", "--network-config="+str(folder/"client.json"), "--fixture="+str(fixture_path)], stdout=output, stderr=output)
                    children.append((child, output))
                codes = [child.wait(timeout=140) for child, output in children]
                print("FULL_GAME_NATIVE_EXIT_CODES", codes)
                for child, output in children:output.flush()
                metrics=[(PRIVATE/("client"+str(i)+".log")).read_text(encoding="utf-8") for i in range(options.players)]
                records=[]
                for i,value in enumerate(metrics):
                    performance=re.search(r"PERFORMANCE .*",value)
                    requests={}
                    for operation,summary in re.findall(r"API_SUMMARY (\w+) (\{.*\})",value):
                        requests[operation]=json.loads(summary)
                    for operation in ["move","game_snapshot","poll"]:
                        times=sorted(map(int,re.findall(r"API_MS "+operation+r" (\d+) status=200",value)))
                        if times:requests[operation]={"samples":len(times),"median_ms":statistics.median(times),"p95_ms":times[int((len(times)-1)*.95)],"max_ms":max(times)}
                    remote=re.search(r"REMOTE_CHECK .*",value)
                    attack=re.search(r"ATTACK_RESPONSE_MS (\[.*\])",value)
                    records.append({"client":i,"exit_code":codes[i],"performance":performance.group() if performance else None,"remote":remote.group() if remote else None,"attack_response_ms":json.loads(attack.group(1)) if attack else [],"requests":requests})
                label=("packed" if options.runtime else "source")+"-"+str(options.players)+"-player.json"
                (PRIVATE.parent/label).write_text(json.dumps(records,indent=2),encoding="utf-8")
                if any(codes) or any("PERFORMANCE players=" not in value for value in metrics):raise SystemExit(1)
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
