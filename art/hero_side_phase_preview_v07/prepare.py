"""Build complete-pose references, preserving the current runtime and accepted v06."""
from pathlib import Path
import importlib.util,json
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1]
V4=OUT.parent/'hero_consistency_preview_v04';V5=OUT.parent/'hero_sequence_repair_preview_v05';V6=OUT.parent/'hero_side_spacing_preview_v06'
spec=importlib.util.spec_from_file_location('prev',V5/'repair_preview.py');M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M);P=M.P
(OUT/'references').mkdir(parents=True,exist_ok=True)
def high(folder,index,meta_name='registration.json',raw_name='generated.png'):
    meta=json.loads((folder/meta_name).read_text(encoding='utf-8'));t=meta['transforms'][index]
    c=P.clean(Image.open(folder/raw_name)).crop(tuple(t['sourceCell']))
    return P.W.render(c,t['scale'],t['offsetPx'],512)
poses={i+1:high(V4/'side_walk',i,'normalization.json','take1/generated.png') for i in [0,1,3]}
poses[3]=high(V6/'take1',0);poses[5]=high(V6/'take1',1)
poses[6]=high(V5/'side_walk/take3',1);poses[8]=high(V5/'side_walk/take3',3)
meta=json.loads((V5/'side_walk/take4/registration.json').read_text(encoding='utf-8'))
poses[7]=P.W.render(P.clean(Image.open(V5/'side_walk/take4/generated.png')),meta['scale'],meta['offsetPx'],512)
target=Image.new('RGBA',(1024,1024))
for slot,index in enumerate([2,3,5,6]):target.alpha_composite(poses[index],(slot%2*512,slot//2*512))
target.save(OUT/'references/edit_targets_2_3_5_6.png')
context=Image.new('RGB',(2048,1088),'#e2eacb');draw=ImageDraw.Draw(context);font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
for i in range(8):
    x=i%4*512;y=i//4*544;context.paste(poses[i+1],(x,y+32),poses[i+1])
    draw.text((x+10,y+3),f'v06 current frame {i+1}',font=font,fill='#344539')
context.save(OUT/'references/current_8_frames.png')
plan={'previewOnly':True,'changedFramesOneBased':[2,3,5,6],'preservedFramesOneBased':[1,4,7,8],
    'frameCount':8,'fpsReference':12,'fpsGameSpeed115':13.8,'canvas':[128,128],'root':[64,112],
    'sourceVersion':'v06, currently game template 4','runtimePolicy':'No assets, scripts, speed, idle or current template changes.',
    'phasePlanDraft':[
        '1 NEAR support/weight acceptance; FAR starts swing; near hand behind',
        '2 FAR recovery/passing under hip, visibly ahead of previous rear boot; NEAR support foot flat; near hand moving forward beside hip',
        '3 FAR low reach toward next contact; NEAR support foot moving backward; near hand moderately forward',
        '4 FAR forward reach/contact; NEAR trailing; near hand forward',
        '5 FAR weight acceptance with support foot under body; NEAR rear heel lifts and knee starts moving forward; near hand returns',
        '6 NEAR recovery/passing forward IN FRONT of FAR planted support leg; near boot raised just under/forward of hip, near hand nearly below shoulder',
        '7 NEAR low reach; FAR support; near hand begins backward',
        '8 NEAR forward reach/contact; FAR trailing; near hand backward'],
    'acceptanceFocus':['1-to-2-to-3 spacing','4-to-5-to-6 spacing','frame6 foreground leg identity','opposite arm swing','8-to-1 loop seam']}
P.save(OUT/'plan.json',plan)
print('Prepared four complete targets and chronological eight-frame context.')
