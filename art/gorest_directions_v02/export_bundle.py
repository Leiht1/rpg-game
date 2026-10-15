"""Export the four reviewed bitmap sequences and verify lossless PNG round trips."""
from pathlib import Path
import hashlib
import json
import zipfile

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parent
FRONT = ROOT.parent / "gorest_walk_trial_v01"
atlas = Image.new("RGBA", (1024, 2048))
manifest = {"purpose": "Four-direction walk previews only; not integrated into Godot",
            "frameSize": [256, 256], "framesPerDirection": 8, "fps": 8,
            "gridColumns": 4, "rowsPerDirection": 2,
            "directionOrder": ["front", "back", "left", "right"],
            "atlasSize": [1024, 2048], "loop": True,
            "leftPolicy": "Mirror each complete right-facing frame, retaining chronological order",
            "registration": "Gorest fixed upper-body centroid; not the runtime game's foot origin",
            "directions": {}}
zip_files = []
checks = []
for row, direction in enumerate(manifest["directionOrder"]):
    out = FRONT if direction == "front" else ROOT / direction
    sheet_path = out / f"{direction}_walk_sheet.png"
    sheet = Image.open(sheet_path).convert("RGBA")
    assert sheet.size == (1024, 512)
    meta = json.loads((out / "normalization.json").read_text(encoding="utf-8"))
    atlas.paste(sheet, (0, row * 512))
    zip_files.append((sheet_path, f"{direction}/{sheet_path.name}"))
    for i in range(8):
        frame_path = out / "frames" / f"{direction}_walk_{i:02d}.png"
        frame = Image.open(frame_path).convert("RGBA")
        actual = sheet.crop(((i % 4) * 256, (i // 4) * 256, (i % 4 + 1) * 256, (i // 4 + 1) * 256))
        assert actual.tobytes() == frame.tobytes(), f"Sheet/frame mismatch {direction} {i}"
        assert frame.getchannel("A").getextrema() == (0, 255)
        zip_files.append((frame_path, f"{direction}/frames/{frame_path.name}"))
        checks.append({"direction": direction, "frame": i, "sha256": hashlib.sha256(frame.tobytes()).hexdigest()})
    gif_path = out / f"{direction}_walk_preview.gif"
    gif = Image.open(gif_path)
    assert gif.n_frames == 8
    durations = []
    for i in range(gif.n_frames):
        gif.seek(i)
        durations.append(gif.info["duration"])
    assert sum(durations) == 1000
    zip_files.append((gif_path, f"{direction}/{gif_path.name}"))
    manifest["directions"][direction] = {
        "atlasOffset": [0, row * 512], "sheet": f"{direction}/{sheet_path.name}",
        "globalScale": meta["globalScale"], "sourceFrameOrder": meta["sourceFrameOrder"],
        "rootAnchors": meta["rootAnchors"], "pngSha256": hashlib.sha256(sheet_path.read_bytes()).hexdigest(),
        "gifDurationsMs": durations}

atlas_path = ROOT / "four_directions_sheet.png"
atlas.save(atlas_path)
readback = Image.open(atlas_path).convert("RGBA")
assert readback.tobytes() == atlas.tobytes()
right = Image.open(ROOT / "right/right_walk_sheet.png").convert("RGBA")
left = Image.open(ROOT / "left/left_walk_sheet.png").convert("RGBA")
for i in range(8):
    box = ((i % 4) * 256, (i // 4) * 256, (i % 4 + 1) * 256, (i // 4 + 1) * 256)
    assert right.crop(box).transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes() == left.crop(box).tobytes()
manifest_path = ROOT / "export_manifest.json"
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
checks_path = ROOT / "export_verification.json"
checks_path.write_text(json.dumps({"status": "pass", "pngRoundTrips": 32, "rgbaFrames": 32,
                                   "leftIsExactWholeFrameMirror": True, "gifOneSecondLoops": 4,
                                   "atlasRoundTrip": True, "frameHashes": checks}, indent=2) + "\n", encoding="utf-8")
zip_files += [(atlas_path, atlas_path.name), (manifest_path, manifest_path.name),
              (ROOT / "four_directions_preview.gif", "four_directions_preview.gif")]
with zipfile.ZipFile(ROOT / "hero_four_directions.zip", "w", compression=zipfile.ZIP_DEFLATED) as bundle:
    for source, destination in zip_files:
        bundle.write(source, destination)
with zipfile.ZipFile(ROOT / "hero_four_directions.zip") as bundle:
    assert bundle.testzip() is None
print(json.dumps({"status": "pass", "frames": 32, "atlasSize": list(atlas.size), "zipFileCount": len(zip_files)}))
