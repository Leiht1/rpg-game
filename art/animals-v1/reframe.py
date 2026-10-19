from PIL import Image
from pathlib import Path
im=Image.open('art/animals-v1/generated/generated.png').convert('RGB');out=Image.new('RGB',(2048,1536),(255,0,255))
xs=[0,410,790,1135,im.width];ys=[0,350,695,im.height]
for y in range(3):
 for x in range(4):
  p=im.crop((xs[x],ys[y],xs[x+1],ys[y+1]));out.paste(p,(x*512+(512-p.width)//2,y*512+(512-p.height)//2))
out.save('art/animals-v1/ownership.png')
