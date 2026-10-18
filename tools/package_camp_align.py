from pathlib import Path
from PIL import Image
src=Image.open('art/camp-align-v1/candidate-01/generated.png')
edit=Image.open('art/camp-align-v1/candidate-02/generated.png')
xs=[0,627,1254];ys=[0,560,1254]
out=Image.new('RGB',(1440,1440),'#ff00ff')
for y in range(2):
 for x in range(2):
  image=edit if (x,y)==(1,1) else src
  crop=image.crop((xs[x],ys[y],xs[x+1],ys[y+1]))
  out.paste(crop,(x*720+(720-crop.width)//2,y*720+(720-crop.height)//2))
out.save('art/camp-align-v1/owned-final.png')
