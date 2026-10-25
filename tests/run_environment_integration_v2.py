"""Current season/weather native checks, preserving historical report outputs."""
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/network-integration-v2/environment'
OUT.mkdir(parents=True,exist_ok=True)
for name,source,old in [('calendar','season_v1.gd','seasons-v1'),('surface','season_features_v1.gd','season-features-v1'),('body','weather_body_v1.gd','weather-v1'),('legacy-hat','hat_legacy_v2.gd','hat-motion-v2')]:
    destination=OUT/name;destination.mkdir(exist_ok=True)
    text=(ROOT/'tests'/source).read_text(encoding='utf-8')
    text=text.replace('res://reports/'+old+'/',str(destination).replace('\\','/')+'/')
    script=OUT/(name+'.gd');script.write_text(text,encoding='utf-8')
    try:
        with (OUT/(name+'.log')).open('w',encoding='utf-8') as log:
            subprocess.run(['D:/Godot/Godot_v4.7.2-stable_win64.exe','--path',str(ROOT),'--script',str(script)],stdout=log,stderr=log,check=True,timeout=180)
    finally:
        script.unlink(missing_ok=True);script.with_suffix('.gd.uid').unlink(missing_ok=True)
    print(name,'passed',flush=True)
