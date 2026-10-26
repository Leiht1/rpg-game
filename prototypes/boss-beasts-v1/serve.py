from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from pathlib import Path
import os,webbrowser,argparse
p=argparse.ArgumentParser();p.add_argument('--open',action='store_true');a=p.parse_args()
os.chdir(Path(__file__).resolve().parent)
url='http://127.0.0.1:8766/'
try: server=ThreadingHTTPServer(('127.0.0.1',8766),SimpleHTTPRequestHandler)
except OSError:
 if a.open:webbrowser.open(url)
 raise SystemExit('Preview port already in use; existing server retained.')
if a.open:webbrowser.open(url)
print(url,flush=True);server.serve_forever()
