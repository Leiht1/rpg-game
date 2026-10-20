from PIL import Image,ImageDraw
from pathlib import Path
import sys
p=Path(__file__).parent/'evidence'
for d in ['front','side']:
 for a,dur in [('breathe',1800),('walk',640),('run',440),('wave',1600)]:
  if "--wave-only" in sys.argv and a!="wave":continue
  frames=[]
  for f in sorted((p/f'{d}_{a}').glob('*.png')):
   im=Image.open(f).convert('RGBA'); bg=Image.new('RGBA',im.size,'#e5ebdf');bg.alpha_composite(im);frames.append(bg.convert('RGB'))
  frames[0].save(p/f'{d}_{a}.gif',save_all=True,append_images=frames[1:],loop=0,duration=dur/24,disposal=2)
contact=Image.new('RGB',(1024,600),'#e5ebdf'); draw=ImageDraw.Draw(contact)
for row,d in enumerate(['front','side']):
 for col,a in enumerate(['breathe','walk','run','wave']):
  im=Image.open(p/f'{d}_{a}/06.png').convert('RGBA').resize((256,256))
  contact.paste(im,(col*256,row*300+25),im)
  draw.text((col*256+16,row*300+8),f'{d} / {a}',fill='#334533')
contact.save(p/'contact.png')
# A phase strip helps inspect actual GPU-rendered poses, not a second animation implementation.
strip=Image.new('RGB',(1152,460),'#e5ebdf');dr=ImageDraw.Draw(strip)
for row,action in enumerate(['walk','run']):
 for col,k in enumerate([0,4,8,12,16,20]):
  im=Image.open(p/f'side_{action}/{k:02}.png').convert('RGBA').resize((192,192))
  strip.paste(im,(col*192,row*230+20),im)
  dr.text((col*192+8,row*230+4),f'{action} {k}/24',fill='#334533')
strip.save(p/'gait_phases.png')
