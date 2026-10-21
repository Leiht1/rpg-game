"""Machine-local persistent test service. Never touches existing LAN deployments."""
import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import ssl
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[2]


def write_new(path, value):
    with path.open('x', encoding='utf-8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['setup', 'server', 'client', 'check', 'backup'])
    parser.add_argument('--godot')
    args = parser.parse_args()
    root = Path(os.environ['LOCALAPPDATA']) / 'Windrest' / 'IndependentTest-v1'
    manifest = root / 'machine.json'
    if args.action == 'setup':
        import cryptography  # Fail before creating any files if dependencies are absent.
        import PIL
        godot = Path(args.godot).resolve() if args.godot else None
        if godot is None or not godot.is_file():
            raise SystemExit('Setup requires --godot with the Godot 4.7.2 executable path.')
        version = subprocess.check_output([str(godot), '--version'], text=True).strip()
        if not version.startswith('4.7.2.'):
            raise SystemExit('Godot 4.7.2 required: ' + version)
        if manifest.exists():
            print('Existing setup retained; accounts, worlds, certificates and config unchanged.')
        else:
            if root.exists() and any(root.iterdir()):
                raise SystemExit('Partial/existing directory detected. Preserve it and inspect; refusing initialization: ' + str(root))
            with socket.socket() as probe:
                probe.bind(('127.0.0.1', 24871))
            root.mkdir(parents=True, exist_ok=True)
            config = json.loads((PROJECT / 'config/network-server.json').read_text(encoding='utf-8-sig'))
            config.update(bind='127.0.0.1', port=24871, data_dir=str(root / 'Data'),
                          godot=str(godot), project=str(PROJECT))
            write_new(root / 'server.json', config)
            subprocess.run([sys.executable, str(PROJECT / 'tools/network/server.py'), '--config',
                            str(root / 'server.json'), '--initialize'], check=True)
            client = json.loads((PROJECT / 'config/network-client.json').read_text(encoding='utf-8-sig'))
            client.update(server_url='https://127.0.0.1:24871',
                          certificate=str(root / 'Data/server-public.crt'),
                          login_cache=str(root / 'login-memory.json'))
            write_new(root / 'client.json', client)
            # Adjacent helper enables DPAPI without touching the old dist deployment.
            runtime = root / 'Runtime'
            runtime.mkdir()
            source_runtime = godot.with_name(godot.name.replace('_console.exe', '.exe'))
            shutil.copy2(source_runtime, runtime / 'WindrestTest.exe')
            compiler = Path(os.environ['WINDIR']) / 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
            subprocess.run([str(compiler), '/nologo', '/reference:System.Security.dll',
                            '/out:' + str(runtime / 'LoginVault.exe'),
                            str(PROJECT / 'tools/network/LoginVault.cs')], check=True)
            write_new(manifest, dict(machine=os.environ['COMPUTERNAME'], project=str(PROJECT),
                                    python=sys.executable, godot=str(godot), schema=1))
        print('Local persistent test data: ' + str(root))
        print('Private activation file: ' + str(root / 'Data/Accounts/FIRST-ACTIVATION.private.json'))
        return
    if not manifest.exists():
        raise SystemExit('Run setup on this computer first.')
    machine = json.loads(manifest.read_text(encoding='utf-8'))
    if machine['machine'] != os.environ['COMPUTERNAME'] or machine['project'] != str(PROJECT):
        raise SystemExit('Machine/project mismatch; preserve the data and inspect before using it.')
    if args.action in ('server', 'backup'):
        # Avoid opening a second Service while the live service owns in-memory state.
        with socket.socket() as probe:
            probe.bind(('127.0.0.1', 24871))
        command = [machine['python'], str(PROJECT / 'tools/network/server.py'),
                   '--config', str(root / 'server.json')]
        if args.action == 'backup':
            command.append('--backup')
        raise SystemExit(subprocess.call(command))
    if args.action == 'client':
        subprocess.Popen([str(root / 'Runtime/WindrestTest.exe'), '--path', str(PROJECT),
                          '--', '--network-config=' + str(root / 'client.json')])
        return
    context = ssl.create_default_context(cafile=str(root / 'Data/server-public.crt'))
    # Connect over loopback while checking the fixed certificate identity.
    with socket.create_connection(('127.0.0.1', 24871), timeout=8) as connection:
        with context.wrap_socket(connection, server_hostname='windrest-server') as tls:
            payload = json.dumps(dict(version='0.1.0', protocol=1, username='__connection_probe__',
                                      password='invalid-probe-password')).encode()
            tls.sendall(b'POST /api/login HTTP/1.0\r\nHost: windrest-server\r\nContent-Type: application/json\r\nContent-Length: '
                        + str(len(payload)).encode() + b'\r\n\r\n' + payload)
            chunks = []
            while True:
                chunk = tls.recv(65536)
                if not chunk:
                    break
                chunks.append(chunk)
            response = json.loads(b''.join(chunks).split(b'\r\n\r\n', 1)[1])
            if response.get('ok') is not False or not response.get('error'):
                raise SystemExit('Unexpected login probe reply.')
    print('TLS certificate and local login endpoint verified; no real account used.')


if __name__ == '__main__':
    main()
