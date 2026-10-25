from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
p=Path('art/mine-puzzle-v1/generated/generated.png');im=Image.open(p).convert('RGBA');a=np.array(im)
# Chroma matte preserves the complete ownership cells, including detached leaves.
d=np.maximum(255-a[:,:,0].astype(float),np.maximum(a[:,:,1].astype(float),255-a[:,:,2].astype(float)))
alpha=np.clip((d-40)/40,0,1);a[:,:,3]=(alpha*255).astype('uint8')
# Unmix the key only at the antialiased edge; retain original full colour.
for c,key in [(0,255),(2,255)]:a[:,:,c]=np.clip((a[:,:,c].astype(float)-key*(1-alpha))/np.maximum(alpha,.001),0,255).astype('uint8')
a[alpha==0]=0
rgba=Image.fromarray(a);out=Path('assets/exploration/puzzle-v1');out.mkdir(parents=True,exist_ok=True)
names=['lamp','ore','carving-0','carving-1','carving-2','carving-3','rubble','crystal']
for i,name in enumerate(names):
 x=(i%2)*im.width//2;y=(i//2)*im.height//4
 v=rgba.crop((x,y,x+im.width//2,y+im.height//4));v=v.crop(v.getbbox())
 if name=='ore':
  cv=Image.new('RGBA',(256,256));v.thumbnail((232,224),Image.Resampling.LANCZOS);cv.alpha_composite(v,((256-v.width)//2,248-v.height));v=cv
 v.save(out/(name+'.png'))
# The exact generated carved glyphs also become the lamp medallions.
for i,box in enumerate([(235,315,360,442),(923,315,1070,447),(221,561,371,702),(939,552,1063,702)]):
 glyph=rgba.crop(box);glyph.save(out/f'glyph-{i}.png')
data={'art_source':'existing','generated_route':'local:codex-cli','model':'codex-image_gen','estimateUsd':0,'source':str(p),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'processing':'equal ownership cells; soft magenta matte; full alpha bounds; ore registered on 256 canvas; exact source glyph crops','files':{v.name:hashlib.sha256(v.read_bytes()).hexdigest() for v in out.glob('*.png')},'quality_limits':'generated carving spike is radial; used identical crop on matching lamp. No user aesthetic approval claimed.'}
(out/'provenance.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
