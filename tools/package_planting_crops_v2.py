"""Preserve all generated subjects using inspected ownership; no redrawing or largest-component loss."""
from pathlib import Path
import json,shutil,hashlib,sys
from PIL import Image
r=Path(__file__).resolve().parents[1]
base=r/'art/planting-crops-v2'
if '--publish' not in sys.argv:
 raw=Image.open(base/'generation/generated.png').convert('RGB')
 xs=[0,420,840,1254];ys=[0,360,736,1176]
 sheet=Image.new('RGB',(1536,1536),(255,0,255))
 for y in range(3):
  for x in range(3):
   cell=raw.crop((xs[x],ys[y],xs[x+1],ys[y+1]))
   sheet.paste(cell,(x*512+(512-cell.width)//2,y*512+512-cell.height-24))
 sheet.save(base/'ownership-sheet.png')
 (base/'ownership.json').write_text(json.dumps({'x':xs,'y':ys,'note':'Only empty magenta bottom margin excluded; all whole plant drawings retained.'},indent=2),encoding='utf8')
else:
 out=r/'prototypes/planting-crops-v2/final';out.mkdir(parents=True,exist_ok=True)
 files={}
 for stage in range(3):
  for col,crop in enumerate(['carrot','potato','cabbage']):
   src=base/f'processed-v2/sheet-{stage*3+col+1}.png';dst=out/f'{crop}_{stage}.png'
   shutil.copyfile(src,dst);files[dst.name]=hashlib.sha256(dst.read_bytes()).hexdigest()
 (out.parent/'provenance.json').write_text(json.dumps({'status':'pending_user','route':'generate2dsprite -> route_media -> local:codex-cli','source':str(base.relative_to(r)),'processing':'inspected ownership, soft chroma key, all components, shared scale; see pipeline-meta.json','files':files},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
