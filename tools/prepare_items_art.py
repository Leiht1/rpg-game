from PIL import Image
from pathlib import Path
import json
raw=Image.open('art/items-v03/candidate-01/generated.png').convert('RGBA')
# Ownership rectangles measured from actual returned composition; no redrawing.
xs=[0,278,522,778,1027,1270,1536];ys=[0,300,520,760,1024]
out=Image.new('RGBA',(1536,1024),(255,0,255,255))
rects=[]
for y in range(4):
 for x in range(6):
  box=(xs[x],ys[y],xs[x+1],ys[y+1]);part=raw.crop(box);part.thumbnail((226,226),Image.Resampling.LANCZOS)
  out.paste(part,(x*256+(256-part.width)//2,y*256+(256-part.height)//2))
  rects.append(box)
out.save('art/items-v03/ownership-sheet.png')
Path('art/items-v03/ownership.json').write_text(json.dumps(dict(source='candidate-01/generated.png',rectangles=rects,reason='Raw model rows cross uniform grid boundaries; regrid by visual ownership, preserve every subject.'),indent=2),encoding='utf-8')
