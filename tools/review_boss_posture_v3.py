"""Uniform review layout and objective report from actual Godot captures."""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image,ImageDraw
p=Path('reports/boss-posture-v3');poses=['neutral','contact','down','passing']
for scale in ['normal','large']:
    top=230 if scale=='normal' else 110; row_height=480-top+20
    board=Image.new('RGB',(1280,row_height*4),'#252c2a');d=ImageDraw.Draw(board)
    for i,pose in enumerate(poses):
        im=Image.open(p/f'{pose}-{scale}.png');board.paste(im.crop((0,top,1280,480)),(0,i*row_height+20));d.text((12,i*row_height+3),pose,fill='white')
    board.save(p/f'pose-review-{scale}.png')
old=Image.open('reports/boss-posture-v2/neutral-large.png');new=Image.open(p/'neutral-large.png')
board=Image.new('RGB',(1280,800),'#252c2a');d=ImageDraw.Draw(board)
for i,(im,title) in enumerate([(old,'OLD V2'),(new,'REWORK')]):
    board.paste(im.crop((0,110,1280,480)),(0,30+i*400));d.text((12,i*400+5),title,fill='white')
board.save(p/'before-after-neutral.png')
# Native-pixel crops enlarged exactly 2x. All poses share crop bounds.
board=Image.new('RGB',(1440,1440),'#252c2a');d=ImageDraw.Draw(board)
for i,pose in enumerate(poses):
    im=Image.open(p/f'{pose}-large.png')
    for col,box in enumerate([(95,310,320,475),(510,310,735,475),(1000,270,1155,435)]):
        crop=im.crop(box).resize(((box[2]-box[0])*2,(box[3]-box[1])*2),Image.Resampling.NEAREST)
        x=col*480;y=i*360+25;board.paste(crop,(x,y));d.text((x+5,i*360+3),pose+[' front joints',' back joints',' profile joints'][col],fill='white')
board.save(p/'joint-review.png')
board=Image.new('RGB',(560,840),'#252c2a');d=ImageDraw.Draw(board)
for i,pose in enumerate(poses):
    for col,prefix in enumerate(['','mirror-']):
        im=Image.open(p/f'{prefix}{pose}-normal.png').crop((900,250,1180,450))
        board.paste(im,(col*280,i*210+10));d.text((col*280+5,i*210),pose+(' right' if col==0 else ' left'),fill='white')
board.save(p/'mirror-review.png')
provenance=json.loads(Path('prototypes/boss-posture-v3/parts/provenance.json').read_text(encoding='utf8'))
audit=[]
for part in provenance['parts']:
    file=Path('prototypes/boss-posture-v3/parts')/part['view']/(part['slot']+'.png')
    a=np.array(Image.open(file).convert('RGBA')).astype(float)
    magenta=int(((np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1]>70)&(a[:,:,3]>200)).sum())
    audit.append(dict(view=part['view'],slot=part['slot'],sha_match=hashlib.sha256(file.read_bytes()).hexdigest()==part['sha256'],opaque_magenta_pixels=magenta))
(p/'asset-audit.json').write_text(json.dumps(audit,indent=2),encoding='utf8')
m=json.loads((p/'metrics.json').read_text(encoding='utf8'))
lines=['# 姿态测量','', '世界单位；正常相机 zoom=1、候选 scale=0.8，所以屏幕差值=下表×0.8。所有地面坐标均相对同一根点，支撑脚足底Y=0。正背接地脚的不同Y是地面纵深投影，不是腾空。', '', '|视角|姿态|支撑脚(x,y)|另一脚(x,y)|另一脚离自身地面|骨盆Y|躯干Y|全身包围高|膝L/R°|肘L/R°|躯干倾角°|','|---|---|---|---|---|---|---|---|---|---|---|']
for view in ['front','back','right']:
    for pose in poses:
        r=m[view][pose]
        fmt=lambda xy:'/'.join(f'{x:.1f}' for x in xy)
        lines.append(f'|{view}|{pose}|{fmt(r["left_sole"])}|{fmt(r["right_sole"])}|{r["clearance"]:.1f}|{r["pelvis"][1]:.1f}|{r["torso"][1]:.1f}|{r["height"]:.1f}|{fmt(r["knees_degrees"])}|{fmt(r["elbows_degrees"])}|{r["torso_degrees"]:.1f}|')
lines+=['','膝角列是图面骨骼相对角；正背另有固定32单位肢段的纵深屈伸投影，物理矢状角及地面投影保存在 metrics.json，不能把图面角单独当作三维屈膝角。肘角为真实父子节点相对角。', '']
for view in ['front','back','right']:
    n=m[view]['neutral'];c=m[view]['contact'];d=m[view]['down'];s=m[view]['passing']
    lines.append(f'- {view}：Contact 横向足距 {c["screen_step_x"]:.1f}、纵深图面足差 {c["screen_step_y"]:.1f}；Down 相对Neutral骨盆下沉 {d["pelvis"][1]-n["pelvis"][1]:.1f}，躯干下沉 {d["torso"][1]-n["torso"][1]:.1f}；Passing 离地 {s["clearance"]:.1f}（正常尺寸 {s["clearance"]*.8:.1f}px）。')
(p/'METRICS.md').write_text('\n'.join(lines),encoding='utf8')
print('Uniform layouts, joint crops, metrics and',len(audit),'asset records. Audit issues:',sum(not a['sha_match'] or a['opaque_magenta_pixels'] for a in audit))

board=Image.new('RGB',(2560,1560),'#252c2a');draw=ImageDraw.Draw(board)
for i,pose in enumerate(poses):
    for col,folder in enumerate(['boss-posture-v2','boss-posture-v3']):
        im=Image.open(Path('reports')/folder/(pose+'-large.png'))
        board.paste(im.crop((0,110,1280,480)),(col*1280,i*390+20))
        draw.text((col*1280+8,i*390+3),('OLD ' if col==0 else 'REWORK ')+pose,fill='white')
board.save(p/'before-after-poses.png')
