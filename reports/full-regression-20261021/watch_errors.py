"""Stop only this run's stalled Godot tests after an unhandled script error."""
from pathlib import Path
import json
import subprocess
import time

OUT = Path(__file__).resolve().parent
records = []
while not (OUT / "save-protection.json").exists():
    logs = list((OUT / "logs").glob("*.log"))
    if logs:
        path = max(logs, key=lambda p: p.stat().st_mtime)
        text = path.read_text(encoding="utf-8", errors="replace")
        if "SCRIPT ERROR:" in text and time.time() - path.stat().st_mtime > 15:
            # Full path and exact script argument identify this disposable test.
            label = path.stem
            script = label.split("-phase")[0].split("-restart")[0] + ".gd"
            code = "$p=Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*' -and $_.CommandLine -like '*full-regression-20261021*' -and $_.CommandLine -like '*res://tests/" + script + "*' }; $p | ForEach-Object { Stop-Process -Id $_.ProcessId -Force; $_.ProcessId }"
            result = subprocess.run(["powershell", "-NoProfile", "-Command", code], capture_output=True, text=True)
            if result.stdout.strip():
                records.append({"label": label, "reason": "unhandled script error; no progress for 15 seconds", "pids": result.stdout.strip()})
                (OUT / "stalled-tests.json").write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
                print("STOPPED_STALLED", label, flush=True)
    time.sleep(3)
