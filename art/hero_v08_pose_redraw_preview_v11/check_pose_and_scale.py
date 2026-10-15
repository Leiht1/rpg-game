"""Diagnostic pose comparisons. Colour/mask observations are not art approval."""
from pathlib import Path
import json,math
import numpy as np
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent;ART=OUT.parent
def head(im):
    a=np.array(im).astype(float);yy,xx=np.where(a[:,:,3]>32);top=int(yy.min())
    skin=(a[:,:,0]>210)&(a[:,:,1]>140)&(a[:,:,2]>100)&(a[:,:,0]-a[:,:,1]>20)&(a[:,:,1]-a[:,:,2]>15)&(a[:,:,3]>128)
    skin[:top+75]=False;skin[top+160:]=False
    sy,sx=np.where(skin);bottom=int(round(np.percentile(sy,99.5)))+1
    mask=a[:,:,3].copy();mask[:top]=0;mask[bottom:]=0
    hy,hx=np.where(mask>32)
    return {'width':float((hx.max()-hx.min()+1)/4),'height':float((bottom-top)/4),'area':float(mask.sum()/255/16)}
def skin_blobs(im):
    a=np.array(im).astype(float)
    m=(a[:,:,0]>205)&(a[:,:,1]>135)&(a[:,:,2]>95)&(a[:,:,0]-a[:,:,1]>22)&(a[:,:,1]-a[:,:,2]>18)&(a[:,:,3]>128)
    m[:270]=False;m[350:]=False
    found=[]
    while m.any():
        y,x=np.argwhere(m)[0];stack=[(int(y),int(x))];m[y,x]=False;pts=[]
        while stack:
            y,x=stack.pop();pts.append((x,y))
            for dy,dx in [(0,1),(0,-1),(1,0),(-1,0)]:
                ny=y+dy;nx=x+dx
                if 0<=ny<512 and 0<=nx<512 and m[ny,nx]:m[ny,nx]=False;stack.append((ny,nx))
        if len(pts)>=35:
            p=np.array(pts)
            if p[:,1].max()<349:found.append({'center':(p.mean(axis=0)/4).tolist(),'areaPx':len(pts)/16,'bottom':int(p[:,1].max())})
    return sorted(found,key=lambda x:x['areaPx'],reverse=True)
def feet(im):
    a=np.array(im.getchannel('A'));y,x=np.where((a>64)&(np.indices(a.shape)[0]>=376))
    return [float(x.min()/4),float(x.max()/4),float(y.min()/4),float(y.max()/4)]
rows=[];font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',16)
contact=Image.new('RGB',(2048,1104),'#e5ebd6');d=ImageDraw.Draw(contact)
for i in range(8):
    old=Image.open(ART/f'hero_side_refine_preview_v08/registered_high/frame_{i+1:02}.png').convert('RGBA')
    new=Image.open(OUT/f'right_walk_preview/registered_high/frame_{i+1:02}.png').convert('RGBA')
    om,nm=head(old),head(new);ob,nb=skin_blobs(old),skin_blobs(new);of,nf=feet(old),feet(new)
    handDelta=None
    if ob and nb:handDelta=float(np.linalg.norm(np.array(ob[0]['center'])-np.array(nb[0]['center'])))
    rows.append({'frame':i+1,'oldHead':om,'newHead':nm,'oldSkinBlobs':ob,'newSkinBlobs':nb,'dominantArmSkinCentroidDeltaPx':handDelta,'oldFootExtent':of,'newFootExtent':nf,'footExtentDeltaPx':[round(b-a,3) for a,b in zip(of,nf)]})
    col=i%4;row=i//4
    for sub,(label,im) in enumerate([('v08 原姿势',old),('v11 重绘候选',new)]):
        x=col*512+sub*256;y=row*552
        d.text((x+5,y+3),f'{label} · {i+1}',font=font,fill='#344539')
        small=im.resize((256,256),Image.Resampling.LANCZOS);contact.paste(small,(x,y+25),small)
        # Head/torso close-up is review-only and never part of final artwork.
        detail=im.crop((144,76,352,352)).resize((208,276),Image.Resampling.LANCZOS)
        contact.paste(detail,(x+24,y+276),detail)
contact.save(OUT/'pose_comparison_contact.png')
h=[r['newHead'] for r in rows]
summary={'headWidthRange':[min(r['width'] for r in h),max(r['width'] for r in h)],'headHeightRange':[min(r['height'] for r in h),max(r['height'] for r in h)],'headAreaCV':float(np.std([r['area'] for r in h])/np.mean([r['area'] for r in h])),'maximumArmCentroidDelta':max(r['dominantArmSkinCentroidDeltaPx'] or 0 for r in rows)}
(OUT/'pose_and_scale_diagnostics.json').write_text(json.dumps({'status':'needs-visual-review','summary':summary,'frames':rows,'limits':['Skin component can change with occlusion/cuff; not a precise joint detector.','Foot extent alone cannot validate near/far identity or knee angle.','Head/torso contact crops are diagnostic only, never replacements.']},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary))
