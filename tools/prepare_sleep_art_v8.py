from pathlib import Path
from PIL import Image
im=Image.open('art/sleep-occupied-v8/raw/generated.png').convert('RGBA')
canvas=Image.new('RGBA',(im.width,2304),(255,0,255,255))
for i,(a,b) in enumerate([(0,480),(480,800),(800,1536)]):
 part=im.crop((0,a,im.width,b));canvas.paste(part,(0,i*768+(768-part.height)//2))
canvas.save('art/sleep-occupied-v8/owned.png')
