from PIL import Image
import numpy as np,json,pathlib,hashlib
root=pathlib.Path('.')
out=root/'assets/exploration/mine-blast-v4';out.mkdir(parents=True,exist_ok=True)
for kind,rows,count in [('flash',2,8),('particles',3,12)]:
 im=Image.open(root/f'art/mine-blast-v4/{kind}-source/generated.png').convert('RGB');w,h=im.size
 for i in range(count):
  cell=im.crop((i%4*w//4,i//4*h//rows,(i%4+1)*w//4,(i//4+1)*h//rows))
  a=np.array(cell).astype(float); alpha=np.clip(1-(np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1])/255,0,1)
  alpha=np.clip((alpha-.10)/.90,0,1)
  rgb=np.clip((a-(1-alpha[:,:,None])*np.array([255,0,255]))/np.maximum(alpha[:,:,None],.001),0,255)
  rgba=np.dstack([rgb,alpha*255]).astype('uint8');rgba[alpha<.035]=0
  result=Image.fromarray(rgba)
  if kind=='particles':
   box=result.getbbox();result=result.crop(box)
  result.save(out/f'{kind}-{i:02}.png')
manifest={'frames':[f'flash-{i:02}.png' for i in range(8)],'duration_ms':[30,40,50,65,75,85,95,110],'canvas':[384,512],'anchor_px':[192,256],'smoke':[f'particles-{i:02}.png' for i in [0,1,2,3,4,5,10,11]],'stones':[f'particles-{i:02}.png' for i in [6,7,8,9]],'tail_seconds':4.8,'art_source':'local Codex image generation; source and prompts in art/mine-blast-v4'}
(out/'runtime.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
p=root/'data/mine_rules.json';d=json.loads(p.read_text());d['blast_visual']['manifest']='res://assets/exploration/mine-blast-v4/runtime.json';d['blast_visual']['width']=350;p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

