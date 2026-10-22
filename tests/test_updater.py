import copy
import json
from pathlib import Path
import ssl
import sys
import tempfile
import threading
import types
import unittest
from unittest.mock import patch
import zipfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools/network"))
import updater
import publish_update
import server

class UpdaterTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.client=self.root/"client";self.client.mkdir();(self.client/"Config").mkdir()
        for name in updater.FILES:(self.client/name).write_bytes((name+" old").encode())
        self.updates=self.root/"Updates";self.key=self.root/"private/key.pem"
        self.first,self.public=publish_update.publish(self.client,self.updates,self.key,"2026.10.22.1",1,"old")
        self.home=self.root/"同事 中文目录";launcher=self.root/"launcher.exe";launcher.write_bytes(b"launcher")
        publish_update.bootstrap(self.client,self.home,launcher,self.first,self.public)
        for name in updater.FILES:(self.client/name).write_bytes((name+" new").encode())
        self.second,_=publish_update.publish(self.client,self.updates,self.key,"2026.10.22.2",2,"new")
        self.archive=self.updates/self.second["payload"]["archive"]
    def tearDown(self):self.temp.cleanup()
    def test_install_preserves_config_and_old_version(self):
        marker=self.home/"Config/personal.txt";marker.write_bytes(b"keep")
        result=updater.install(self.home,self.archive,self.second,self.public)
        self.assertEqual(updater.installed(self.home)[0]["sequence"],2)
        self.assertEqual(marker.read_bytes(),b"keep")
        self.assertTrue((self.home/"Versions/2026.10.22.1/Windrest.exe").exists())
        self.assertEqual((result/"Windrest.pck").read_bytes(),b"Windrest.pck new")
    def test_bad_signature(self):
        value=copy.deepcopy(self.second);value["payload"]["notes"]="tamper"
        with self.assertRaises(Exception):updater.install(self.home,self.archive,value,self.public)
        self.assertEqual(updater.installed(self.home)[0]["sequence"],1)
    def next_release(self, sequence):
        for name in updater.FILES:(self.client/name).write_bytes((name+str(sequence)).encode())
        envelope,_=publish_update.publish(self.client,self.updates,self.key,"2026.10.22."+str(sequence),sequence,"test")
        return envelope,self.updates/envelope["payload"]["archive"]
    def test_keeps_only_latest_two_and_config(self):
        updater.install(self.home,self.archive,self.second,self.public)
        marker=self.home/"Config/personal.txt";marker.write_bytes(b"keep")
        for sequence in (3,4):
            envelope,archive=self.next_release(sequence)
            updater.install(self.home,archive,envelope,self.public)
            self.assertEqual(sorted(p.name for p in (self.home/"Versions").iterdir()),
                             ["2026.10.22."+str(sequence-1),"2026.10.22."+str(sequence)])
        self.assertEqual(marker.read_bytes(),b"keep")
    def test_failed_switch_does_not_prune(self):
        updater.install(self.home,self.archive,self.second,self.public)
        envelope,archive=self.next_release(3)
        with patch.object(updater,"atomic_json",side_effect=OSError("disk full")):
            with self.assertRaises(OSError):updater.install(self.home,archive,envelope,self.public)
        self.assertTrue((self.home/"Versions/2026.10.22.1").is_dir())
        self.assertEqual(updater.installed(self.home)[0]["sequence"],2)
        updater.install(self.home,archive,envelope,self.public)
        self.assertFalse((self.home/"Versions/2026.10.22.1").exists())
    def test_locked_old_version_retries_and_unknown_folder_preserved(self):
        updater.install(self.home,self.archive,self.second,self.public)
        unknown=self.home/"Versions/2020.1";unknown.mkdir();(unknown/"personal.txt").write_bytes(b"keep")
        envelope,archive=self.next_release(3)
        original=updater.shutil.rmtree
        def locked(path,*args,**kwargs):
            if Path(path).name=="2026.10.22.1":raise PermissionError("locked")
            return original(path,*args,**kwargs)
        with patch.object(updater.shutil,"rmtree",side_effect=locked):
            updater.install(self.home,archive,envelope,self.public)
        self.assertEqual(updater.installed(self.home)[0]["sequence"],3)
        self.assertTrue((self.home/"Versions/2026.10.22.1").exists())
        with patch.object(updater,"fetch",return_value=updater.canonical(envelope)):
            updater.atomic_json(self.home/"Config/network-client.json",{})
            updater.update(self.home)
        self.assertFalse((self.home/"Versions/2026.10.22.1").exists())
        self.assertEqual((unknown/"personal.txt").read_bytes(),b"keep")
    def test_hash_tampering(self):
        self.archive.write_bytes(b"broken")
        with self.assertRaises(ValueError):updater.install(self.home,self.archive,self.second,self.public)
        self.assertEqual(updater.installed(self.home)[0]["sequence"],1)
    def test_atomic_pointer_failure_keeps_previous(self):
        with patch.object(updater,"atomic_json",side_effect=OSError("disk full")):
            with self.assertRaises(OSError):updater.install(self.home,self.archive,self.second,self.public)
        self.assertEqual(updater.installed(self.home)[0]["sequence"],1)
        updater.install(self.home,self.archive,self.second,self.public)
        self.assertEqual(updater.installed(self.home)[0]["sequence"],2)
    def test_zip_traversal_rejected(self):
        evil=self.root/"bad.zip"
        with zipfile.ZipFile(evil,"w") as z:z.writestr("../escape.exe",b"bad")
        value=copy.deepcopy(self.second);p=value["payload"]
        p["sha256"]=updater.file_hash(evil);p["size"]=evil.stat().st_size;p["archive"]="client-"+p["sha256"]+".zip"
        from cryptography.hazmat.primitives import serialization
        import base64
        key=serialization.load_pem_private_key(self.key.read_bytes(),password=None)
        value["signature"]=base64.b64encode(key.sign(updater.canonical(p))).decode()
        with self.assertRaises(ValueError):updater.install(self.home,evil,value,self.public)
        self.assertFalse((self.root/"escape.exe").exists())
    def test_https_download_update_and_current(self):
        data=self.root/"Data";data.mkdir();(data/"Accounts").mkdir()
        cert,key=server.certificate(data)
        http=server.ThreadingHTTPServer(("127.0.0.1",0),server.Handler)
        http.service=types.SimpleNamespace(root=data)
        context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(cert,key)
        http.socket=context.wrap_socket(http.socket,server_side=True)
        thread=threading.Thread(target=http.serve_forever,daemon=True);thread.start()
        try:
            import shutil
            shutil.copy2(cert,self.home/"Config/server-public.crt")
            config={"server_url":"https://127.0.0.1:"+str(http.server_port),"server_name":"windrest-server"}
            updater.atomic_json(self.home/"Config/network-client.json",config)
            updater.update(self.home)
            self.assertEqual(updater.installed(self.home)[0]["sequence"],2)
            self.assertEqual(updater.update(self.home),updater.installed(self.home)[1])
            # A lower signed release still cannot silently downgrade the client.
            updater.atomic_json(self.updates/"latest.json",self.first)
            with self.assertRaises(ValueError):updater.update(self.home)
            for name in ["../Data/server-public.crt","../Data/Accounts/server-key.private.pem","%2e%2e/Data/x"]:
                with self.assertRaises(ValueError):updater.fetch(config,self.home,name)
            config["server_name"]="wrong-server"
            with self.assertRaises(ssl.SSLCertVerificationError):updater.fetch(config,self.home,"latest.json")
        finally:http.shutdown();http.server_close();thread.join()
    def test_launch_passes_persistent_config(self):
        with patch.object(updater.subprocess,"Popen") as spawn:
            updater.launch(self.home)
            args=spawn.call_args.args[0]
            self.assertEqual(args[-1],"--network-config="+str(self.home/"Config/network-client.json"))
            self.assertIn("Versions",args[0])
    def test_release_sequence_cannot_be_reused(self):
        with self.assertRaises(ValueError):publish_update.publish(self.client,self.updates,self.key,"same",2,"x")

if __name__=="__main__":unittest.main()
