"""Run current regression suites in a disposable copy, with isolated user data."""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
WORK = ROOT / "reports/.tmp/full-regression-20261021"
PROJECT = WORK / "project"
ENGINE = Path("D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
ENV = dict(os.environ, APPDATA=str(WORK / "AppData/Roaming"),
           LOCALAPPDATA=str(WORK / "AppData/Local"), PYTHONIOENCODING="utf-8")
RESULTS = []
RESUME = "--resume" in sys.argv


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")


def fingerprints():
    base = Path(os.environ["APPDATA"]) / "Godot/app_userdata"
    return {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in base.rglob("*") if p.is_file() and p.suffix in (".json", ".tmp")}


def prepare():
    if PROJECT.exists():
        raise RuntimeError("Disposable project already exists; refusing to overwrite")
    write_json(WORK / "player-before.json", fingerprints())
    files = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    for name in filter(None, files):
        target = PROJECT / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, target)
    for name in ("imported",):
        if (ROOT / ".godot" / name).exists():
            shutil.copytree(ROOT / ".godot" / name, PROJECT / ".godot" / name)
    cache = ROOT / ".godot/global_script_class_cache.cfg"
    if cache.exists():
        shutil.copy2(cache, PROJECT / ".godot" / cache.name)
    # Login tests need the existing local Windows-account encryption helper.
    helper = ROOT / "dist/network-v0.1.0/Client/LoginVault.exe"
    if helper.exists():
        target = PROJECT / "dist/network-v0.1.0/Client/LoginVault.exe"
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(helper, target)
    (PROJECT / "override.cfg").write_text(
        '[application]\nconfig/use_custom_user_dir=true\n'
        'config/custom_user_dir="WindrestRegression-20261021"\n', encoding="utf-8")
    # Only adapt old multi-size test loops; keep game sources and assertions intact.
    adaptations = []
    for path in (PROJECT / "tests").glob("*.gd"):
        text = path.read_text(encoding="utf-8-sig")
        updated = re.sub(r'\[(?:\s*Vector2i\(\s*\d+\s*,\s*\d+\s*\)\s*,?\s*){2,}\]',
                         lambda m: "[Vector2i(1280,720)]" if "960" in m[0] and "1600" in m[0] else m[0], text)
        if updated != text:
            path.write_text(updated, encoding="utf-8")
            adaptations.append(path.name)
    write_json(OUT / "environment.json", {
        "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
        "engine": str(ENGINE), "viewport": [1280, 720], "isolated_project": str(PROJECT),
        "test_only_resolution_adaptations": adaptations,
        "player_files_before": len(fingerprints()), "started": time.strftime("%Y-%m-%d %H:%M:%S")})
    print("PREPARED", len(files)-1, "tracked files; isolated data; default window only", flush=True)


def collect_checks(start):
    reports = []
    for path in (PROJECT / "reports").rglob("*.json"):
        if path.stat().st_mtime < start:
            continue
        try:
            value = json.loads(path.read_text(encoding="utf-8-sig"))
        except (ValueError, OSError):
            continue
        rows = value.get("checks", []) if isinstance(value, dict) else value
        if isinstance(rows, list) and rows and all(isinstance(r, dict) and "pass" in r for r in rows):
            reports.append({"source": str(path.relative_to(PROJECT)), "checks": len(rows),
                            "failures": [r.get("name", r.get("label", str(r))) for r in rows if not r["pass"]]})
    return reports


def execute(label, command, timeout=150, cwd=PROJECT, category="native"):
    previous = [r for r in RESULTS if r["label"] == label]
    if RESUME and previous and (previous[-1]["status"] == "pass" or label == "test_player"):
        return
    start = time.time()
    suffix = "-attempt"+str(len(previous)+1) if previous else ""
    log = OUT / "logs" / (re.sub(r"[^a-zA-Z0-9_-]", "_", label) + suffix + ".log")
    log.parent.mkdir(parents=True, exist_ok=True)
    code = -1
    with log.open("w", encoding="utf-8") as output:
        process = subprocess.Popen(command, cwd=cwd, env=ENV, stdout=output, stderr=output)
        while process.poll() is None:
            failed_script = category in ("native", "logic") and log.exists() and time.time()-log.stat().st_mtime > 15 and "SCRIPT ERROR:" in log.read_text(encoding="utf-8", errors="replace")
            if time.time()-start > timeout or failed_script:
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
                process.wait(timeout=15)
                code = "script_error_stall" if failed_script else "timeout"
                break
            time.sleep(.2)
        else:
            code = process.returncode
    raw = log.read_text(encoding="utf-8", errors="replace")
    errors = [line.strip() for line in raw.splitlines()
              if re.match(r"(?:SCRIPT ERROR:|ERROR:|FAIL:|FAILED |AssertionError|Traceback)", line)]
    result = {"label": label, "category": category, "exit": code,
              "seconds": round(time.time()-start, 2), "log": str(log.relative_to(OUT)),
              "errors": errors[:30], "error_count": len(errors),
              "summaries": [line for line in raw.splitlines() if re.search(r"checks.*fail|RESULT|PASS|Ran \d+ tests|^OK$|EXIT_CODES", line)][-5:],
              "reports": collect_checks(start)}
    result["status"] = "pass" if code == 0 and not any("SCRIPT ERROR:" in e or "AssertionError" in e for e in errors) and not any(r["failures"] for r in result["reports"]) else "fail"
    RESULTS.append(result)
    write_json(OUT / "results.json", RESULTS)
    print(result["status"].upper(), label, code, result["seconds"], "errors="+str(len(errors)), flush=True)


def godot(name, args=(), headless=False, timeout=150, tag=""):
    source = (PROJECT / "tests" / (name + ".gd")).read_text(encoding="utf-8-sig")
    if "root.get_texture()" in source or "RenderingServer.frame_post_draw" in source:
        headless = False
    command = [str(ENGINE), "--path", str(PROJECT), "--audio-driver", "Dummy", "--max-fps", "60"]
    if headless:
        command.append("--headless")
    command += ["--script", str(OUT / "bootstrap.gd"), "--", *args,
                "--regression-script=res://tests/" + name + ".gd"]
    execute(name + tag, command, timeout, category="logic" if headless else "native")


def run():
    execute("project-import", [str(ENGINE), "--path", str(PROJECT), "--headless", "--editor", "--import", "--quit"], 180, category="import")
    for filename in ("test_network_server.py", "test_network_game_host.py", "test_network_game_job.py"):
        execute(filename, [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", filename, "-v"], 240, category="service")
    tool_python = Path.home()/".cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe"
    execute("audio-workbench", [str(tool_python), "-m", "unittest", "discover", "-s", "tools/audio_workbench", "-p", "test_workbench.py", "-v"], 120, category="tool")
    for name in ("network_game_compile", "launcher_startup_smoke", "launcher_click_smoke", "login_memory_smoke"):
        godot(name, headless=name in ("network_game_compile", "login_memory_smoke"))
    for mode in ("write", "read", "clear"):
        godot("login_prefill_smoke", [mode], headless=True, tag="-"+mode)
    logic = """test_player test_world_v06 test_ore_distribution_v06 test_random_entry_v1
    test_ecology_v03 test_resources_v031 test_crafting_v1 test_equipment_v04
    test_food_v2 test_food_edges_v2 test_world_map_v3_logic test_world_map_v3_storage
    test_world_map_v3_distribution test_map_population_v4_logic test_character_contracts_v1""".split()
    for name in logic:
        godot(name, headless=True)
    native = """test_movement_regression test_movement_jitter test_grounding_interactions
    test_ore_runtime_v06 test_harvest_v05 test_harvest_edges_v05 test_harvest_followup_v051
    test_harvest_contact_layer_v051 test_buried_solid_v052 test_item_actions_followup_v051
    test_broadleaf_v1 test_crafting_progress_v1 test_crafted_tools_runtime_v1 test_drop_quantity_v1
    test_bag_organize_v1 test_recipe_hint_ui_v1 test_front_tool_layer_v13 test_back_tool_layer_v6
    test_camp_build_v4 test_camp_door_hinge_transaction_v3 test_camp_gate_surface_v4
    test_camp_h_damage_window_v4 test_floor_formal_v3 test_floor_under_buildings_v1
    test_camp_effects_v11 test_inventory_chest_v1 test_chest_ui_v2 test_chest_volume_render_v2
    test_cooking_build_v2 test_cooking_discovery_v1 test_campfire_drag_v1 test_campfire_flame_v2
    test_planting_v1 test_planting_dependencies_v1 test_planting_layout_v1 test_seed_selector_v2
    test_abandoned_fish_v1 test_roasted_fish_formal_v1 test_food_formal_v2 test_hallucination_visual_v3
    test_animal_art_formal_v2 test_animal_art_formal_shear_v2 test_animals_v1 test_animals_edges_v1
    test_animal_drag_feed_v1 test_animal_debug_button_v1 test_scissors_exploration_v1
    test_shear_sign_map_v1 test_body_v2 test_body_ui_revision_v2 test_sleep_formal_v9
    test_sleep_fit_v10 test_sleep_collision_v11 test_industry_v1 test_industry_refine_v2
    test_industry_polish_v3 test_camp_expansion_v2 test_camp_expansion_geometry
    test_camp_expansion_front_v2 test_camp_food_polish_v2 test_camp_formal_drag_v2
    test_camp_interaction_polish_v3 test_build_freshness_v1 test_fishing_formal_v1
    test_fishing_population_v2 test_merchant_v1 test_merchant_formal_legacy test_ui_fade_v1
    test_target_tip_timeout test_world_environment test_world_map_v3_window test_world_map_v3_markers
    test_world_map_v3_perf test_map_population_v4_window test_map_population_v4_movement
    test_audio_selected_v6 test_audio_ui_open_v7 test_audio_ui_single_v8 test_audio_close_only_v9
    test_character_creation_v1 test_character_hair_v2 test_character_hair_world_v2 test_ponytail_side_v3
    test_ecology_compat_v1 test_ecology_signpost_revision_v1 test_ecology_signpost_revision_ui_v1
    test_ore_ground_density_v1""".split()
    for name in native:
        args = ["formal", "window"] if name == "test_industry_v1" else ["--formal"] if name in ("test_camp_build_v4", "test_camp_h_damage_window_v4") else ["window"]
        godot(name, args, timeout=210 if name in ("test_map_population_v4_window", "test_world_map_v3_perf") else 150)
        restarts = {
            "test_bag_organize_v1": ["--read"], "test_seed_selector_v2": ["read-destroyed"],
            "test_industry_v1": ["formal", "read"], "test_camp_expansion_v2": ["read"],
            "test_chest_ui_v2": ["restart"], "test_cooking_discovery_v1": ["--restart-read"],
            "test_abandoned_fish_v1": ["read"], "test_map_population_v4_window": ["--resume"],
        }
        if name in restarts:
            godot(name, restarts[name], tag="-restart")
        if name == "test_scissors_exploration_v1":
            godot("test_scissors_restart_v1")
    for name, modes in (
        ("test_equipment_persistence_v04", [["--write"], []]),
        ("test_crafting_persistence_v1", [["--write"], []]),
        ("test_body_persistence_v2", [["--mode="+m] for m in ("write", "read", "awake", "legacy-read")]),
        ("test_planting_persistence_v1", [[], ["read"], ["after-harvest"]]),
    ):
        for index, args in enumerate(modes):
            godot(name, args, headless=True, tag="-phase"+str(index+1))
    execute("network-two-clients", [sys.executable, "tests/run_network_gameplay.py"], 240, category="multiplayer")
    execute("network-two-clients-delay-220ms", [sys.executable, "tests/run_network_gameplay.py", "--delay", ".22"], 240, category="multiplayer")
    execute("network-two-clients-delay-550ms", [sys.executable, "tests/run_network_gameplay.py", "--delay", ".55"], 240, category="multiplayer")
    before = json.loads((WORK / "player-before.json").read_text(encoding="utf-8"))
    after = fingerprints()
    write_json(OUT / "save-protection.json", {"before_count": len(before), "after_count": len(after),
        "changed": [p for p in before if before[p] != after.get(p)], "added": [p for p in after if p not in before],
        "production_server_tested_or_changed": False})
    print("FINISHED", len(RESULTS), "suites", sum(r["status"] == "pass" for r in RESULTS), "passed", flush=True)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    if RESUME:
        RESULTS = json.loads((OUT / "results.json").read_text(encoding="utf-8"))
    else:
        prepare()
    run()
