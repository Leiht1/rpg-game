"""Build high-resolution complete-pose references from recorded v05 sources."""
from pathlib import Path
import importlib.util,json
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1]
V4=OUT.parent/'hero_consistency_preview_v04';V5=OUT.parent/'hero_sequence_repair_preview_v05'
spec=importlib.util.spec_from_file_location('prev',V5/'repair_preview.py')
M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M);P=M.P
(OUT/'references').mkdir(exist_ok=True)
def high(folder,raw,index,meta_name='registration.json'):
    meta=json.loads((folder/meta_name).read_text(encoding='utf-8'))
    t=meta['transforms'][index];cell=P.clean(Image.open(folder/raw)).crop(tuple(t['sourceCell']))
    return P.W.render(cell,t['scale'],t['offsetPx'],512)
poses={2:high(V4/'side_walk','take1/generated.png',1,'normalization.json'),
       3:high(V5/'side_walk/take1','generated.png',2),
       4:high(V4/'side_walk','take1/generated.png',3,'normalization.json'),
       5:high(V5/'side_walk/take3','generated.png',0),
       6:high(V5/'side_walk/take3','generated.png',1)}
target=Image.new('RGBA',(1024,512))
for col,index in enumerate([3,5]):target.alpha_composite(poses[index],(col*512,0))
target.save(OUT/'references/edit_targets_3_5.png')
context=Image.new('RGB',(1536,1088),'#e2eacb');d=ImageDraw.Draw(context)
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
for row,indices in enumerate([[2,3,4],[4,5,6]]):
    for col,index in enumerate(indices):
        context.paste(poses[index],(col*512,row*544+32),poses[index])
        d.text((col*512+12,row*544+3),f'v05 · frame {index}',font=font,fill='#344539')
context.save(OUT/'references/context_2_3_4_and_4_5_6.png')
plan={'previewOnly':True,'changedFrames':[3,5],'unchangedFrames':[1,2,4,6,7,8],
      'directions':['right','left (whole-frame mirror)'],'frameSize':[128,128],'root':[64,112],
      'frameCount':8,'fps':12,'idle':'unchanged v05; no reprocessing',
      'artSource':'host_image','route':'host:image_gen + generate2dmedia adopt',
      'goal':'Tighten 2-to-3 pose spacing; differentiate 4 contact extension from 5 down/weight transfer, keeping limb identities.'}
P.save(OUT/'plan.json',plan)
print('Prepared two full-pose targets and six-pose context from recorded sources.')
