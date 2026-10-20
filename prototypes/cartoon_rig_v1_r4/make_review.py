from pathlib import Path
from PIL import Image,ImageDraw
p=Path(__file__).parent/'evidence'
for d in ['front','side']:
 for action,duration in [('chop',1650),('pickup',2200)]:
  frames=[]
  for f in sorted((p/f'{d}_{action}').glob('*.png')):
   im=Image.open(f).convert('RGBA');bg=Image.new('RGBA',im.size,'#e5ebdf');bg.alpha_composite(im);frames.append(bg.convert('RGB'))
  frames[0].save(p/f'{d}_{action}.gif',save_all=True,append_images=frames[1:],loop=0,duration=duration/48,disposal=2)
strip=Image.new('RGB',(1620,960),'#e5ebdf');draw=ImageDraw.Draw(strip)
for row,(d,a) in enumerate([('side','chop'),('side','pickup'),('front','chop'),('front','pickup')]):
 for col,k in enumerate([0,14,23,26,35,42]):
  im=Image.open(p/f'{d}_{a}/{k:02}.png').convert('RGBA').resize((270,240))
  strip.paste(im,(col*270,row*240),im)
  draw.text((col*270+8,row*240+5),f'{d} {a} {k}/48',fill='#334533')
strip.save(p/'action_phases.png')
