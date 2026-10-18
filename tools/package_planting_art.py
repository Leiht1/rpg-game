from pathlib import Path
from PIL import Image
import json
r=Path(__file__).resolve().parents[1]
raw=Image.open(r/'art/planting-v1/generation/generated.png').convert('RGB')
# Actual ownership boundaries from visual inspection; the model did not honor equal columns.
xs=[0,340,628,940,1254];ys=[0,314,622,918,1254]
sheet=Image.new('RGB',(1536,1536),(255,0,255))
for y in range(4):
 for x in range(4):
  cell=raw.crop((xs[x],ys[y],xs[x+1],ys[y+1]))
  sheet.paste(cell,(x*384+(384-cell.width)//2,y*384+384-cell.height-20))
sheet.save(r/'art/planting-v1/ownership-sheet.png')
(r/'art/planting-v1/ownership.json').write_text(json.dumps(dict(x=xs,y=ys,reason='Preserve whole subjects across nonuniform generated grid; no component deletion or redraw.')),encoding='utf8')
