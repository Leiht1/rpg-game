"""Remove the complex engraving layer; reuse only the actual lamp glyph."""
from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
out=Path('assets/exploration/mine-clues-v4');out.mkdir(parents=True,exist_ok=True)
bg=Image.open('assets/exploration/mine-v1/interior.png').convert('RGBA')
config=json.loads(Path('data/mine_puzzle.json').read_text(encoding='utf-8-sig'))
files={}
for i,(wx,wy) in enumerate(config['wall_art']):
 cx=round(bg.width/2+wx*bg.width/2000);cy=round(bg.height/2+wy*bg.width/2000)
 region=(max(0,cx-87),max(0,cy-65),min(bg.width,cx+87),min(bg.height,cy+65))
 near=bg.crop(region).resize((1120,832),Image.Resampling.LANCZOS)
 glyph_path=Path(f'assets/exploration/mine-scene-v2/glyph-{i}.png')
 glyph=Image.open(glyph_path).convert('RGBA');glyph.thumbnail((260,260),Image.Resampling.LANCZOS)
 near.alpha_composite(glyph,((1120-glyph.width)//2,300-glyph.height//2))
 yy,xx=np.mgrid[0:832,0:1120];distance=np.minimum(np.minimum(xx,1119-xx),np.minimum(yy,831-yy));mask=np.clip(distance/72,0,1)
 a=np.array(near);a[:,:,3]=(mask*255).astype('uint8');dest=out/f'closeup-{i}.png';Image.fromarray(a).save(dest)
 files[dest.name]={'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'wall_region':region,'only_overlay':str(glyph_path),'glyph_sha256':hashlib.sha256(glyph_path.read_bytes()).hexdigest()}
(out/'provenance.json').write_text(json.dumps({'art_source':'existing','processing':'Unchanged cave wall sample + exactly one matching lamp glyph; complex etch layer removed; no new generation','files':files},ensure_ascii=False,indent=2),encoding='utf-8')
