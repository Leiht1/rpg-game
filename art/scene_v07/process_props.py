from PIL import Image
from pathlib import Path
import json,hashlib,numpy as np
src=Path('art/scene_v07/props/generated.png')
im=Image.open(src).convert('RGBA')
w,h=im.size
names=['tree_0','tree_1','rock_0','rock_1','flowers','leaves']
sizes=[(177,190),(177,198),(77,65),(54,48),(34,26),(35,22)]
report={'source_size':im.size,'source_mode':Image.open(src).mode,'cells':[],'warnings':['raw_sheet: requested equal grid not respected; manual ownership rectangles required', 'raw_sheet: colored translucent glow; alpha<210 discarded during cleanup'],'status':'pending_user','finish':'HD, original logical canvases and foot anchor retained'}
ownership=[(28,50,595,685),(600,60,1025,685),(1080,375,1505,690),(165,775,465,978),(695,780,905,974),(1100,775,1420,978)]
for i,(name,size) in enumerate(zip(names,sizes)):
 x0,y0,x1,y1=ownership[i]
 cell=im.crop((x0,y0,x1,y1));a=np.array(cell)
 border=np.concatenate([a[0,:,3],a[-1,:,3],a[:,0,3],a[:,-1,3]])
 if int(border.max())>8:report['warnings'].append(f'{name}: cell_edge_alpha={int(border.max())}, expected<=8')
 # Preserve isolated leaves and chips: no largest-component selection.
 a[a[:,:,3]<210]=0
 cell=Image.fromarray(a);bbox=cell.getbbox()
 if bbox is None:raise RuntimeError(name+' empty')
 crop=cell.crop(bbox)
 # Premultiplied alpha LANCZOS; single scale, no shape distortion.
 scale=min(size[0]/crop.width,size[1]/crop.height)
 target=(max(1,round(crop.width*scale)),max(1,round(crop.height*scale)))
 scaled=crop.convert('RGBa').resize(target,Image.Resampling.LANCZOS).convert('RGBA')
 canvas=Image.new('RGBA',size)
 xy=((size[0]-target[0])//2,size[1]-target[1])
 canvas.alpha_composite(scaled,xy)
 canvas.save('prototypes/scene-study-v07/'+name+'.png')
 report['cells'].append({'name':name,'cell':[x0,y0,x1,y1],'crop':bbox,'scale':scale,'output_size':size,'placement':xy,'alpha_extrema':canvas.getchannel('A').getextrema()})
report['sha256']=hashlib.sha256(src.read_bytes()).hexdigest()
Path('art/scene_v07/processing.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
