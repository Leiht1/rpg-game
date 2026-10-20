"""Ownership crops only; no drawing, recolouring or generated art replacement."""
from pathlib import Path
from PIL import Image
import json

root = Path(__file__).resolve().parent
image = Image.open(root / 'generated/generated.png')
w, h = image.size
regions = {'rod': (0, 0, w//2, h), 'float': (w//2, 0, w, h//2), 'fish': (w//2, h//2, w, h)}
out = root / 'owned'
out.mkdir(exist_ok=True)
for name, bounds in regions.items():
    image.crop(bounds).save(out / f'{name}.png')
(root / 'ownership.json').write_text(json.dumps({'source_size': [w, h], 'regions': regions}, indent=2), encoding='utf-8')
print(json.dumps({'source_size': [w, h], 'regions': regions}))
