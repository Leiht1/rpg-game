from PIL import Image
import numpy as np,json
from pathlib import Path
src=Image.open('art/ores-v06/generated/generated.png').convert('RGB');a=np.asarray(src).astype(int)
cols=[0,425,800,1195,1600,src.width];rows=[0,480,src.height]
out=Image.new('RGB',(3200,1280),(255,0,255));records=[]
for y in range(2):
 for x in range(5):
  box=(cols[x],rows[y],cols[x+1],rows[y+1]);im=src.crop(box);v=np.asarray(im).astype(int)
  mask=~((v[:,:,0]-v[:,:,1]>80)&(v[:,:,2]-v[:,:,1]>80))
  yy,xx=np.where(mask);b=(int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1))
  assert b[0]>3 and b[1]>3 and b[2]<im.width-3 and b[3]<im.height-3, (x,y,b)
  # Exact ownership boxes include every subject pixel, then add original magenta margin.
  crop=im.crop((b[0]-3,b[1]-3,b[2]+3,b[3]+3))
  dx=x*640+(640-crop.width)//2;dy=y*640+544-crop.height
  out.paste(crop,(dx,dy));records.append({'cell':[y,x],'source_ownership':box,'visible_bbox_local':b,'paste':[dx,dy],'scale':1,'rotation':0})
out.save('art/ores-v06/owned-sheet.png')
Path('art/ores-v06/ownership.json').write_text(json.dumps({'source':'generated/generated.png','notes':'Explicit ownership boundaries in blank gaps; no visible pixels cut, every asset moved without scale/rotation onto 640 cells with safe margins. Original raw nominal row 396 cuts rock foot at y430.','cells':records},indent=2),encoding='utf-8')
