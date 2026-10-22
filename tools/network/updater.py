"""Signed full-package updater. Installed versions are immutable; only pointer switches."""
import argparse
import base64
import hashlib
import http.client
import json
import os
from pathlib import Path
import queue
import re
import shutil
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
from urllib.parse import urlsplit
import zipfile
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

FILES = {"Windrest.exe", "Windrest.pck", "Candidates.pck", "LoginVault.exe", "BUILD.txt"}
MAX_SIZE = 2 * 1024**3

def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")

def atomic_json(path, value):
    path = Path(path)
    temp = path.with_suffix(path.suffix + ".tmp")
    with temp.open("wb") as f:
        f.write(canonical(value)); f.flush(); os.fsync(f.fileno())
    os.replace(temp, path)

def verify(envelope, public_key):
    payload = envelope["payload"]
    Ed25519PublicKey.from_public_bytes(base64.b64decode(public_key, validate=True)).verify(
        base64.b64decode(envelope["signature"], validate=True), canonical(payload))
    if (payload.get("format") != 1 or not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,4}", payload.get("version", ""))
        or not isinstance(payload.get("sequence"), int) or payload["sequence"] < 1
        or not isinstance(payload.get("size"), int) or not 0 < payload["size"] <= MAX_SIZE
        or not re.fullmatch(r"[a-f0-9]{64}", payload.get("sha256", ""))
        or payload.get("archive") != "client-" + payload["sha256"] + ".zip"
        or set(payload.get("files", {})) != FILES
        or any(not re.fullmatch(r"[a-f0-9]{64}", v) for v in payload["files"].values())):
        raise ValueError("更新版本信息无效")
    return payload

class Connection(http.client.HTTPSConnection):
    def __init__(self, url, certificate, server_name):
        parts = urlsplit(url)
        if parts.scheme != "https" or not parts.hostname or parts.username or parts.query or parts.fragment:
            raise ValueError("更新地址须为HTTPS")
        super().__init__(parts.hostname, parts.port or 443, timeout=12,
                         context=ssl.create_default_context(cafile=str(certificate)))
        self.server_name = server_name
        self.base_path = parts.path.rstrip("/")
    def connect(self):
        raw = socket.create_connection((self.host, self.port), self.timeout)
        try:self.sock = self._context.wrap_socket(raw, server_hostname=self.server_name)
        except BaseException:raw.close(); raise

def fetch(config, home, name, target=None, progress=lambda *_: None):
    conn = Connection(config["server_url"], home/"Config"/config.get("certificate", "server-public.crt"), config.get("server_name", "windrest-server"))
    try:
        conn.request("GET", conn.base_path + "/updates/" + name)
        response = conn.getresponse()
        if response.status != 200:raise ValueError("更新服务暂不可用（%s）" % response.status)
        limit = MAX_SIZE if target else 65536
        length = int(response.getheader("Content-Length", "0"))
        if not 0 < length <= limit:raise ValueError("更新文件大小无效")
        data = bytearray(); total = 0
        out = target.open("wb") if target else None
        try:
            while True:
                block = response.read(256*1024)
                if not block:break
                total += len(block)
                if total > length:raise ValueError("下载文件超出声明大小")
                if out:out.write(block)
                else:data.extend(block)
                progress(total, length)
        finally:
            if out:out.close()
        if total != length:raise ValueError("下载中断，请重试")
        return bytes(data)
    finally:conn.close()

def file_hash(path):
    with Path(path).open("rb") as f:return hashlib.file_digest(f, "sha256").hexdigest()

def prune_versions(home, public_key):
    """Best-effort cleanup only after a successful version switch/check."""
    try:
        current, _ = installed(home)
        versions = home/"Versions"
        root = versions.resolve()
        if versions.is_symlink() or getattr(versions.lstat(), "st_file_attributes", 0) & 0x400:return
        candidates = []
        for path in versions.iterdir():
            try:
                if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,4}", path.name):continue
                if path.is_symlink() or getattr(path.lstat(), "st_file_attributes", 0) & 0x400:continue
                if not path.is_dir() or path.resolve().parent != root:continue
                payload = verify(json.loads((path/"release.json").read_text(encoding="utf-8")), public_key)
                if payload["version"] == path.name and payload["sequence"] < current["sequence"]:
                    candidates.append((payload["sequence"], path))
            except Exception:continue
        candidates.sort(key=lambda item:item[0], reverse=True)
        for _, path in candidates[1:]:
            try:
                # Never traverse junctions or links, even inside an old release.
                if any(p.is_symlink() or getattr(p.lstat(), "st_file_attributes", 0) & 0x400
                       for p in path.rglob("*")):continue
                shutil.rmtree(path)
            except OSError:pass  # Locked files are retried on the next successful check.
    except Exception:pass  # Cleanup must not prevent a verified game from starting.

def install(home, archive, envelope, public_key):
    payload = verify(envelope, public_key)
    if archive.stat().st_size != payload["size"] or file_hash(archive) != payload["sha256"]:
        raise ValueError("更新包校验失败，已保留原版本")
    versions = home/"Versions"; versions.mkdir(exist_ok=True)
    destination = versions/payload["version"]
    stage = Path(tempfile.mkdtemp(prefix=".install-", dir=versions))
    try:
        with zipfile.ZipFile(archive) as z:
            infos = z.infolist()
            if len(infos) != len(FILES) or {i.filename for i in infos} != FILES:
                raise ValueError("更新包文件清单无效")
            if sum(i.file_size for i in infos) > MAX_SIZE:raise ValueError("解压大小超出限制")
            for info in infos:
                if info.external_attr >> 16 & 0o170000 == 0o120000:raise ValueError("不允许符号链接")
                with z.open(info) as src, (stage/info.filename).open("wb") as dst:shutil.copyfileobj(src, dst)
                if file_hash(stage/info.filename) != payload["files"][info.filename]:raise ValueError("文件校验失败")
        (stage/"release.json").write_bytes(canonical(envelope))
        if destination.exists():
            if any(file_hash(destination/name) != digest for name,digest in payload["files"].items()):
                raise ValueError("已安装的同名版本损坏，请保留旧版本并联系管理员")
        else:os.replace(stage, destination)
        # New directory is complete before the only active-version pointer changes.
        atomic_json(home/"current.json", {"version":payload["version"], "sequence":payload["sequence"]})
        prune_versions(home, public_key)
        return destination
    finally:
        if stage.exists():shutil.rmtree(stage)

def installed(home):
    value = json.loads((home/"current.json").read_text(encoding="utf-8"))
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){1,4}", value.get("version", "")):raise ValueError("本地版本信息无效")
    path = home/"Versions"/value["version"]
    if not (path/"Windrest.exe").is_file():raise ValueError("本地游戏文件缺失")
    return value, path

def update(home, notify=lambda *_: None):
    config = json.loads((home/"Config/network-client.json").read_text(encoding="utf-8-sig"))
    public_key = (home/"Config/update-public.key").read_text().strip()
    notify("正在检查更新…", 0)
    envelope = json.loads(fetch(config, home, "latest.json"))
    payload = verify(envelope, public_key)
    current, path = installed(home)
    if payload["sequence"] < current["sequence"]:raise ValueError("服务器版本早于已安装版本，已阻止回退")
    if payload["sequence"] == current["sequence"]:
        if payload["version"] != current["version"]:raise ValueError("版本编号冲突")
        prune_versions(home, public_key)
        return path
    notify("发现新版本 " + payload["version"] + "\n" + payload.get("notes", ""), 0)
    fd, temp = tempfile.mkstemp(prefix=".download-", suffix=".zip", dir=home); os.close(fd)
    archive = Path(temp)
    try:
        fetch(config, home, payload["archive"], archive,
              lambda done,total:notify("正在下载：%.1f / %.1f MB" % (done/1024**2,total/1024**2),done/total*100))
        notify("正在校验并安装…", 100)
        return install(home, archive, envelope, public_key)
    finally:archive.unlink(missing_ok=True)

def launch(home):
    _, path = installed(home)
    # Config remains outside version directories; Godot saves remain in user://.
    return subprocess.Popen([str(path/"Windrest.exe"), "--", "--network-config="+str(home/"Config/network-client.json")], cwd=path)

def main():
    parser=argparse.ArgumentParser();parser.add_argument("--home",type=Path)
    parser.add_argument("--check-only",action="store_true");args=parser.parse_args()
    home=args.home.resolve() if args.home else Path(sys.executable if getattr(sys,"frozen",False) else __file__).resolve().parent
    lock=(home/"launcher.lock").open("a+b")
    if os.name=="nt":
        import msvcrt
        lock.seek(0);lock.write(b"0");lock.flush();lock.seek(0)
        try:msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
        except OSError:
            if args.check_only:return 2
            import tkinter.messagebox as msg
            msg.showinfo("风栖原野", "游戏或启动器已经打开，请先关闭原窗口。");return 2
    if args.check_only:
        try:update(home);return 0
        except Exception as exc:
            (home/"update-error.txt").write_text(str(exc),encoding="utf-8")
            return 1
    import tkinter as tk
    from tkinter import ttk
    window=tk.Tk();window.title("风栖原野 · 更新启动器");window.geometry("460x240");window.resizable(False,False)
    window.configure(bg="#e9dfc4")
    text=tk.StringVar(value="正在检查更新…");events=queue.Queue();running=[False];game=[None]
    tk.Label(window,textvariable=text,bg="#e9dfc4",fg="#4b4437",wraplength=420,justify="center",font=("Microsoft YaHei UI",11)).pack(padx=20,pady=25)
    bar=ttk.Progressbar(window,maximum=100,length=410);bar.pack(pady=8)
    row=tk.Frame(window,bg="#e9dfc4");row.pack(pady=12)
    def start_game():
        try:
            game[0]=launch(home);window.withdraw();watch_game()
        except Exception as exc:
            text.set("启动失败："+str(exc));retry_button.configure(state="normal");offline_button.configure(state="normal")
    def watch_game():
        if game[0].poll() is None:window.after(500,watch_game)
        else:window.destroy()
    def work():
        try:update(home,lambda label,value:events.put(("progress",label,value)));events.put(("done","",0))
        except Exception as exc:events.put(("error",str(exc),0))
    def retry():
        if running[0]:return
        running[0]=True;retry_button.configure(state="disabled");offline_button.configure(state="disabled")
        threading.Thread(target=work,daemon=True).start()
    retry_button=tk.Button(row,text="重试更新",command=retry);retry_button.pack(side="left",padx=8)
    offline_button=tk.Button(row,text="启动已安装版本",command=start_game);offline_button.pack(side="left",padx=8)
    def poll():
        while not events.empty():
            kind,label,value=events.get()
            if kind=="progress":text.set(label);bar["value"]=value
            elif kind=="done":running[0]=False;start_game();return
            else:
                running[0]=False;text.set("更新未完成，原版本已保留。\n"+label)
                retry_button.configure(state="normal");offline_button.configure(state="normal")
        window.after(100,poll)
    # Let a download finish safely; closing never terminates a running game.
    window.protocol("WM_DELETE_WINDOW", lambda:window.destroy() if not running[0] else text.set("正在更新，请等待完成后关闭。"))
    retry();poll();window.mainloop();return 0

if __name__=="__main__":sys.exit(main())
