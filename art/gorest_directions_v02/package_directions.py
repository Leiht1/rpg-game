"""Normalize generated whole poses with Gorest, then pack previews; no art drawing."""
from pathlib import Path
import copy
import hashlib
import importlib.util
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
FRONT = ROOT.parent / "gorest_walk_trial_v01"
GOREST = Path(r"C:\Users\HT\Documents\Codex\2026-10-15\https-github-com-0x0funky-agent-sprite\outputs\gorest-2d-animation-spritesheet-generator-main")
SPEC = importlib.util.spec_from_file_location("gorest_normalizer", GOREST / "scripts/normalize_spritesheet.py")
NORMALIZER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NORMALIZER)
SIZE, COUNT, FPS = 256, 8, 8
TAKES = {"back": "take1", "right": "take2"}
DURATIONS = [120, 130] * 4  # GIF uses 10ms ticks: average 8fps, exactly 1s.
FONT = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 18)


def save_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def split(sheet):
    return [sheet.crop(((i % 4) * SIZE, (i // 4) * SIZE,
                        (i % 4 + 1) * SIZE, (i // 4 + 1) * SIZE)) for i in range(COUNT)]


def pack(frames):
    sheet = Image.new("RGBA", (SIZE * 4, SIZE * 2))
    for i, frame in enumerate(frames):
        sheet.paste(frame, ((i % 4) * SIZE, (i // 4) * SIZE))
    return sheet


def save_animation(frames, stem):
    frames[0].save(stem.with_suffix(".gif"), save_all=True, append_images=frames[1:],
                   duration=DURATIONS, loop=0, optimize=False, disposal=2)
    frames[0].save(stem.with_suffix(".webp"), save_all=True, append_images=frames[1:],
                   duration=125, loop=0, lossless=True)


def package(direction, frames, meta):
    out = ROOT / direction
    (out / "frames").mkdir(parents=True, exist_ok=True)
    sheet = pack(frames)
    sheet.save(out / f"{direction}_walk_sheet.png")
    for i, frame in enumerate(frames):
        frame.save(out / "frames" / f"{direction}_walk_{i:02d}.png")
    contact = Image.new("RGB", (1024, 560), "#f6efdf")
    previews = []
    for i, frame in enumerate(frames):
        x, y = (i % 4) * SIZE, (i // 4) * 280
        ImageDraw.Draw(contact).text((x + 12, y + 3), f"{i + 1:02d}", font=FONT, fill="#405346")
        contact.paste(frame, (x, y + 24), frame)
        preview = Image.new("RGB", (512, 288), "#f6efdf")
        ImageDraw.Draw(preview).rectangle((256, 0, 511, 287), fill="#30453c")
        preview.paste(frame, (0, 16), frame)
        preview.paste(frame, (256, 16), frame)
        previews.append(preview)
    contact.save(out / f"{direction}_walk_contact.png")
    save_animation(previews, out / f"{direction}_walk_preview")
    arrays = [np.asarray(f).astype(np.float32) / 255 for f in frames]
    rgb = [a[:, :, :3] * a[:, :, 3:] for a in arrays]
    differences = [float(np.mean(np.abs(rgb[(i + 1) % COUNT] - rgb[i]))) for i in range(COUNT)]
    boxes = [f.getchannel("A").getbbox() for f in frames]
    heights = [b[3] - b[1] for b in boxes]
    qa = {
        "status": "needs_visual_review", "frameCount": COUNT, "fps": FPS,
        "uniqueFrameCount": len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames}),
        "frameSize": [SIZE, SIZE], "sheetSize": list(sheet.size), "gifCycleMs": sum(DURATIONS),
        "alphaBboxes": boxes, "fullBodyHeights": heights,
        "minimumAlphaMargin": min(min(b[0], b[1], SIZE - b[2], SIZE - b[3]) for b in boxes),
        "fullBodyHeightCV": float(np.std(heights) / np.mean(heights)),
        "adjacentPremultipliedMAE": differences,
        "loopSeamToMedianAdjacentRatio": differences[-1] / float(np.median(differences[:-1])),
        "sourceEdgeRisks": meta["sourceEdgeRisks"], "globalScale": meta["globalScale"],
        "registration": meta["rootAnchorPolicy"], "scope": "preview only, no game integration",
        "limitations": ["Numerical checks do not establish anatomy, gait, identity stability or a seamless loop."]
    }
    save_json(out / "normalization.json", meta)
    save_json(out / "qa.json", qa)
    return qa


def complete_right_halfcycle(frames, meta):
    """Join complete poses from two image takes; one uniform scale per source take."""
    out = ROOT / "right"
    half_take = "take3_halfcycle"
    cache = out / "normalization_source_order_take3_halfcycle.json"
    normalized = out / "normalized_source_order_take3_halfcycle.png"
    if not cache.exists():
        half_meta = NORMALIZER.normalize_sheet(
            out / half_take / "generated.png", normalized, 2, 2, SIZE, SIZE,
            "/generated/windrest_hero_right_walk_v02.png",
            safe_padding=24, source_edge_threshold=2, reject_source_edge_touch=True,
            anchor_mode="upper-body")
        save_json(cache, half_meta)
    half_meta = json.loads(cache.read_text(encoding="utf-8"))
    half_sheet = Image.open(normalized).convert("RGBA")
    half_frames = [half_sheet.crop(((i % 2) * SIZE, (i // 2) * SIZE,
                                    (i % 2 + 1) * SIZE, (i // 2 + 1) * SIZE)) for i in range(4)]
    # Match source takes once as groups, never normalize individual frame bboxes.
    height = lambda frame: frame.getchannel("A").getbbox()[3] - frame.getchannel("A").getbbox()[1]
    group_factor = float(np.median([height(f) for f in frames[4:8]]) /
                         np.median([height(f) for f in half_frames]))
    raw_half = NORMALIZER.remove_chroma_key(Image.open(out / half_take / "generated.png"))
    scale = half_meta["globalScale"] * group_factor
    half_frames, half_boxes = [], []
    for cell_box in half_meta["sourceCells"]:
        cell = raw_half.crop(tuple(cell_box))
        bbox = cell.getchannel("A").getbbox()
        anchor = NORMALIZER.upper_body_anchor(cell.getchannel("A"), bbox)
        sprite = cell.crop(bbox)
        w, h = round(sprite.width * scale), round(sprite.height * scale)
        sprite = sprite.resize((w, h), Image.Resampling.LANCZOS)
        x = round(128 - (anchor[0] - bbox[0]) * scale)
        y = round(78.08 - (anchor[1] - bbox[1]) * scale)
        frame = Image.new("RGBA", (SIZE, SIZE))
        frame.alpha_composite(sprite, (x, y))
        half_frames.append(frame)
        half_boxes.append([x, y, w, h])
    half_meta["gorestOriginalGlobalScale"] = half_meta["globalScale"]
    half_meta["crossTakeGroupScaleFactor"] = group_factor
    half_meta["crossTakeScalePolicy"] = "One additional uniform factor for all four poses of this source take, matched to the other take's median height; rendered once from raw pixels."
    half_meta["globalScale"], half_meta["frameBboxes"] = scale, half_boxes
    result = copy.deepcopy(meta)
    result["sourceNormalizations"] = {"take2": copy.deepcopy(meta), half_take: half_meta}
    result["sourceTakes"] = [half_take, "take2"]
    result["sourceTake"] = "take3_halfcycle+take2"
    result["sourceGlobalScales"] = {half_take: half_meta["globalScale"], "take2": meta["globalScale"]}
    result["globalScale"] = None  # Each source take has a different image resolution.
    result["sourceSheetSizes"] = {half_take: half_meta["sourceSheetSize"], "take2": meta["sourceSheetSize"]}
    result["sourceSheetSize"] = None
    result["sourceFrameOrder"] = [0, 1, 2, 3, 8, 9, 10, 11]
    result["sourceFrameRefs"] = ([{"take": half_take, "frame": i} for i in range(4)] +
                                 [{"take": "take2", "frame": i} for i in range(4, 8)])
    for key in ("sourceCells", "frameBboxes", "rootAnchors"):
        result[key] = half_meta[key] + meta[key][4:8]
    result["normalization"] = "one_global_uniform_scale_per_source_take_fixed_upper_body_anchor_complete_pose_assembly"
    result["phaseOrderPolicy"] = "Four complete opposite-half poses from take3, followed by four complete poses from take2; no limb edits or per-frame scaling."
    result["sourceEdgeRisks"] = half_meta["sourceEdgeRisks"] + meta["sourceEdgeRisks"]
    # Final Gorest wrappers crop the repacked eight-frame bitmap, not either source sheet.
    return half_frames + frames[4:8], result


def main():
    config_path = ROOT / "phase_orders.json"
    if not config_path.exists():
        save_json(config_path, {"back": list(range(8)), "right": list(range(8))})
    orders = json.loads(config_path.read_text(encoding="utf-8"))
    all_frames, reports, metas = {}, {}, {}
    all_frames["front"] = split(Image.open(FRONT / "front_walk_sheet.png").convert("RGBA"))
    for direction in ("back", "right"):
        out = ROOT / direction
        take = TAKES[direction]
        raw = out / take / "generated.png"
        href = f"/generated/windrest_hero_{direction}_walk_v02.png"
        suffix = "" if take == "take1" else f"_{take}"
        normalized = out / f"normalized_source_order{suffix}.png"
        cached = out / f"normalization_source_order{suffix}.json"
        if not cached.exists():
            meta = NORMALIZER.normalize_sheet(raw, normalized, 4, 2, SIZE, SIZE, href,
                                               safe_padding=24, source_edge_threshold=2,
                                               reject_source_edge_touch=True, anchor_mode="upper-body")
            save_json(cached, meta)
        original = json.loads(cached.read_text(encoding="utf-8"))
        meta = copy.deepcopy(original)
        meta["sourceTake"] = take
        source_frames = split(Image.open(normalized).convert("RGBA"))
        order = orders[direction]
        assert sorted(order) == list(range(8)), "Only reorder all eight complete source poses once."
        frames = [source_frames[i] for i in order]
        for key in ("sourceCells", "frameBboxes", "rootAnchors"):
            meta[key] = [original[key][i] for i in order]
        meta["sourceFrameOrder"] = order
        meta["phaseOrderPolicy"] = "Eight complete generated poses in visually reviewed gait order; no partial-body edits."
        if direction == "right":
            frames, meta = complete_right_halfcycle(frames, meta)
        all_frames[direction], metas[direction] = frames, meta
        reports[direction] = package(direction, frames, meta)
    # Project contract: reflect each complete frame, retaining chronological order.
    all_frames["left"] = [f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in all_frames["right"]]
    left = copy.deepcopy(metas["right"])
    left["frames"] = [s.replace("_right_walk_", "_left_walk_") for s in left["frames"]]
    left["derivation"] = {"operation": "mirror_each_complete_right_frame_horizontally",
                          "source": "../right/right_walk_sheet.png",
                          "sourceSha256": hashlib.sha256((ROOT / "right/right_walk_sheet.png").read_bytes()).hexdigest(),
                          "frameOrderReversed": False}
    left["frameBboxes"] = [[SIZE - (x + w), y, w, h] for x, y, w, h in left["frameBboxes"]]
    left["rootAnchors"] = [[SIZE - x, y] for x, y in left["rootAnchors"]]
    metas["left"] = left
    reports["left"] = package("left", all_frames["left"], left)
    labels = [("front", "正面 · 已确认"), ("back", "背面"), ("left", "左侧"), ("right", "右侧")]
    overview = []
    for i in range(COUNT):
        panel = Image.new("RGB", (512, 568), "#f6efdf")
        draw = ImageDraw.Draw(panel)
        for index, (direction, label) in enumerate(labels):
            x, y = (index % 2) * 256, (index // 2) * 284
            if index in (1, 2):
                draw.rectangle((x, y, x + 255, y + 283), fill="#e7eddf")
            draw.text((x + 16, y + 7), label, font=FONT, fill="#405346")
            panel.paste(all_frames[direction][i], (x, y + 28), all_frames[direction][i])
        overview.append(panel)
    save_animation(overview, ROOT / "four_directions_preview")
    overview[0].save(ROOT / "four_directions_still.png")
    save_json(ROOT / "qa_summary.json", reports)
    print(json.dumps({d: {k: r[k] for k in ("uniqueFrameCount", "minimumAlphaMargin", "fullBodyHeights", "fullBodyHeightCV", "loopSeamToMedianAdjacentRatio")} for d, r in reports.items()}, ensure_ascii=False))


if __name__ == "__main__":
    main()
