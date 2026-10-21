"""Real HTTPS server plus two independent native Godot windows, isolated data."""
import argparse
import concurrent.futures
import importlib.util
import json
import os
from pathlib import Path
import ssl
import sqlite3
from collections import Counter
import subprocess
import time
import urllib.request

ROOT=Path(__file__).resolve().parents[1]
PRIVATE=ROOT/"reports/network-v01/private"
GODOT=Path("D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
SPEC=importlib.util.spec_from_file_location("windrest_server",ROOT/"tools/network/server.py")
server=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(server)
def totals(state):
    result=Counter()
    def add(slots):
        for slot in slots:
            if slot:result[slot["item_id"]]+=slot["count"]
    for character in state["characters"].values():
        add(character["slots"]);add(character["equipment"].values())
    for world in state["worlds"].values():
        for kind in ("drops","storage"):
            for obj in world[kind].values():add(obj["contents"])
        for obj in world["legacies"].values():add(obj["slots"]);add(obj["equipment"].values())
    return result
def stop(process,packaged):
    if os.name=="nt" and packaged:
        subprocess.run(["taskkill","/PID",str(process.pid),"/T","/F"],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    else:process.terminate()
    process.wait(timeout=10)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--packaged",action="store_true")
    args=parser.parse_args()
    PRIVATE.mkdir(parents=True,exist_ok=True)
    config=json.loads((ROOT/"config/network-server.json").read_text())
    config.update(data_dir=str(PRIVATE/"Data"),godot=str(GODOT),project=str(ROOT),world_cells=128,port=24871)
    pack=ROOT/"dist/network-v0.1.0"
    if args.packaged:
        config.update(godot=str(pack/"Server/WorldWorker.exe"),project=str(pack/"Server"))
    (PRIVATE/"server.json").write_text(json.dumps(config),encoding="utf-8")
    service=server.Service(config)
    if not service.state["accounts"]:
        keys=json.loads(service.initialize().read_text())
        clients=[]
        for i in range(2):
            username="native"+str(i+1);password=server.secrets.token_urlsafe(20)
            r=service.handle("activate",{"protocol":1,"version":"0.1.0",**keys[i],"username":username,"password":password})
            token=r["token"]
            service.handle("nickname",{"protocol":1,"version":"0.1.0","nickname":"联机测试"+str(i+1)},token)
            clients.append({"username":username,"password":password,"chat":"你好来自客户端"+str(i+1),"output":str(ROOT/"reports/network-v01"/("client"+str(i+1)))})
        (PRIVATE/"clients.json").write_text(json.dumps(clients,ensure_ascii=False),encoding="utf-8")
        w=service.handle("create_world",{"protocol":1,"version":"0.1.0","name":"原生双客户端测试"},service.sessions.keys().__iter__().__next__())["world"]
        token2=list(service.sessions)[1]
        service.handle("join_world",{"protocol":1,"version":"0.1.0","world_id":w["id"]},token2)
        for token in list(service.sessions):
            service.handle("character",{"protocol":1,"version":"0.1.0","appearance":{"gender":"male","hair_id":"male_natural","skin_id":"skin_2"}},token)
    clients=json.loads((PRIVATE/"clients.json").read_text(encoding="utf-8"))
    for w in service.state["worlds"].values():
        x,y=w["spawn"]
        w["drops"]["race-drop"]={"x":x,"y":y+10,"contents":[{"item_id":"wood","count":1}]}
        w["storage"]["race-box"]={"x":x+25,"y":y+10,"contents":[{"item_id":"stone","count":1}]+[{} for _ in range(8)]}
    for c in service.state["characters"].values():
        w=service.state["worlds"][c["world_id"]]
        c["x"],c["y"]=w["spawn"]
    # One existing character and one first-entry UI path, never player data.
    second=service.state["accounts"]["TEST-002"]["player_id"]
    service.state["characters"].pop(second,None)
    service.save()
    before=totals(service.state)
    cert,key=server.certificate(service.root)
    service.db.close()
    client_config=json.loads((ROOT/"config/network-client.json").read_text())
    client_config.update(server_url="https://localhost:24871",certificate=str(cert),profile_cache=str(PRIVATE/"display-profile.json"))
    (PRIVATE/"client-config.json").write_text(json.dumps(client_config),encoding="utf-8")
    log=(ROOT/"reports/network-v01/server.log").open("w")
    server_command=[str(pack/"Server/WindrestServer.exe")] if args.packaged else ["python",str(ROOT/"tools/network/server.py")]
    process=subprocess.Popen(server_command+["--config",str(PRIVATE/"server.json")],stdout=log,stderr=log)
    children=[]
    try:
        time.sleep(2)
        if process.poll() is not None:raise RuntimeError("HTTPS server exited before readiness")
        import socket
        context=ssl.create_default_context(cafile=str(cert))
        with socket.create_connection(("127.0.0.1",24871),timeout=5) as raw:
            with context.wrap_socket(raw,server_hostname="windrest-server") as connection:
                print("TLS_READY",connection.version())
        for i,fixture in enumerate(clients):
            path=PRIVATE/("fixture"+str(i)+".json");path.write_text(json.dumps(fixture,ensure_ascii=False),encoding="utf-8")
            output=(ROOT/"reports/network-v01"/("client"+str(i+1)+".log")).open("w",encoding="utf-8")
            engine=pack/"Client/Windrest.exe" if args.packaged else GODOT
            project=pack/"Client" if args.packaged else ROOT
            child=subprocess.Popen([str(engine),"--path",str(project),"--position",f"{40+i*80},{40+i*50}","--script",str(ROOT/"tests/network_native_smoke.gd"),"--","--network-config="+str(PRIVATE/"client-config.json"),"--fixture="+str(path)],stdout=output,stderr=output)
            children.append((child,output))
        results=[]
        for child,output in children:
            try:results.append(child.wait(timeout=100))
            except subprocess.TimeoutExpired:child.terminate();results.append(124)
            output.close()
        print("NATIVE_CLIENT_EXIT_CODES",results)
        if any(results):raise SystemExit(1)
        with sqlite3.connect(service.root/"state.sqlite3") as saved:
            persisted=json.loads(saved.execute("SELECT payload FROM state WHERE id=1").fetchone()[0])
            after=totals(persisted)
        for item in ("wood","stone"):
            if before[item]!=after[item]:raise AssertionError("shared inventory conservation failed: "+item)
        print("SHARED_ITEM_CONSERVATION PASS")
        stop(process,args.packaged)
        process=subprocess.Popen(server_command+["--config",str(PRIVATE/"server.json")],stdout=log,stderr=log)
        time.sleep(2)
        fixture=clients[0].copy()
        account=persisted["accounts"]["TEST-001"]
        fixture.update(expected_character=persisted["characters"][account["player_id"]],expected_world=persisted["worlds"][account["world_id"]])
        restart_fixture=PRIVATE/"restart-fixture.json";restart_fixture.write_text(json.dumps(fixture,ensure_ascii=False),encoding="utf-8")
        output=(ROOT/"reports/network-v01/restart.log").open("w",encoding="utf-8")
        try:
            result=subprocess.run([str(engine),"--headless","--path",str(project),"--script",str(ROOT/"tests/network_reconnect_smoke.gd"),"--","--network-config="+str(PRIVATE/"client-config.json"),"--fixture="+str(restart_fixture)],stdout=output,stderr=output,timeout=30)
            print("SERVER_RESTART_CLIENT_EXIT_CODE",result.returncode)
            if result.returncode:raise SystemExit(1)
        finally:output.close()
    finally:
        for child,output in children:
            if child.poll() is None:child.terminate()
            output.close()
        stop(process,args.packaged);log.close()

if __name__=="__main__":main()
