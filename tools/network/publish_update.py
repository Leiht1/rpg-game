"""Publish a signed immutable runtime and prepare the first launcher bundle."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from updater import FILES, atomic_json, canonical, file_hash, verify

ROOT=Path(__file__).resolve().parents[2]

def publish(client, updates, key_path, version, sequence, notes):
    updates.mkdir(parents=True,exist_ok=True)
    if key_path.exists():key=serialization.load_pem_private_key(key_path.read_bytes(),password=None)
    else:
        key_path.parent.mkdir(parents=True,exist_ok=True)
        key=Ed25519PrivateKey.generate()
        key_path.write_bytes(key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
        if __import__("os").name=="nt":
            import re
            raw=subprocess.check_output(["whoami","/user","/fo","csv","/nh"])
            sid=re.search(rb"S-1-\d+(?:-\d+)+",raw).group().decode("ascii")
            subprocess.run(["icacls",str(key_path),"/inheritance:r","/grant:r","*"+sid+":F","SYSTEM:F"],check=True,stdout=subprocess.DEVNULL)
    if not isinstance(key,Ed25519PrivateKey):raise ValueError("需要Ed25519签名密钥")
    public=base64.b64encode(key.public_key().public_bytes(serialization.Encoding.Raw,serialization.PublicFormat.Raw)).decode("ascii")
    if (updates/"latest.json").exists():
        previous=verify(json.loads((updates/"latest.json").read_text(encoding="utf-8")),public)
        if sequence <= previous["sequence"] or version==previous["version"]:raise ValueError("发布版本及序号必须递增")
    fd,temp=__import__("tempfile").mkstemp(suffix=".zip",dir=updates);__import__("os").close(fd)
    archive=Path(temp)
    try:
        with zipfile.ZipFile(archive,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as z:
            for name in sorted(FILES):z.write(client/name,name)
        digest=file_hash(archive)
        payload={"format":1,"version":version,"sequence":sequence,"notes":notes,
                 "archive":"client-"+digest+".zip","sha256":digest,"size":archive.stat().st_size,
                 "files":{name:file_hash(client/name) for name in sorted(FILES)}}
        envelope={"payload":payload,"signature":base64.b64encode(key.sign(canonical(payload))).decode("ascii")}
        # Publish the immutable archive before changing discovery metadata.
        archive.replace(updates/payload["archive"])
        atomic_json(updates/"latest.json",envelope)
    finally:archive.unlink(missing_ok=True)
    public=base64.b64encode(key.public_key().public_bytes(serialization.Encoding.Raw,serialization.PublicFormat.Raw)).decode("ascii")
    return envelope,public

def bootstrap(client, home, launcher, envelope, public):
    if home.exists():raise ValueError("首次启动包目录已存在，请使用新目录")
    home.mkdir(parents=True)
    shutil.copytree(client/"Config",home/"Config")
    (home/"Config/update-public.key").write_text(public,encoding="ascii")
    payload=envelope["payload"];runtime=home/"Versions"/payload["version"];runtime.mkdir(parents=True)
    for name in FILES:shutil.copy2(client/name,runtime/name)
    (runtime/"release.json").write_bytes(canonical(envelope))
    atomic_json(home/"current.json",{"version":payload["version"],"sequence":payload["sequence"]})
    shutil.copy2(launcher,home/"WindrestLauncher.exe")
    (home/"使用说明.txt").write_text("风栖原野自动更新版\n\n完整解压到可写文件夹，双击 WindrestLauncher.exe。\n每次启动会检查并自动更新，然后进入游戏。\n更新失败可重试，或启动已安装版本。\n更新成功后只保留当前版和上一版，自动清理更早版本。\n不要单独移动EXE；保留Config、Versions和current.json。\n请先关闭游戏再重新启动启动器。个人存档及记住的账号不在更新包内。\n",encoding="utf-8")

def prune_distribution_packages(dist, current_version):
    """Keep current and previous bootstrap bundles after a successful build."""
    import re
    dist = dist.resolve()
    prefix = "Windrest-AutoUpdate-"
    current = tuple(map(int, current_version.split(".")))
    # A failed/incomplete new bundle must never trigger removal of older builds.
    home = dist/(prefix+current_version)
    archive = dist/(prefix+current_version+".zip")
    if not home.is_dir() or not archive.is_file():return []
    if json.loads((home/"current.json").read_text(encoding="utf-8"))["version"] != current_version:return []
    with zipfile.ZipFile(archive) as z:
        if z.testzip() is not None:return []
    versions = {}
    for path in dist.iterdir():
        match = re.fullmatch(r"Windrest-AutoUpdate-([0-9]+(?:\.[0-9]+){1,4})(?:\.zip)?", path.name)
        if not match:continue
        version = tuple(map(int, match[1].split(".")))
        if version <= current:versions.setdefault(version, []).append(path)
    removed = []
    for version in sorted(versions, reverse=True)[2:]:
        for path in versions[version]:
            # Resolve and check every removal target; never follow links/junctions.
            if path.resolve().parent != dist:continue
            if path.is_symlink() or getattr(path.lstat(), "st_file_attributes", 0) & 0x400:continue
            try:
                if path.is_dir():
                    if any(p.is_symlink() or getattr(p.lstat(), "st_file_attributes", 0) & 0x400 for p in path.rglob("*")):continue
                    shutil.rmtree(path)
                else:path.unlink()
                removed.append(path.name)
            except OSError:
                print("Distribution cleanup deferred:", path)
    return removed

def main():
    p=argparse.ArgumentParser();p.add_argument("--client",type=Path,required=True)
    p.add_argument("--updates",type=Path,required=True);p.add_argument("--key",type=Path,required=True)
    p.add_argument("--version",required=True);p.add_argument("--sequence",type=int,required=True)
    p.add_argument("--notes",default="客户端更新");p.add_argument("--bootstrap",type=Path)
    args=p.parse_args()
    # Validate publication identifiers before any write.
    import re
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,4}",args.version) or args.sequence < 1:raise ValueError("版本编号无效")
    envelope,public=publish(args.client.resolve(),args.updates.resolve(),args.key.resolve(),args.version,args.sequence,args.notes)
    if args.bootstrap:
        build=ROOT/"dist/updater-build"
        subprocess.run([__import__("sys").executable,"-m","PyInstaller","--noconfirm","--onefile","--windowed","--name","WindrestLauncher",
                        "--icon",str(ROOT/"prototypes/network-menu-v1/app-icon.ico"),"--distpath",str(build/"bin"),"--workpath",str(build/"work"),"--specpath",str(build),str(ROOT/"tools/network/updater.py")],check=True)
        bootstrap(args.client.resolve(),args.bootstrap.resolve(),build/"bin/WindrestLauncher.exe",envelope,public)
        shutil.make_archive(str(args.bootstrap.resolve()),"zip",args.bootstrap.resolve())
        print("Launcher package:",str(args.bootstrap.resolve())+".zip")
        print("Old distribution packages removed:", prune_distribution_packages(args.bootstrap.resolve().parent, args.version))
    print("Published:",args.updates.resolve()/"latest.json")

if __name__=="__main__":main()
