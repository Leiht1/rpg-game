from PIL import Image
import numpy as np
for frame in [11,12]:
 im=Image.open(f'assets/buildings/v1/frame-{frame:02}.png').convert('RGBA')
 for w in range(96,121,2):
  h=round(w*im.height/im.width);tile=im.resize((w,h),Image.Resampling.LANCZOS)
  out=Image.new('RGBA',(384,256))
  for y in range(4):
   for x in range(4): out.alpha_composite(tile,(round(48+x*96-w/2),round(32+y*64-h/2)))
  alpha=np.array(out)[16:-16,24:-24,3]
  print(frame,w,h,int(alpha.min()),int((alpha<250).sum()))
