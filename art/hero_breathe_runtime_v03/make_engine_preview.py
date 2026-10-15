"""Assemble four fixed-position Godot pose captures, without changing the art."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
source = ROOT / 'reports/character-godot-poses.png'
sheet = Image.open(source).convert('RGB')
assert sheet.size == (2112, 832)
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 15)
frames = []
for phase in range(4):
    frame = Image.new('RGB', (704, 236), '#e3e9ce')
    draw = ImageDraw.Draw(frame)
    for direction, label in enumerate(['正面', '背面', '右侧', '左侧']):
        x, y = phase * 176, direction * 208
        frame.paste(sheet.crop((x, y, x + 176, y + 208)), (direction * 176, 28))
        draw.text((direction * 176 + 68, 3), label, fill='#374533', font=font)
    frames.append(frame)

# A shared palette avoids GIF palette changes between breathing poses.
palette_source = Image.new('RGB', (704, 236 * 4))
for index, frame in enumerate(frames):
    palette_source.paste(frame, (0, 236 * index))
palette = palette_source.quantize(256, dither=Image.Dither.NONE)
gif_frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
gif_frames[0].save(ROOT / 'reports/character-breathe-godot.gif', save_all=True,
                   append_images=gif_frames[1:], duration=750, loop=0, disposal=2, optimize=False)
frames[0].save(ROOT / 'reports/character-breathe-godot.webp', save_all=True,
               append_images=frames[1:], duration=750, loop=0, lossless=True)
(Path(__file__).parent / 'engine-preview-source.json').write_text(json.dumps({
    'source': 'reports/character-godot-poses.png',
    'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    'directions': ['front', 'back', 'right', 'left'],
    'source_idle_columns': [0, 1, 2, 3],
    'cell_size': [176, 208], 'frame_duration_ms': 750,
    'total_duration_ms': 3000,
    'method': 'Godot fixed-position pose samples assembled for preview, not a continuous gameplay recording',
    'art_edits': False
}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Godot breathing preview: four directions, four poses, 3000 ms.')
