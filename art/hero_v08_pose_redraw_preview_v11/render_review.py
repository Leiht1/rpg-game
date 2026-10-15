"""Render labelled reviews from the already verified final PNGs only."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent;ART=OUT.parent
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
images={di:[Image.open(OUT/f'{di}_walk_preview/frames/{di}_walk_{i:02}.png').convert('RGBA') for i in range(8)] for di in ['front','back','right']}
labels={'front':'正视参考','back':'背视参考','right':'侧视重绘 v11'}
contact=Image.new('RGB',(2048,864),'#e5ebd6');draw=ImageDraw.Draw(contact)
for row,di in enumerate(images):
    for i,f in enumerate(images[di]):
        x=i*256;y=row*288;draw.text((x+6,y+3),f'{labels[di]} · {i+1}',font=font,fill='#344539')
        big=f.resize((256,256));contact.paste(big,(x,y+28),big);draw.line((x,y+252,x+256,y+252),fill='#b1bda5')
contact.save(OUT/'crossview_contact.png')
side=Image.new('RGB',(1024,576),'#e5ebd6');d=ImageDraw.Draw(side)
for i,f in enumerate(images['right']):
    x=i%4*256;y=i//4*288;d.text((x+6,y+3),f'重绘 v11 · 第{i+1}帧',font=font,fill='#344539')
    b=f.resize((256,256));side.paste(b,(x,y+28),b)
side.save(OUT/'side_contact.png')
old=[Image.open(ART/f'hero_side_refine_preview_v08/right_walk_preview/frames/right_walk_{i:02}.png').convert('RGBA') for i in range(8)]
cross=[];compare=[]
for i in range(8):
    p=Image.new('RGB',(768,442),'#e5ebd6');d=ImageDraw.Draw(p);d.rectangle((0,302,768,442),fill='#2c3837')
    for col,di in enumerate(images):
        f=images[di][i];d.text((col*256+6,3),f'{labels[di]} · {i+1}',font=font,fill='#344539');b=f.resize((256,256));p.paste(b,(col*256,28),b);p.paste(f,(col*256+64,310),f)
    cross.append(p)
    p=Image.new('RGB',(512,442),'#e5ebd6');d=ImageDraw.Draw(p)
    for col,(label,f) in enumerate([('v08 原姿势',old[i]),('v11 同姿势重绘',images['right'][i])]):
        d.text((col*256+6,3),f'{label} · {i+1}',font=font,fill='#344539');b=f.resize((256,256));p.paste(b,(col*256,28),b);p.paste(f,(col*256+64,310),f)
    compare.append(p)
for name,ps in [('crossview_walk',cross),('side_before_after',compare)]:
    for suffix,wms,gms in [('',[72,73]*4,[70,70,80,70,70,70,80,70]),('_slow',[145]*8,[140,150]*4)]:
        ps[0].save(OUT/f'{name}{suffix}.webp',save_all=True,append_images=ps[1:],duration=wms,loop=0,lossless=True)
        ps[0].save(OUT/f'{name}{suffix}.gif',save_all=True,append_images=ps[1:],duration=gms,loop=0,disposal=2)
print('Updated labels and reviews; final frame PNGs unchanged.')
