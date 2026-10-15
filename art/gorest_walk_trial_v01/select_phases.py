"""Reorder only complete generated bitmap frames into alternating gait phases."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parent
source = Image.open(root / "take2" / "normalized_source_order.png").convert("RGBA")
meta = json.loads((root / "take2" / "normalization_source_order.json").read_text(encoding="utf-8"))
order = [0, 5, 6, 7, 3, 2, 1, 4]
size = meta["cellSize"]
sheet = Image.new("RGBA", source.size)
for out_index, source_index in enumerate(order):
    sx, sy = source_index % 4 * size, source_index // 4 * size
    frame = source.crop((sx, sy, sx + size, sy + size))
    sheet.paste(frame, (out_index % 4 * size, out_index // 4 * size))
sheet.save(root / "front_walk_sheet.png")
for field in ("sourceCells", "frameBboxes", "rootAnchors"):
    meta[field] = [meta[field][i] for i in order]
meta["sourceFrameOrder"] = order
meta["phaseOrderPolicy"] = "Reordered complete drawn frames only; no mirroring, local edits, warping, or interpolation."
meta["normalization"] += "_whole_frame_phase_reorder"
(root / "normalization.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({"frameCount": len(order), "sourceFrameOrder": order, "sourceEdgeRisks": meta["sourceEdgeRisks"], "globalScale": meta["globalScale"]}))
