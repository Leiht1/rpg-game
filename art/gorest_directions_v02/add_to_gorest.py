"""Add only three preview assets and preserve all existing Gorest library content."""
from datetime import datetime, timezone
from pathlib import Path
import copy
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parent
GOREST = Path(r"C:\Users\HT\Documents\Codex\2026-10-15\https-github-com-0x0funky-agent-sprite\outputs\gorest-2d-animation-spritesheet-generator-main")
GENERATED = GOREST / "public/generated"
LIBRARY_PATH = GENERATED / "game_asset_library.json"
before_bytes = LIBRARY_PATH.read_bytes()
before = json.loads(before_bytes)
library = copy.deepcopy(before)
backup = ROOT / "gorest_library.before.json"
if backup.exists():
    raise SystemExit("Library backup exists; do not replace an earlier backup or duplicate entries.")
now = datetime.now(timezone.utc).isoformat()
new_assets = []
metadata_fields = ["frameCount", "frames", "proportionPolicy", "normalization", "rootAnchorPolicy",
                   "globalScale", "cellSize", "frameSize", "sheetSize", "sourceSheetSize", "sourceCells",
                   "sourceFrameOrder", "phaseOrderPolicy", "gridDetection", "safePadding", "safeFramePolicy",
                   "sourceEdgePolicy", "sourceEdgeRisks", "frameBboxes", "rootAnchors"]

for direction, label, semantic in [("back", "背面", "up"), ("right", "右侧", "right"), ("left", "左侧", "left")]:
    stem = f"windrest_hero_{direction}_walk_v02"
    asset_id, clip_id = f"asset_{stem}", f"clip_{stem}"
    if any(a.get("id") == asset_id for a in before["assets"]):
        raise SystemExit(f"Already present: {asset_id}")
    out = ROOT / direction
    meta = json.loads((out / "normalization.json").read_text(encoding="utf-8"))
    qa = json.loads((out / "qa.json").read_text(encoding="utf-8"))
    assert qa["uniqueFrameCount"] == 8 and not qa["sourceEdgeRisks"]
    assert qa["minimumAlphaMargin"] >= 24
    assert qa.get("visualReview", {}).get("acceptedForPreview") is True, "Review complete gait before publishing."
    source_direction = "right" if direction == "left" else direction
    source_takes = meta.get("sourceTakes", [meta["sourceTake"]])
    source_take = source_takes[0]
    raw = ROOT / source_direction / source_take / "generated.png"
    job_path = raw.parent / "job.json"
    job = json.loads(job_path.read_text(encoding="utf-8"))
    prompts = {"take2": "right_correction_prompt.txt", "take3_halfcycle": "right_halfcycle_prompt.txt"}
    prompt_path = ROOT / prompts.get(source_take, f"{source_direction}_prompt.txt")
    href = f"/generated/{stem}.png"
    source_href = f"/generated/sources/{stem}/raw.png"
    title = f"风栖原野主角 · {label}行走（8帧）"
    sprite = {key: copy.deepcopy(meta[key]) for key in metadata_fields}
    sprite.update({
        "id": f"sprite_{stem}", "characterName": "风栖原野主角", "description": f"与已确认正面一致的{label}行走预览，未接入游戏。",
        "style": "warm bright hand-painted cartoon matching approved Gorest front",
        "prompt": prompt_path.read_text(encoding="utf-8"), "createdTime": now, "isPreset": False,
        "spritesheetPng": href, "sourceMasterPng": source_href, "generationMode": "spritesheet",
        "gridColumns": 4, "fps": 8, "loop": True, "sourceEdgeRiskCount": 0,
        "artSourcePolicy": "Generated complete character bitmap poses. Only chroma removal, complete-frame reordering, global uniform scaling, registration, packing and preview. Left reflects each complete right frame per project contract.",
        "qualityPolicy": "Visually reviewed preview; no claim of game acceptance or perfectly seamless motion.",
        "provenance": {"route": "local:codex-cli", "requestedModel": job["requestedModel"],
                       "underlyingImageModel": "not exposed", "rawSheet": source_href,
                       "rawSha256": hashlib.sha256(raw.read_bytes()).hexdigest(),
                       "sourceDirection": source_direction, "sourceTake": source_take,
                       "status": "preview_not_game_integrated"}
    })
    if direction == "left":
        sprite["derivation"] = meta["derivation"]
    for field in ("sourceTakes", "sourceGlobalScales", "sourceSheetSizes", "sourceFrameRefs"):
        if field in meta:
            sprite[field] = meta[field]
    sprite["provenance"]["sources"] = []
    binding = {"actionName": "walk", "triggerType": "auto", "triggerValue": "preview-loop",
               "gameState": f"windrest.preview.{direction}_walk", "notes": "Preview only, no gameplay scene binding."}
    new_assets.append({
        "id": asset_id, "name": title, "role": "player", "confirmed": False,
        "savedTime": now, "updatedTime": now, "sprite": sprite,
        "animations": [{"id": clip_id, "name": title, "actionName": "walk", "direction": semantic,
                        "sprite": sprite, "binding": binding, "loop": True, "fps": 8}],
        "defaultAnimationId": clip_id, "binding": binding,
        "tags": ["windrest", "hero", direction, "walk", "preview", "not-game-integrated"]
    })
    source_dir = GENERATED / "sources" / stem
    source_dir.mkdir(parents=True, exist_ok=True)
    for src, name in [(raw, "raw.png"), (job_path, "job.json"), (prompt_path, "prompt.txt"),
                      (out / "normalization.json", "normalization.json"), (out / "qa.json", "qa.json"),
                      (ROOT / "references/approved_front_look.png", "approved_front_look.png"),
                      (ROOT.parent / "reference/hero.png", "identity_reference.png")]:
        shutil.copy2(src, source_dir / name)
    for take in source_takes:
        take_dir = ROOT / source_direction / take
        take_prompt = ROOT / prompts.get(take, f"{source_direction}_prompt.txt")
        for src, name in [(take_dir / "generated.png", f"raw_{take}.png"),
                          (take_dir / "job.json", f"job_{take}.json"), (take_prompt, f"prompt_{take}.txt")]:
            shutil.copy2(src, source_dir / name)
        sprite["provenance"]["sources"].append({
            "take": take, "sheet": f"/generated/sources/{stem}/raw_{take}.png",
            "rawSha256": hashlib.sha256((take_dir / "generated.png").read_bytes()).hexdigest(),
            "job": f"/generated/sources/{stem}/job_{take}.json"})
    shutil.copy2(out / f"{direction}_walk_sheet.png", GENERATED / f"{stem}.png")

backup.write_bytes(before_bytes)
library["assets"] = new_assets + before["assets"]
library["updatedTime"] = now
LIBRARY_PATH.write_text(json.dumps(library, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
report = {
    "libraryPath": str(LIBRARY_PATH), "addedAssetIds": [a["id"] for a in new_assets],
    "previousLibrarySha256": hashlib.sha256(before_bytes).hexdigest(),
    "currentLibrarySha256": hashlib.sha256(LIBRARY_PATH.read_bytes()).hexdigest(),
    "existingAssetsUnchanged": before["assets"] == library["assets"][3:],
    "otherLibraryDataUnchanged": all(before.get(k) == library.get(k) for k in set(before) - {"assets", "updatedTime"})
}
assert report["existingAssetsUnchanged"] and report["otherLibraryDataUnchanged"]
(ROOT / "gorest_library_change.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(report, ensure_ascii=False))
