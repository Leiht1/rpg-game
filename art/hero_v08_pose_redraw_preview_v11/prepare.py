from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1];ART=OUT.parent
(OUT/'references').mkdir(parents=True,exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(name,v):(OUT/name).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
sheet=Image.new('RGBA',(2048,1024));hashes={}
for i in range(8):
    p=ART/f'hero_side_refine_preview_v08/registered_high/frame_{i+1:02}.png'
    im=Image.open(p).convert('RGBA');sheet.alpha_composite(im,(i%4*512,i//4*512));hashes[p.relative_to(ROOT).as_posix()]=sha(p)
sheet.save(OUT/'references/v08_exact_eight_poses.png')
master=ART/'hero_side_refine_preview_v08/registered_high/frame_01.png'
(OUT/'references/side_body_master.png').write_bytes(master.read_bytes())
cross=Image.new('RGBA',(1536,512))
for col,di in enumerate(['front','back']):
    p=ART/f'hero_v08_pose_locked_preview_v10/{di}_walk_preview/registered_high/frame_01.png'
    cross.alpha_composite(Image.open(p).convert('RGBA'),(col*512,0));hashes[p.relative_to(ROOT).as_posix()]=sha(p)
cross.alpha_composite(Image.open(master).convert('RGBA'),(1024,0));cross.save(OUT/'references/crossview_reference.png')
# Review/planning only: coarse limb centre lines reinforce the original poses.
# These guides are never composited into final art or used as a cut-part rig.
poses=[
 {'nearArm':[[240,245],[214,285],[197,323]],'farArm':[[266,244],[280,283],[289,309]],'nearLeg':[[250,335],[269,365],[271,395],[286,421]],'farLeg':[[231,334],[214,361],[204,392],[207,421]]},
 {'nearArm':[[241,245],[234,281],[236,325]],'farArm':[[267,244],[279,280],[286,303]],'nearLeg':[[257,334],[271,361],[268,393],[279,422]],'farLeg':[[238,335],[242,356],[224,379],[233,395]]},
 {'nearArm':[[239,249],[251,288],[281,324]],'farArm':[[221,248],[208,290],[193,317]],'nearLeg':[[235,343],[226,370],[216,397],[218,427]],'farLeg':[[257,341],[271,371],[279,397],[298,425]]},
 {'nearArm':[[239,238],[266,272],[310,298]],'farArm':[[213,244],[197,284],[185,305]],'nearLeg':[[234,333],[217,359],[196,386],[188,416]],'farLeg':[[263,335],[275,370],[290,399],[311,424]]},
 {'nearArm':[[241,251],[256,291],[280,324]],'farArm':[[214,253],[204,285],[190,315]],'nearLeg':[[254,337],[240,358],[216,383],[208,412]],'farLeg':[[264,340],[265,369],[265,396],[279,426]]},
 {'nearArm':[[239,245],[246,288],[256,325]],'farArm':[[221,246],[208,279],[201,299]],'nearLeg':[[259,338],[273,355],[275,382],[293,411]],'farLeg':[[238,337],[227,366],[219,396],[230,427]]},
 {'nearArm':[[241,246],[225,286],[233,327]],'farArm':[[268,246],[280,282],[291,310]],'nearLeg':[[258,341],[275,365],[293,393],[320,419]],'farLeg':[[235,342],[229,373],[229,401],[231,428]]},
 {'nearArm':[[236,248],[202,285],[174,313]],'farArm':[[265,246],[285,283],[293,310]],'nearLeg':[[259,340],[279,366],[297,394],[325,423]],'farLeg':[[228,338],[201,368],[183,392],[182,418]]}]
guide=Image.new('RGB',(2048,1024),'#f4f4ed');d=ImageDraw.Draw(guide);font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',24)
for i,pose in enumerate(poses):
    ox=i%4*512;oy=i//4*512
    d.text((ox+16,oy+12),str(i+1),font=font,fill='#344539');d.rectangle((ox+1,oy+1,ox+510,oy+510),outline='#d5dccd')
    d.ellipse((ox+158,oy+80,ox+330,oy+220),outline='#717b67',width=3)
    d.line([(ox+244,oy+224),(ox+245,oy+340)],fill='#717b67',width=5)
    for key,color in [('farArm','#449cb0'),('farLeg','#449cb0'),('nearArm','#d98a42'),('nearLeg','#d98a42')]:
        pts=[(ox+x,oy+y) for x,y in pose[key]];d.line(pts,fill=color,width=5)
        for x,y in pts:d.ellipse((x-5,y-5,x+5,y+5),fill=color)
guide.save(OUT/'references/pose_landmark_guide.png')
save('pose_reference.json',{'source':'v08','sourceHashes':hashes,'frameIndicesZeroBased':list(range(8)),'poseLandmarks512':poses,'landmarkCaveat':'Manually estimated 2D review landmarks, not a rig or precise anatomical ground truth. Original coloured v08 frame is authority if a guide disagrees.','generationInstruction':'Redraw the same eight poses, same phase/order/occlusion; no alternative walk.'})
runtime={p.relative_to(ROOT).as_posix():sha(p) for folder in ['assets/hero','scripts','scenes'] for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix not in ['.import','.uid']}
if not (OUT/'game_files_before.json').exists():save('game_files_before.json',runtime)
save('plan.json',{'previewOnly':True,'newUserAuthorization':'Redraw a consistent complete sequence, strictly following all current v08 frame poses.','directionsToRedraw':['right'],'directionReferences':['front','back'],'frames':8,'canvas':[128,128],'root':[64,112],'fps':13.8,'generation':'Whole-sheet complete-figure restoration, no semantic walk recipe overriding the source poses.','sourcePoseLock':'pose_reference.json','bodyReference':'references/side_body_master.png','crossviewReference':'references/crossview_reference.png','left':'mirror complete right frames','normalization':'One shared scale for whole new source sheet, rigid whole-frame registration only. No per-frame size fit or body part patches.','runtime':'No changes before preview acceptance.'})
print('Prepared exact v08 pose targets, shared-body/crossview references and review-only landmarks.')
