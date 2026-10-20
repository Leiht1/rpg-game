from pathlib import Path
from PIL import Image
import json,hashlib,numpy as np
base=Path('art/character-creation-v1');out=Path('prototypes/character-creation-v1')
for d in ['heads','hair','outfit']: (out/d).mkdir(parents=True,exist_ok=True)
views=['front','back','side'];records=[]
def crop_cell(im,r,c,rows,cols):
    w,h=im.size;box=(round(c*w/cols),round(r*h/rows),round((c+1)*w/cols),round((r+1)*h/rows));cell=im.crop(box);a=np.array(cell)[:,:,3];ys,xs=np.where(a>16);bounds=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1));return cell.crop(bounds),box,bounds
def fit(im,size):
    scale=min(size[0]/im.width,size[1]/im.height);return im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
heads=Image.open(base/'bald-processed/raw-sheet-clean.png').convert('RGBA')
for c,v in enumerate(views):
    cell,box,bounds=crop_cell(heads,0,c,1,3);part=fit(cell,(196,153));canvas=Image.new('RGBA',(224,180));canvas.alpha_composite(part,((224-part.width)//2,180-part.height));canvas.save(out/'heads'/f'{v}.png');records.append({'target':f'heads/{v}.png','source':'bald-generated/generated.png','cell':box,'bbox':bounds,'scale':part.width/cell.width})
names={'male':[('natural','自然短发'),('fluffy','蓬松短发'),('parted','侧分短发'),('curly','微卷短发')],'female':[('bob','齐肩短发'),('straight','长直发'),('twintail','双马尾'),('ponytail','低马尾')]}
cat={'version':1,'hair':{},'skin':{},'outfit':{}}
for sex in names:
    im=Image.open(base/f'{sex}-final/raw-sheet-clean.png').convert('RGBA')
    for r,(key,label) in enumerate(names[sex]):
        id=f'{sex}_{key}';cat['hair'][id]={'name':label,'gender':sex}
        for c,v in enumerate(views):
            cell,box,bounds=crop_cell(im,r,c,4,3)
            target_width=224 if sex=='male' else (248 if v!='side' else 235)
            part=fit(cell,(target_width,290));canvas=Image.new('RGBA',(360,400))
            # Original head center (112,90) is the registration point. Top is -90.
            at=((360-part.width)//2,200-90);canvas.alpha_composite(part,at)
            front=canvas.copy();rear=canvas.copy()
            # Long hair around/under the neck goes behind the existing head.
            # Back view keeps its nape in front; front/side put the lower tail behind face.
            split=200-90+(125 if v=='front' else 116)
            if v=='back': rear=Image.new('RGBA',canvas.size)
            else:
                fa=np.array(front);ra=np.array(rear)
                fa[split:,:,3]=0;ra[:split,:,3]=0
                front=Image.fromarray(fa);rear=Image.fromarray(ra)
            for layer,img in [('front',front),('rear',rear)]: img.save(out/'hair'/f'{id}-{v}-{layer}.png')
            cat['hair'][id][v]={'front':f'hair/{id}-{v}-front.png','rear':f'hair/{id}-{v}-rear.png'}
            records.append({'target':f'hair/{id}-{v}','source':f'{sex}-packed.png','cell':box,'bbox':bounds,'scale':part.width/cell.width,'registration':[180,200],'part_top':at[1],'split_y':split})
for i,(label,color) in enumerate([('瓷白','#f7d6b4'),('浅肤','#efb67e'),('自然','#d99a65'),('麦色','#b97c4d'),('棕肤','#945b38'),('深棕','#633c29')],1):cat['skin'][f'skin_{i}']={'name':label,'color':color}
im=Image.open(base/'outfit-final/raw-sheet-clean.png').convert('RGBA')
for c,v in enumerate(views):
    cat['outfit'][v]={}
    for r,(part,size) in enumerate([('torso',(80 if v=='side' else 96,96)),('arm',(32,100)),('leg',(36,80))]):
        cell,box,bounds=crop_cell(im,r,c,3,3);scaled=fit(cell,size);canvas=Image.new('RGBA',size);canvas.alpha_composite(scaled,((size[0]-scaled.width)//2,(size[1]-scaled.height)//2));name=f'outfit/{v}_{part}.png';canvas.save(out/name)
        for k in ([part] if part=='torso' else [part+'_l',part+'_r']):cat['outfit'][v][k]=name
        records.append({'target':name,'source':'outfit-packed.png','cell':box,'bbox':bounds,'scale':scaled.width/cell.width})
cat['outfits']={'modern_outfit':{'parts':cat.pop('outfit'),'skin_regions':{'torso':[0,.2],'arm_l':[.72,1],'arm_r':[.72,1]}}}
(out/'catalog.json').write_text(json.dumps(cat,ensure_ascii=False,indent=2),encoding='utf-8')
(base/'registration.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
qa=[]
for name in ['male','female','bald','outfit']:
    d=json.loads((base/(f'{name}-processed/pipeline-meta.json' if name=='bald' else f'{name}-final/pipeline-meta.json')).read_text());qa.append({'bundle':name,'qa':d.get('qa')})
(base/'qa-summary.json').write_text(json.dumps(qa,indent=2),encoding='utf-8')
files={str(p).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.rglob('*.png')}
prov={'status':'pending_user','art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen','exact_revision':'unknown','cost':'unknown; route reports local quota 0 USD','approved':False,'references':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in Path('assets/hero/cartoon/art').glob('*.png')},'candidate_sha256':files,'ownership':'art/character-creation-v1/ownership.json','registration':'art/character-creation-v1/registration.json','qa':'art/character-creation-v1/qa-summary.json','note':'Bald heads are generated hair-removal edits; wigs are standalone parts. Original approved images and all keyframes unchanged. First outfit call failed TOOL_UNAVAILABLE; three-reference retry succeeded.'}
(base/'provenance.json').write_text(json.dumps(prov,ensure_ascii=False,indent=2),encoding='utf-8')
print('candidate PNGs',len(files))
