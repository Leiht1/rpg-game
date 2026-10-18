from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib, json

root = Path('art/sleep-still-v3')
out = Path('prototypes/sleep-still-v3/final')
out.mkdir(parents=True, exist_ok=True)
transforms = []
for direction, size, fit in [('vertical',(256,416),(192,352)), ('horizontal',(512,256),(400,184))]:
    source = root / (direction+'-processed') / 'clean.png'
    im = Image.open(source).convert('RGBA')
    box = im.getbbox()
    body = im.crop(box)
    scale = min(fit[0]/body.width, fit[1]/body.height)
    body = body.convert('RGBa').resize((round(body.width*scale),round(body.height*scale)),Image.Resampling.LANCZOS).convert('RGBA')
    canvas = Image.new('RGBA',size)
    xy = ((size[0]-body.width)//2,(size[1]-body.height)//2)
    canvas.alpha_composite(body,xy)
    canvas.save(out/('sleep-'+direction+'.png'))
    transforms.append(dict(direction=direction,source=str(source),bbox=box,scale=scale,xy=xy,canvas=size))
provenance = dict(status='pending_user',approval=None,art_source='host_image',route='local:codex-cli',
    reference_sha256=hashlib.sha256((root/'user-reference.png').read_bytes()).hexdigest(),
    jobs=[str(root/(d+'-raw')/'job.json') for d in ['vertical','horizontal']],
    transforms=transforms,files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')},
    notes=['Two separately generated whole-body stills. No standing character parts, pose rotation, head replacement or skeletal sleep animation.',
           'Runtime continuous chest-local UV breathing only; source closed eyes remain painted. New candidate not promoted to formal assets.'])
(out.parent/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf8')
report=Path('reports/sleep-still-v3');report.mkdir(parents=True,exist_ok=True)
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',24)
card=Image.new('RGB',(940,500),'#eee5cf');draw=ImageDraw.Draw(card)
draw.text((30,20),'重新绘制 · 完整闭眼睡姿（候选）',font=font,fill='#58442d')
for direction,xy in [('vertical',(130,75)),('horizontal',(370,145))]:
    im=Image.open(out/('sleep-'+direction+'.png'))
    if direction=='vertical': im=im.resize((224,364),Image.Resampling.LANCZOS)
    card.paste(im,xy,im)
draw.text((170,450),'竖向',font=font,fill='#58442d')
draw.text((570,450),'横向',font=font,fill='#58442d')
card.save(report/'new-stills.png')
print('Packaged two whole sleeping stills; pending_user.')
