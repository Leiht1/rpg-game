from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
src=Path('art/view_v01/props/generated.png');im=Image.open(src).convert('RGBA')
rects=[(70,25,765,650),(910,30,1380,660),(180,670,710,1000),(960,725,1340,995)]
report={'status':'pending_user','art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen','exact_underlying_model':None,'actual_cost':None,'estimateUsd':0,'warnings':['raw_sheet: requested equal grid not respected; manual ownership rectangles required','raw_sheet: colored translucent glow; alpha<210 discarded during cleanup'],'cells':[]}
for name,rect in zip(['tree_0','tree_1','rock_0','rock_1'],rects):
 cell=np.array(im.crop(rect));cell[cell[:,:,3]<210]=0
 pic=Image.fromarray(cell);bb=pic.getbbox();pic=pic.crop(bb)
 old=Image.open('assets/environment/stylized_v3/'+name+'.png');size=old.size
 scale=min(size[0]/pic.width,size[1]/pic.height);target=tuple(max(1,round(d*scale)) for d in pic.size)
 pic=pic.convert('RGBa').resize(target,Image.Resampling.LANCZOS).convert('RGBA')
 out=Image.new('RGBA',size);xy=((size[0]-target[0])//2,size[1]-target[1]);out.alpha_composite(pic,xy);out.save('prototypes/view-v01/'+name+'.png')
 report['cells'].append({'name':name,'ownership':rect,'trim':bb,'uniform_scale':scale,'placement':xy,'logical_canvas':size,'alpha_extrema':out.getchannel('A').getextrema(),'base_alignment':'bottom center; nature_prop draw bottom = root+8'})
refs=['reports/ecology-v03-271828-region-0.png']+['assets/environment/stylized_v3/'+n+'.png' for n in ['tree_0','tree_1','rock_0','rock_1']]
report['references']={f:hashlib.sha256(Path(f).read_bytes()).hexdigest() for f in refs}
report['raw_sha256']=hashlib.sha256(src.read_bytes()).hexdigest()
Path('art/view_v01/processing.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report['cells']))
