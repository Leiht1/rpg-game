"""Run the current weather suites with outputs isolated from historical evidence."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path("D:/Godot/Godot_v4.7.2-stable_win64_console.exe")
OUT = ROOT / "reports/seasons-v1"
for name, source, old_folder in (
    ("weather-layer", "weather_layer_v2.gd", "weather-layer-v2"),
    ("weather-body", "weather_body_v1.gd", "weather-v1"),
):
    folder = OUT / name
    folder.mkdir(parents=True, exist_ok=True)
    script = OUT / (name + "-regression.gd")
    text = (ROOT / "tests" / source).read_text(encoding="utf-8")
    text = text.replace("reports/" + old_folder + "/", "reports/seasons-v1/" + name + "/")
    script.write_text(text, encoding="utf-8")
    try:
        with (folder / "native.log").open("w", encoding="utf-8") as log:
            subprocess.run([str(ENGINE), "--path", str(ROOT), "--script", str(script)],
                           stdout=log, stderr=log, check=True, timeout=150)
    finally:
        script.unlink(missing_ok=True)
        script.with_suffix(".gd.uid").unlink(missing_ok=True)
    print(name, "passed", flush=True)
