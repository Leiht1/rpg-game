"""Sequential final packaged passes; keep independent evidence for each round."""
from pathlib import Path
import subprocess
import sys
import argparse
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/network-integration-v2'
RUNTIME=ROOT/'reports/.tmp/network-integration-v2/runtime'
commands=[
 ('build-final-assets',[str(ROOT/'tools/network/build.py'),'--godot','D:/Godot/Godot_v4.7.2-stable_win64_console.exe','--output',str(RUNTIME),'--archive-dir',str(RUNTIME.parent/'archives')]),
 ('gear-final-package',[str(ROOT/'tests/run_network_integration_v2.py'),'--mode','gear','--runtime',str(RUNTIME)]),
 ('gameplay-final-package',[str(ROOT/'tests/run_network_integration_v2.py'),'--mode','gameplay','--runtime',str(RUNTIME)]),
 ('delay-final-package',[str(ROOT/'tests/run_network_integration_v2.py'),'--mode','gameplay','--delay','.22','--runtime',str(RUNTIME)]),
 ('restart-final-package',[str(ROOT/'tests/network_persistence_v2.py')]),
]
p=argparse.ArgumentParser();p.add_argument('--start',choices=[label for label,args in commands],default=commands[0][0]);options=p.parse_args()
commands=commands[[label for label,args in commands].index(options.start):]
for label,args in commands:
    with (OUT/(label+'.log')).open('w',encoding='utf-8') as log:
        subprocess.run([sys.executable,*args],stdout=log,stderr=log,check=True)
    print(label,'passed',flush=True)
