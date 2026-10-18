from pathlib import Path
from PIL import Image
p=Path('art/sleep-v1')
im=Image.open(p/'raw/generated.png').convert('RGB')
out=Image.new('RGB',(1536,1536),'#ff00ff')
for i,(a,b) in enumerate([(0,350),(350,620),(620,1024)]):
 c=im.crop((0,a,1536,b));out.paste(c,(0,i*512+(512-c.height)//2))
out.save(p/'owned.png')
im=Image.open(p/'vertical-raw/generated.png').convert('RGB');h=im.height//2
out=Image.new('RGB',(im.width,im.height+256),'#ff00ff')
for i in range(2): out.paste(im.crop((0,i*h,im.width,(i+1)*h)),(0,i*(h+128)+64))
out.save(p/'vertical-owned.png')
