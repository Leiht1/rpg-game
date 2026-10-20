"""Ownership splitting and publication only; no drawn art replacement."""
from pathlib import Path
from PIL import Image
import json

root = Path(__file__).resolve().parent
image = Image.open(root / 'generated/generated.png')
w, h = image.size
regions = {'coin': (0, 0, w//2, h), 'locked_chest': (w//2, 0, w, h)}
(root / 'owned').mkdir(exist_ok=True)
for name, bounds in regions.items():
    image.crop(bounds).save(root / 'owned' / f'{name}.png')
(root / 'ownership.json').write_text(json.dumps({'source_size': [w, h], 'regions': regions}, indent=2), encoding='utf-8')
