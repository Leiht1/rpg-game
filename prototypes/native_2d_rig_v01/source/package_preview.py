"""Package only actual Godot renders for convenient, fair 128px comparison."""
from pathlib import Path
import hashlib
import json
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'preview_data'
OUT.mkdir(exist_ok=True)
FONT = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 16)
SMALL = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 13)
BG = '#e4ebd7'


def main():
    for action in ['walk','breathe','wave']:
        for outfit in range(2):
            sheet = Image.new('RGBA',(1024,1024))
            for i in range(64):
                im = Image.open(ROOT/f'evidence/renders/{action}_{outfit}/{i:03}.png')
                sheet.paste(im, ((i%8)*128,(i//8)*128))
            sheet.save(OUT/f'{action}_{outfit}.png',optimize=True)
    data = {'durations':{'walk':8/13.8,'breathe':1.8,'wave':2.4},
            'joints':json.loads((ROOT/'evidence/joints.json').read_text(encoding='utf-8')),
            'parents':{b['name']:b['parent'] for b in json.loads((ROOT/'source/rig_manifest.json').read_text(encoding='utf-8'))['skeleton']}}
    (OUT/'data.js').write_text('window.RIG_DATA='+json.dumps(data,separators=(',',':'))+';\n',encoding='utf-8')
    durations_ms = {'walk':580,'breathe':1800,'wave':2400}
    for action in ['walk','breathe','wave']:
        frames=[]
        for i in range(64):
            canvas=Image.new('RGB',(808,340),BG)
            d=ImageDraw.Draw(canvas)
            for c,title in enumerate(['v11 已确认序列帧','骨骼 · 原上衣','骨骼 · 换上衣']):
                d.text((20+c*264,12),title,font=FONT,fill='#38493d')
                d.line((20+c*264,282,268+c*264,282),fill='#abb99f')
            if action=='walk':
                old=Image.open(ROOT/f'reference/side_walk_{i//8:02}.png')
            elif action=='breathe':
                old=Image.open(ROOT/f'reference/side_idle_{i//16:02}.png')
            else:
                old=Image.open(ROOT/'reference/side_idle_00.png')
            images=[old]+[Image.open(ROOT/f'evidence/renders/{action}_{o}/{i:03}.png') for o in range(2)]
            for c,im in enumerate(images):
                im=im.resize((256,256),Image.Resampling.LANCZOS)
                canvas.paste(im,(12+c*264,58),im)
            names={'walk':'行走','breathe':'呼吸待机','wave':'挥手（左侧无原版挥手，保持原待机）'}
            d.text((20,316),f'{names[action]}  ·  同比例 2× / Godot 原生渲染 / 128×128',font=SMALL,fill='#5e7057')
            frames.append(canvas)
        timing=[round((i+1)*durations_ms[action]/64)-round(i*durations_ms[action]/64) for i in range(64)]
        frames[0].save(ROOT/f'evidence/{action}_comparison.webp',save_all=True,append_images=frames[1:],
                       duration=timing,loop=0,lossless=True,method=4)
        frames[0].save(ROOT/f'evidence/{action}_comparison_still.png')
        if action=='walk':
            selected=frames[::2]
            gif_timing=[round((i+1)*58/32)*10-round(i*58/32)*10 for i in range(32)]
            selected[0].save(ROOT/'evidence/walk_comparison.gif',save_all=True,append_images=selected[1:],
                              duration=gif_timing,loop=0,optimize=False)
    # Full-cycle contact sheet at identical source dimensions and filtering.
    contact=Image.new('RGB',(8*256,3*282),BG)
    d=ImageDraw.Draw(contact)
    for row in range(3):
        for col in range(8):
            im=Image.open(ROOT/(f'reference/side_walk_{col:02}.png' if row==0 else f'evidence/renders/walk_{row-1}/{col*8:03}.png'))
            im=im.resize((256,256),Image.Resampling.LANCZOS)
            contact.paste(im,(col*256,row*282+24),im)
            name=['v11','骨骼 原上衣','骨骼 换上衣'][row]
            d.text((col*256+8,row*282+2),f'{name}  {col+1} / 8',font=SMALL,fill='#38493d')
    contact.save(ROOT/'evidence/walk_contact.png')
    # Pixel evidence is intentionally separate from the subjective art verdict.
    findings={}
    for action in ['breathe','wave']:
        frames=[np.array(Image.open(ROOT/f'evidence/renders/{action}_0/{i:03}.png')) for i in range(64)]
        base=frames[0][96:116,45:86]
        findings[action+'_feet_max_rgba_delta']=max(int(np.abs(a[96:116,45:86].astype(int)-base.astype(int)).max()) for a in frames)
    bounds={}
    for action in ['walk','breathe','wave']:
        boxes=[Image.open(ROOT/f'evidence/renders/{action}_0/{i:03}.png').getbbox() for i in range(64)]
        bounds[action]={'height_min':min(b[3]-b[1] for b in boxes),'height_max':max(b[3]-b[1] for b in boxes),
                        'alpha_touches_canvas':any(b[0]<=0 or b[1]<=0 or b[2]>=128 or b[3]>=128 for b in boxes)}
    baseline=json.loads((ROOT/'source/protected_baseline.json').read_text(encoding='utf-8'))
    game=ROOT.parents[1]
    changed=[p for p,h in baseline.items() if hashlib.sha256((game/p).read_bytes()).hexdigest()!=h]
    findings.update({'bounds':bounds,'protected_files':len(baseline),'protected_changes':changed,
                     'pixel_region':[45,96,86,116],
                     'status':'pass' if not changed and findings['breathe_feet_max_rgba_delta']==0 and findings['wave_feet_max_rgba_delta']==0 else 'fail',
                     'visual_quality':'needs-user-review; measurements do not approve art or natural gait'})
    (ROOT/'evidence/delivery_checks.json').write_text(json.dumps(findings,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(findings,ensure_ascii=False))


if __name__=='__main__':
    main()
