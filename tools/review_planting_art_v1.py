from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib
r=Path(__file__).resolve().parents[1];out=r/'reports/planting-v1';out.mkdir(exist_ok=True)
im=Image.new('RGB',(1200,1110),'#f1ead9');draw=ImageDraw.Draw(im)
font=lambda n:ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',n)
def text(x,y,s,n=24):draw.text((x,y),s,font=font(n),fill='#39362d',anchor='mt')
text(600,18,'种植作物与图标候选 · 待确认',32)
text(600,62,'每种作物分别为幼苗、生长中、成熟；底层共用当前耕地',20)
soil=Image.open(r/'assets/planting/v2/soil.png').convert('RGBA');soil=soil.crop(soil.getbbox()).resize((276,180),Image.Resampling.LANCZOS)
for col,crop in enumerate(['carrot','potato','cabbage']):
 x=200+col*400;text(x,104,{'carrot':'胡萝卜','potato':'土豆','cabbage':'卷心菜'}[crop],27)
 for stage in range(3):
  y=246+stage*224
  im.paste(soil,(x-138,y-90),soil)
  plant=Image.open(r/f'prototypes/planting-crops-v2/final/{crop}_{stage}.png').convert('RGBA').resize((162,162),Image.Resampling.LANCZOS)
  im.paste(plant,(x-81,y-126),plant)
  text(x,y+94,['幼苗','生长中','成熟'][stage],19)
for i,(key,label) in enumerate([('carrot_seed','胡萝卜种子'),('potato_seed','土豆种子'),('cabbage_seed','卷心菜种子'),('potato','土豆收获物'),('cabbage','卷心菜收获物')]):
 x=120+i*240;icon=Image.open(r/f'prototypes/planting-v1/final/{key}.png').convert('RGBA').resize((128,128),Image.Resampling.LANCZOS)
 im.paste(icon,(x-64,914),icon);text(x,1040,label,21)
im.save(out/'crop-art-review.png')
manifest={}
for folder,keys in [('prototypes/planting-crops-v2/final',[f'{c}_{s}' for c in ['carrot','potato','cabbage'] for s in range(3)]),('prototypes/planting-v1/final',['carrot_seed','potato_seed','cabbage_seed','potato','cabbage'])]:
 for key in keys:
  path=r/f'{folder}/{key}.png';manifest[str(path.relative_to(r))]=hashlib.sha256(path.read_bytes()).hexdigest()
(out/'pending-art.json').write_text(json.dumps({'status':'pending_user','scope':'9 crop stage PNG + 3 seed PNG + 2 produce PNG; excludes separately accepted soil and requested roots derivative','files':manifest},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
