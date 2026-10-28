from pathlib import Path
import subprocess,sys
p=Path('scripts/item_service.gd');fixed=p.read_bytes();s=fixed.decode('utf-8').replace('\r\n','\n')
s=s.replace('\t\tvar changed_rows: Array=[]\n','').replace('changed_rows.append(previous_buildings[id])','builds.refresh_around(previous_buildings[id])').replace('changed_rows.append(builds.states[id])','builds.refresh_around(builds.states[id])').replace('\n\t\tbuilds.refresh_rows(changed_rows)','')
try:
 p.write_bytes(s.encode('utf-8'))
 subprocess.run([sys.executable,'tests/restore_batch_probe.py','reports/interaction-latency-audit/batch-before-24.json'],check=True)
 subprocess.run([sys.executable,'tests/network_latency_load.py','--seconds','30','--label','round3-before'],check=True)
finally:p.write_bytes(fixed)
