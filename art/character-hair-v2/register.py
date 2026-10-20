from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,collections
base=Path('art/character-hair-v2');out=Path('prototypes/character-hair-v2');(out/'hair').mkdir(exist_ok=True);(out/'heads').mkdir(exist_ok=True)
catalog_path=Path('prototypes/character-creation-v1/catalog.json')
backup=base/'prior-catalog.json'
if not backup.exists():backup.write_bytes(catalog_path.read_bytes())
cat=json.loads(backup.read_text(encoding='utf-8'));cat['version']=2;records=[];checks=[]
def cell(im,row,col,rows,cols):
 w,h=im.size;box=(round(col*w/cols),round(row*h/rows),round((col+1)*w/cols),round((row+1)*h/rows));piece=im.crop(box);a=np.array(piece)[:,:,3];ys,xs=np.where(a>16);bbox=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1));checks.append({'check':'source_gutter','cell':[row,col],'bbox':bbox,'size':piece.size,'pass':bbox[0]>0 and bbox[1]>0 and bbox[2]<piece.width and bbox[3]<piece.height});return piece.crop(bbox),box,bbox
for sex in ['male','female']:
 im=Image.open(base/f'{sex}-keyed/raw-sheet-clean.png').convert('RGBA')
 ids=[id for id,row in cat['hair'].items() if row['gender']==sex]
 for r,id in enumerate(ids):
  for c,view in enumerate(['front','back','side']):
   source=f'{sex}-keyed/raw-sheet-clean.png';source_im=im;source_row=r;rows=4
   if id=='male_parted':source='crop-keyed/raw-sheet-clean.png';source_im=Image.open(base/source).convert('RGBA');source_row=0;rows=1
   part,box,bbox=cell(source_im,source_row,c,rows,3)
   target_width=224 if sex=='male' else (248 if view!='side' else 235)
   scale=min(target_width/part.width,290/part.height);scaled=part.resize((round(part.width*scale),round(part.height*scale)),Image.Resampling.LANCZOS)
   canvas=Image.new('RGBA',(360,440));at=((360-scaled.width)//2,220-90);canvas.alpha_composite(scaled,at)
   path=out/'hair'/f'{id}-{view}.png';canvas.save(path)
   cat['hair'][id][view]={'front':'res://'+path.as_posix(),'rear':''}
   records.append({'id':id,'view':view,'source':source,'source_box':box,'alpha_bbox':bbox,'uniform_scale':scale,'canvas':list(canvas.size),'registration':[180,220],'paste':at,'layers':'complete silhouette; no horizontal split'})
   a=np.array(canvas);mask=a[:,:,3]>16;ys,xs=np.where(mask);rgb=a[mask,:3].astype(float)
   checks.append({'check':'complete_output','id':id,'view':view,'pass':not mask[0].any() and not mask[-1].any() and not mask[:,0].any() and not mask[:,-1].any()})
   checks.append({'check':'black_neutral','id':id,'view':view,'median_rgb':np.median(rgb,axis=0).tolist(),'pass':float(np.median(rgb.max(axis=1)-rgb.min(axis=1)))<12 and float(np.median(rgb))<80})
head=Image.open(base/'side-head-keyed/clean.png').convert('RGBA');a=np.array(head)[:,:,3];ys,xs=np.where(a>16);bbox=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1));part=head.crop(bbox);scale=min(196/part.width,153/part.height);scaled=part.resize((round(part.width*scale),round(part.height*scale)),Image.Resampling.LANCZOS);canvas=Image.new('RGBA',(224,180));at=((224-scaled.width)//2,180-scaled.height);canvas.alpha_composite(scaled,at);path=out/'heads/side.png';canvas.save(path)
cat['heads']={'front':'heads/front.png','back':'heads/back.png','side':'res://'+path.as_posix()}
cat['hair']['male_parted']['name']='美式前刺'
cat['sleep_side_eye_center']=[163.54237288135593/224,109.15496368038741/180]
catalog_path.write_text(json.dumps(cat,ensure_ascii=False,indent=2),encoding='utf-8')
records.append({'id':'bald_side','source':'side-head-keyed/clean.png','bbox':bbox,'uniform_scale':scale,'size':[224,180],'paste':at})
(base/'registration.json').write_text(json.dumps(records,indent=2),encoding='utf-8');(base/'registration-qa.json').write_text(json.dumps({'checks':checks,'total':len(checks),'failed':sum(not x['pass'] for x in checks)},indent=2),encoding='utf-8')
files={p.as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in out.rglob('*.png')}
provenance={'status':'pending_user','route':'local:codex-cli','art_source':'host_image','model':'codex-image_gen','exact_revision':'unknown','price':'unknown; local quota','request':'all hair black; American front spikes replaces parted; fix side rear patch and cropping; unified popup and view jitter','source_jobs':[p.as_posix() for p in base.glob('*/job.json')],'source_hashes':{p.as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in base.glob('*generated/generated.png')},'candidate_sha256':files,'catalog_sha256':hashlib.sha256(catalog_path.read_bytes()).hexdigest(),'compatibility':'male_parted ID retained for existing preview saves; name and three textures replaced. Existing worlds, profiles, original body PNGs, outfit and animations untouched.','qa':'registration-qa.json'}
(base/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')
print('PNGs',len(files),'checks',len(checks),'failed',sum(not x['pass'] for x in checks))
