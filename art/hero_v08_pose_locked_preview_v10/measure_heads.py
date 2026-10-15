from pathlib import Path
import json
import numpy as np
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent
def measure(im,di):
    a=np.array(im).astype(float);b=im.getchannel('A').point(lambda v:255 if v>32 else 0).getbbox();top=b[1]
    if di=='back':
        # Back-head lower edge is a hair/collar boundary, not a skin chin.
        # Fixed review crop only; not used to infer identical anatomy.
        bottom=top+132
    else:
        skin=(a[:,:,0]>210)&(a[:,:,1]>140)&(a[:,:,2]>100)&(a[:,:,0]-a[:,:,1]>20)&(a[:,:,1]-a[:,:,2]>15)&(a[:,:,3]>128)
        skin[:top+75]=False;skin[top+160:]=False
        yy,xx=np.where(skin);bottom=int(round(np.percentile(yy,99.5)))+1
    mask=a[:,:,3].copy();mask[:top]=0;mask[bottom:]=0
    yy,xx=np.where(mask>32)
    return {'top512':top,'bottom512':bottom,'widthPx':round((xx.max()-xx.min()+1)/4,3),'heightPx':round((bottom-top)/4,3),'alphaAreaPx':round(mask.sum()/255/16,3),'headCenterX':round((xx.min()+xx.max()+1)/8,3)}
allrows=[];font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',15)
page=Image.new('RGB',(2048,648),'#e5ebd6');d=ImageDraw.Draw(page)
for row,di in enumerate(['front','back','right']):
    for i in range(8):
        im=Image.open(OUT/f'{di}_walk_preview/registered_high/frame_{i+1:02}.png').convert('RGBA');m=measure(im,di)
        allrows.append({'direction':di,'frame':i+1,**m})
        x=i*256;y=row*216
        # Review-only crop; never reused as a replacement head or final art.
        crop=im.crop((120,60,360,240));page.paste(crop,(x+8,y+28),crop)
        d.text((x+5,y+2),f'{di} {i+1}: {m["widthPx"]}×{m["heightPx"]}',font=font,fill='#344539')
        d.text((x+5,y+194),f'head area {m["alphaAreaPx"]}',font=font,fill='#344539')
(OUT/'head_measurements.json').write_text(json.dumps({'measurements':allrows,'policy':'Visible head outline width/height/alpha area. Side/front chin estimated from skin; back uses a review crop. Measurements are diagnostic, not anatomy approval.'},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
page.save(OUT/'head_comparison.png')
print(json.dumps(allrows))
