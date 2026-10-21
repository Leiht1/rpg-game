"""Isolated HTTPS latency test. Uses only the existing private test world."""
import importlib.util
import argparse
import json
from pathlib import Path
import ssl
import subprocess
import threading
import time

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument("--delay",type=float,default=.22)
delay=parser.parse_args().delay
SPEC=importlib.util.spec_from_file_location("server",ROOT/"tools/network/server.py")
server=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(server)
private=ROOT/"reports/network-v01/private"
output=ROOT/"reports/network-movement-v4";output.mkdir(exist_ok=True)
config=json.loads((private/"server.json").read_text(encoding="utf-8-sig"))
assert Path(config["data_dir"]).resolve()==(private/"Data").resolve()
service=server.Service(config)
for character in service.state["characters"].values():
    world=service.state["worlds"][character["world_id"]]
    character["x"],character["y"]=world["spawn"]
service.save()
class Delayed(server.Handler):
    def do_POST(self):
        if self.path=="/api/move":time.sleep(delay)
        super().do_POST()
http=server.ThreadingHTTPServer(("127.0.0.1",24871),Delayed)
http.daemon_threads=True;http.service=service
cert,key=server.certificate(service.root)
tls=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);tls.load_cert_chain(cert,key)
http.socket=tls.wrap_socket(http.socket,server_side=True)
thread=threading.Thread(target=http.serve_forever,daemon=True);thread.start()
try:
    client=json.loads((private/"client-config.json").read_text(encoding="utf-8-sig"))
    client["login_cache"]=str(output/"login-test.private.json")
    path=output/"client-test.private.json";path.write_text(json.dumps(client),encoding="utf-8")
    engine=ROOT/"dist/network-v0.1.0/Client/Windrest.exe"
    with (output/"movement.log").open("w",encoding="utf-8") as log:
        result=subprocess.run([str(engine),"--path",str(engine.parent),"--script",str(ROOT/"tests/network_movement_smoke.gd"),"--","--network-config="+str(path),"--fixture="+str(private/"fixture0.json"),"--output="+str(output/"shortcut.png")],stdout=log,stderr=log,timeout=90)
    print((output/"movement.log").read_text(encoding="utf-8"))
    assert result.returncode==0,result.returncode
finally:
    http.shutdown();http.server_close();service.db.close()
