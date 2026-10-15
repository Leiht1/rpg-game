"""Package generated whole-character frames; never redraw or deform character art."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
sheet = Image.open(ROOT / "front_walk_sheet.png").convert("RGBA")
meta = json.loads((ROOT / "normalization.json").read_text(encoding="utf-8"))
width, height = meta["frameSize"]
count = meta["frameCount"]
rows = count // 4
fps = 8 if count == 8 else 12
frames = [sheet.crop((c * width, r * height, (c + 1) * width, (r + 1) * height))
          for r in range(rows) for c in range(4)]
frame_dir = ROOT / "frames"
frame_dir.mkdir(exist_ok=True)
for i, frame in enumerate(frames):
    frame.save(frame_dir / f"front_walk_{i:02d}.png")

preview_frames = []
for frame in frames:
    preview = Image.new("RGB", (512, 288), "#f6efdf")
    draw = ImageDraw.Draw(preview)
    draw.rectangle((256, 0, 511, 287), fill="#30453c")
    preview.paste(frame, (0, 16), frame)
    preview.paste(frame, (256, 16), frame)
    preview_frames.append(preview)
durations = [round((i + 1) * 1000 / fps / 10) * 10 - round(i * 1000 / fps / 10) * 10 for i in range(count)]
preview_frames[0].save(ROOT / "front_walk_preview.gif", save_all=True,
                       append_images=preview_frames[1:], loop=0, duration=durations,
                       optimize=False, disposal=2)
preview_frames[0].save(ROOT / "front_walk_preview.webp", save_all=True,
                       append_images=preview_frames[1:], loop=0, duration=round(1000 / fps), lossless=True)

contact = Image.new("RGB", (4 * width, rows * (height + 24)), "#f6efdf")
draw = ImageDraw.Draw(contact)
for i, frame in enumerate(frames):
    x, y = (i % 4) * width, (i // 4) * (height + 24)
    draw.text((x + 12, y + 7), f"{i + 1:02d}", fill="#405346")
    contact.paste(frame, (x, y + 24), frame)
contact.save(ROOT / "front_walk_contact.png")

arrays = [np.asarray(f).astype(np.float32) / 255 for f in frames]
premultiplied = [a[:, :, :3] * a[:, :, 3:] for a in arrays]
differences = [float(np.mean(np.abs(premultiplied[(i + 1) % count] - premultiplied[i]))) for i in range(count)]
boxes = [f.getchannel("A").getbbox() for f in frames]
heights = [b[3] - b[1] for b in boxes]
report = {
    "status": "needs_visual_review",
    "frameCount": count,
    "uniqueFrameCount": len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames}),
    "frameSize": [width, height],
    "sheetSize": list(sheet.size),
    "fps": fps,
    "gifCycleMs": sum(durations),
    "alphaBboxes": boxes,
    "minimumAlphaMargin": min(min(b[0], b[1], width - b[2], height - b[3]) for b in boxes),
    "fullBodyHeightCV": float(np.std(heights) / np.mean(heights)),
    "adjacentPremultipliedMAE": differences,
    "loopSeamToMedianAdjacentRatio": differences[-1] / float(np.median(differences[:-1])),
    "sourceEdgeRisks": meta["sourceEdgeRisks"],
    "globalScale": meta["globalScale"],
    "registration": meta["rootAnchorPolicy"],
    "scope": "experiment only, no game integration",
    "limitations": ["Numerical checks do not establish anatomy, gait, identity stability, or a seamless loop."]
}
(ROOT / "qa.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({k: v for k, v in report.items() if k not in ("alphaBboxes", "adjacentPremultipliedMAE")}, ensure_ascii=False))
