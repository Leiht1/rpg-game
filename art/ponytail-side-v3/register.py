from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
base=Path('art/ponytail-side-v3');old_path=Path('prototypes/character-hair-v2/hair/female_ponytail-side.png');out=Path('prototypes/ponytail-side-v3/female_ponytail-side.png')
old=Image.open(old_path).convert('RGBA');generated=Image.open(base/'processed/clean.png').convert('RGBA');old_a=np.array(old);yy,xx=np.where(old_a[:,:,3]>16);oldbox=(int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1));ga=np.array(generated);yy,xx=np.where(ga[:,:,3]>16);box=(int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1));part=generated.crop(box);scale=(oldbox[2]-oldbox[0])/part.width;part=part.resize((round(part.width*scale),round(part.height*scale)),Image.Resampling.LANCZOS)
aligned=Image.new('RGBA',old.size);aligned.alpha_composite(part,(oldbox[0]-14,oldbox[1]))
head=Image.new('RGBA',old.size);head.alpha_composite(Image.open('prototypes/character-hair-v2/heads/side.png'),(68,130));h=np.array(head)
mask=np.zeros((440,360));mask[240:286,65:120]=1
for y in range(220,240):mask[y,65:120]=(y-220)/20
mask*=h[:,:,3]/255.0
a=np.array(aligned);a[:,:,3]=np.rint(a[:,:,3]*mask).astype('uint8');candidate=Image.fromarray(a);candidate.alpha_composite(old);candidate.save(out)
ca=np.array(candidate);region=np.zeros((440,360),bool);region[220:286,65:120]=True;ca[~region]=old_a[~region];candidate=Image.fromarray(ca);candidate.save(out);hs=h.astype(int);skin=(hs[:,:,3]>200)&(hs[:,:,0]>160)&(hs[:,:,0]-hs[:,:,1]>25)&(hs[:,:,1]-hs[:,:,2]>25)
before=int((region&skin&(old_a[:,:,3]<240)).sum());after=int((region&skin&(ca[:,:,3]<240)).sum());outside=np.any(ca!=old_a,axis=2)&~region
checks=[{'name':'exposed rear scalp removed','before':before,'after':after,'pass':before>0 and after==0},{'name':'all pixels outside localized region identical','changed':int(outside.sum()),'pass':not outside.any()},{'name':'all original opaque hair pixels identical','pass':bool((ca[old_a[:,:,3]==255]==old_a[old_a[:,:,3]==255]).all())}]
catpath=Path('prototypes/character-creation-v1/catalog.json');backup=base/'before-catalog.json'
if not backup.exists():backup.write_bytes(catpath.read_bytes())
cat=json.loads(backup.read_text(encoding='utf-8'));cat['hair']['female_ponytail']['side']['front']='res://'+out.as_posix();catpath.write_text(json.dumps(cat,ensure_ascii=False,indent=2),encoding='utf-8')
hashes=json.loads((base/'before-hashes.json').read_text(encoding='utf-8'));checks.append({'name':'all 25 previous V2 PNGs unchanged','pass':all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==v for p,v in hashes.items())})
(base/'qa.json').write_text(json.dumps({'checks':checks,'failed':sum(not x['pass'] for x in checks),'total':len(checks)},indent=2),encoding='utf-8')
prov={'status':'pending_user','art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen','exact_revision':'unknown','cost':'unknown, local quota','source_job':'generated/job.json','source_sha256':hashlib.sha256((base/'generated/generated.png').read_bytes()).hexdigest(),'reference_sha256':{p.as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in [old_path,Path('prototypes/character-hair-v2/heads/side.png'),base/'user-reference.png']},'output':out.as_posix(),'output_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'registration':{'source_box':box,'uniform_scale':scale,'paste':[oldbox[0]-14,oldbox[1]],'canvas':[360,440],'generated_patch_only':[65,220,120,286],'top_feather':[220,240],'mask':'existing bald head alpha in localized area','compositing':'original hair over generated underlay; all original opaque hair unchanged'},'qa':'qa.json','note':'Only female low-ponytail side texture reference changes; left shares original rig mirror. Fringe, tie, ponytail and all other hairstyle PNGs preserved.'}
(base/'provenance.json').write_text(json.dumps(prov,ensure_ascii=False,indent=2),encoding='utf-8');print('skin',before,'->',after,'checks',len(checks),'failed',sum(not x['pass'] for x in checks))
