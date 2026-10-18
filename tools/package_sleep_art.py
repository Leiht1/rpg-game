from pathlib import Path
from PIL import Image
import json,hashlib
out=Path('prototypes/sleep-v1/final');out.mkdir(parents=True,exist_ok=True)
transforms=[]
for name,path,size,fit in [
 ('sleeping_bag','processed/sheet-1.png',(512,256),(448,216)),
 ('straw_mat','processed/sheet-2.png',(512,256),(448,216)),
 ('wood_bed','processed/sheet-3.png',(512,256),(448,216)),
 ('straw_mat-vertical','vertical-processed-v2/sheet-1.png',(256,416),(224,384)),
 ('wood_bed-vertical','vertical-processed-v2/sheet-2.png',(256,512),(224,464))]:
 im=Image.open(Path('art/sleep-v1')/path).convert('RGBA');bbox=im.getbbox();c=im.crop(bbox)
 factor=min(fit[0]/c.width,fit[1]/c.height)
 c=c.convert('RGBa').resize((round(c.width*factor),round(c.height*factor)),Image.Resampling.LANCZOS).convert('RGBA')
 canvas=Image.new('RGBA',size);xy=((size[0]-c.width)//2,(size[1]-c.height)//2);canvas.alpha_composite(c,xy);canvas.save(out/(name+'.png'))
 transforms.append(dict(name=name,source=path,bbox=bbox,scale=factor,canvas=size,xy=xy))
 if name in ['sleeping_bag','wood_bed','wood_bed-vertical']:
  # Extract existing opaque fabric pixels; do not repaint or invent a translucent veil.
  front=canvas.copy();a=front.getchannel('A');cut=Image.new('L',size)
  if 'vertical' in name: cut.paste(255,(0,288,size[0],size[1]))
  else: cut.paste(255,(288 if name=='sleeping_bag' else 296,0,size[0],size[1]))
  import PIL.ImageChops
  front.putalpha(PIL.ImageChops.multiply(a,cut));front.save(out/(name+'-front.png'))
manifest={'status':'pending_user','art_source':'host_image','route':'local:codex-cli','sources':['art/sleep-v1/raw/job.json','art/sleep-v1/vertical-raw/job.json'],'transforms':transforms,'approval':None,'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')},'qa_notes':['Original horizontal grid crossed uniform row boundaries; ownership crops retained all pixels.','Vertical source boundary_band and safe_frame warnings retained; final registered canvases have explicit alpha margins.']}
(out.parent/'provenance.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
print('Packaged',len(manifest['files']),'candidate PNGs. pending_user.')
