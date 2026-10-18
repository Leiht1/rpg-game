from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
R=Path(__file__).resolve().parents[1];src=R/'art/body-v1/candidate-01/generated.png'
im=Image.open(src).convert('RGBA');a=np.array(im);c=a[:,:,:3].astype(float)
mask=(c[:,:,0]>140)&(c[:,:,2]>100)&(c[:,:,0]>c[:,:,1]*1.4)&(c[:,:,2]>c[:,:,1]*1.4)
a[mask,3]=0
out=R/'assets/ui/body_v1';out.mkdir(parents=True,exist_ok=True)
records=[]
for i,name in enumerate(['health','hunger','stamina']):
 cell=Image.fromarray(a[:,round(i*im.width/3):round((i+1)*im.width/3)])
 box=cell.getbbox();assert box and box[0]>0 and box[1]>0 and box[2]<cell.width and box[3]<cell.height
 cut=cell.crop(box);cut.thumbnail((88,88),Image.Resampling.LANCZOS)
 canvas=Image.new('RGBA',(96,96));canvas.alpha_composite(cut,((96-cut.width)//2,(96-cut.height)//2))
 path=out/(name+'.png');canvas.save(path)
 records.append({'file':str(path.relative_to(R)),'bbox':box,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'edge_alpha_clear':True})
(out/'provenance.json').write_text(json.dumps({'route':'local:codex-cli','art_source':'host_image','model':'codex-image_gen (underlying model undisclosed)','source':str(src.relative_to(R)),'prompt':'art/body-v1/prompt.txt','receipt':'art/body-v1/candidate-01/job.json','status':'integrated_per_task_visual_review_pending','source_size':im.size,'warnings':['WARN source_size_mismatch: value=2172x724, requested=1536x1024; file=art/body-v1/candidate-01/generated.png'],'processing':'Equal ownership thirds, full silhouette chroma key, aspect-preserving downscale with alpha safety edge. No code painting.','files':records},ensure_ascii=False,indent=2),encoding='utf-8')
