from PIL import Image
from pathlib import Path
import numpy as np,json
rows=[]
for frame,rect in [(11,(15,13,186,124)),(12,(17,13,183,122))]:
 im=Image.open(f'assets/buildings/v1/frame-{frame:02}.png').convert('RGBA');x,y,w,h=rect
 rows.append({'frame':frame,'source':list(rect),'source_alpha_min':im.getchannel('A').crop((x,y,x+w,y+h)).getextrema()[0],'source_aspect':w/h,'target_aspect':96/64})
Path('reports/camp-build-v4/tile-source-audit.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
results=[]
for kind in ['wood_floor','stone_path']:
 a=np.array(Image.open(f'reports/camp-build-v4/tiles-{kind}.png').convert('RGB')).astype('int16')
 diffs=[int(np.abs(a[:,x-1]-a[:,x]).max()) for x in [96,192,288]]+[int(np.abs(a[y-1]-a[y]).max()) for y in [64,128,192]]
 results.append({'kind':kind,'max_color_jump_at_join':max(diffs),'join_differences':diffs,'unique_colors':int(len(np.unique(a.reshape(-1,3),axis=0))),'pass':max(diffs)<=1})
Path('reports/camp-build-v4/tile-seams.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print(results)
