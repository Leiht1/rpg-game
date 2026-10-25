"""Create self-contained Windows runtime packs without requiring editor installs."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import ssl
import zipfile

ROOT=Path(__file__).resolve().parents[2]

def apply_client_icon(executable):
    from PyInstaller.utils.win32.icon import CopyIcons_FromIco, win32api
    CopyIcons_FromIco(str(executable),[str(ROOT/"prototypes/network-menu-v1/app-icon.ico")])
    # The full Godot runtime also contains a named group, sorted before ID 1
    # by Windows Explorer. Replace that group too so the Godot icon cannot win.
    handle=win32api.LoadLibraryEx(str(executable),0,2)
    try:
        groups=win32api.EnumResourceNames(handle,14)
        data=win32api.LoadResource(handle,14,1)
    finally:
        win32api.FreeLibrary(handle)
    update=win32api.BeginUpdateResource(str(executable),False)
    for group in groups:
        win32api.UpdateResource(update,14,group,data)
    win32api.EndUpdateResource(update,False)


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--godot",required=True)
    p.add_argument("--public-certificate")
    p.add_argument("--client-only",action="store_true",help="Update client without touching the running server")
    p.add_argument("--output",type=Path)
    p.add_argument("--archive-dir",type=Path)
    args=p.parse_args()
    godot=Path(args.godot).resolve()
    runtime=godot.with_name(godot.name.replace("_console.exe",".exe")) if godot.name.endswith("_console.exe") else godot
    if not runtime.is_file():raise FileNotFoundError(runtime)
    out=args.output.resolve() if args.output else ROOT/"dist"/"network-v0.1.0"
    archive_dir=args.archive_dir.resolve() if args.archive_dir else ROOT/"dist"
    archive_dir.mkdir(parents=True,exist_ok=True)
    client=out/"Client";server=out/"Server";config=out/"Config"
    for folder in (client,server,config,client/"Config"):
        folder.mkdir(parents=True,exist_ok=True)
    keep={"character-creation-v1","character-hair-v2","character-face-v3","ponytail-side-v3","network-menu-v1"}
    excludes=["art/*","reports/*","tests/*","tools/*","dist/*","server-data/*",".forge/*"]
    excludes += ["prototypes/"+f.name+"/*" for f in (ROOT/"prototypes").iterdir() if f.is_dir() and f.name not in keep]
    preset='''[preset.0]
name="Windows LAN"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="*.json,*.txt,*.gd,*.png"
exclude_filter="%s"
export_path=""
script_export_mode=1

[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=false
''' % ",".join(excludes)
    presets=ROOT/"export_presets.cfg"
    previous=presets.read_bytes() if presets.exists() else None
    try:
        presets.write_text(preset,encoding="utf-8")
        subprocess.run([str(godot),"--headless","--path",str(ROOT),"--export-pack","Windows LAN",str(client/"Windrest.pck")],check=True)
    finally:
        if previous is None:presets.unlink(missing_ok=True)
        else:presets.write_bytes(previous)
    # The official standalone Godot engine runs the adjacent PCK directly.
    shutil.copy2(runtime,client/"Windrest.exe")
    apply_client_icon(client/"Windrest.exe")
    compiler=Path("C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe")
    subprocess.run([str(compiler),"/nologo","/reference:System.Security.dll",
                    "/out:"+str(client/"LoginVault.exe"),str(ROOT/"tools/network/LoginVault.cs")],check=True)
    if not args.client_only:
        shutil.copy2(runtime,server/"WorldWorker.exe")
        shutil.copy2(client/"Windrest.pck",server/"WorldWorker.pck")
    # prototypes/.gdignore intentionally prevents editor-wide candidate imports.
    # Pack only the runtime candidate directories as a separate raw pack.
    manifest=out/"candidate-manifest.json"
    files=[str(f.relative_to(ROOT)).replace("\\","/") for name in keep for f in (ROOT/"prototypes"/name).rglob("*") if f.is_file() and f.suffix.lower() in (".png",".json")]
    manifest.write_text(json.dumps(files),encoding="utf-8")
    subprocess.run([str(godot),"--headless","--path",str(ROOT),"--script",str(ROOT/"tools/network/pack_candidates.gd"),"--",str(manifest),str(client/"Candidates.pck")],check=True)
    if args.client_only:
        if args.public_certificate:
            shutil.copy2(args.public_certificate,client/"Config/server-public.crt")
        print("Client files updated:",client)
        return
    shutil.copy2(client/"Candidates.pck",server/"Candidates.pck")
    # Some bundled Python distributions load an adjacent TLS policy PEM when
    # constructing SSLContext. Preserve that policy in the frozen executable.
    tls_policy = Path(ssl.__file__).with_name("codex-rejected-cas.pem")
    tls_data = ["--add-data", str(tls_policy)+";."] if tls_policy.is_file() else []
    subprocess.run([sys.executable,"-m","PyInstaller",*tls_data,"--noconfirm","--onefile","--name","WindrestServer",
                    "--distpath",str(server),"--workpath",str(out/"build"),"--specpath",str(out/"build"),
                    "--collect-all","PIL","--collect-all","cryptography",str(ROOT/"tools/network/server.py")],check=True)
    subprocess.run([sys.executable,"-m","PyInstaller","--noconfirm","--onefile","--windowed","--name","WindrestMonitor",
                    "--distpath",str(server),"--workpath",str(out/"monitor-build"),"--specpath",str(out/"monitor-build"),
                    str(ROOT/"tools/network/monitor.py")],check=True)
    (out/"View-Server.cmd").write_text('@echo off\r\nstart "" "%~dp0Server\\WindrestMonitor.exe" --config "%~dp0Config\\network-server.json"\r\n',encoding="ascii")
    c=json.loads((ROOT/"config/network-server.json").read_text())
    c["godot"]="../Server/WorldWorker.exe";c["project"]="../Server"
    c["data_dir"]="../Data"
    (config/"network-server.json").write_text(json.dumps(c,ensure_ascii=False,indent=2),encoding="utf-8")
    shutil.copy2(ROOT/"config/network-client.json",client/"Config/network-client.json")
    if args.public_certificate:
        shutil.copy2(args.public_certificate,client/"Config/server-public.crt")
    build_info="Windrest V0.1.0 / full gameplay V9\nGameplay revision: 1\nMovement revision: 2\nClient and server must be updated together.\n"
    (client/"BUILD.txt").write_text(build_info,encoding="utf-8")
    (server/"BUILD.txt").write_text(build_info,encoding="utf-8")
    (out/"Start-Server.cmd").write_text('@echo off\r\nstart "" "%~dp0Server\\WindrestMonitor.exe" --config "%~dp0Config\\network-server.json"\r\n"%~dp0Server\\WindrestServer.exe" --config "%~dp0Config\\network-server.json"\r\npause\r\n',encoding="ascii")
    (out/"Initialize-Server.cmd").write_text('@echo off\r\n"%~dp0Server\\WindrestServer.exe" --config "%~dp0Config\\network-server.json" --initialize\r\npause\r\n',encoding="ascii")
    for file in (ROOT/"tools/network").glob("*.md"):
        shutil.copy2(file,out/file.name)
    archive=archive_dir/"Windrest-Client-v0.1.0.zip"
    with zipfile.ZipFile(archive,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for f in client.rglob("*"):
            if f.is_file():z.write(f,f.relative_to(client))
    with zipfile.ZipFile(archive_dir/"Windrest-Server-v0.1.0.zip","w",zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for folder in (server,config):
            for f in folder.rglob("*"):
                if f.is_file():z.write(f,f.relative_to(out))
        for f in out.iterdir():
            if f.is_file() and f.suffix in (".cmd",".md"):z.write(f,f.name)
    print("Client:",archive)
    print("Server:",out)

if __name__=="__main__":main()
