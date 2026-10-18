"""Key/crop/resample generated art only. No replacement art is drawn."""
from pathlib import Path
import hashlib, json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'art/ui-v1/candidate-01/generated.png'
image=Image.open(source).convert('RGBA')
out=ROOT/'assets/ui/v1'
out.mkdir(parents=True,exist_ok=True)
regions={'panel':(24,36,655,642),'slot':(675,36,1238,630),'button':(20,660,715,1060),'field_lantern':(785,650,1130,1190)}
sizes={'panel':(256,240),'slot':(96,96),'button':(192,64),'field_lantern':(128,128)}
records=[]
for name,rect in regions.items():
    crop=image.crop(rect)
    a=np.array(crop)
    rgb=a[:,:,:3].astype(float)
    key=(rgb[:,:,0]>150)&(rgb[:,:,2]>120)&(rgb[:,:,0]>rgb[:,:,1]*1.4)&(rgb[:,:,2]>rgb[:,:,1]*1.4)
    a[:,:,3][key]=0
    crop=Image.fromarray(a)
    bbox=crop.getbbox()
    assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<crop.width and bbox[3]<crop.height,(name,bbox)
    crop=crop.crop(bbox)
    target=sizes[name]
    crop.thumbnail((target[0]-4,target[1]-4),Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',target)
    canvas.alpha_composite(crop,((target[0]-crop.width)//2,(target[1]-crop.height)//2))
    dest=out/(name+'.png')
    canvas.save(dest)
    records.append({'file':str(dest.relative_to(ROOT)),'ownership_rect':rect,'alpha_bbox':bbox,'size':target,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'safe_margin_px':2})
job=json.loads((source.parent/'job.json').read_text('utf-8'))
provenance={'version':'core-ui-art-1.0.0','status':'integrated_per_current_task_visual_review_pending','art_source':'host_image','route':'local:codex-cli','exact_image_model':'not exposed','source':str(source.relative_to(ROOT)),'source_size':image.size,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'prompt':'art/ui-v1/prompt.txt','receipt':'art/ui-v1/candidate-01/job.json','estimate':job['estimate'],'selection_reason':'Coherent wood/linen/sage kit with quiet centers; independent ownership crops avoid nominal quadrant truncation.','processing':'Chroma key, ownership crop, equal aspect Lanczos downscale, transparent 2px padding. No repaint/rotation/nonuniform scaling.','files':records,'warnings':['Returned 1254x1254 instead of requested 1024x1024. Nominal grid crosses button; ownership crops used.'],'external_assets':[]}
(out/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')
items_path=ROOT/'data/items.json'
items=json.loads(items_path.read_text('utf-8'))
for item in items:
    if item['item_id'] in ['stone_axe','stone_pickaxe','simple_shovel']: item['drop_rules']['source']='徒手制作 / F6 调试物品库'
    if item['item_id']=='simple_shovel': item['description']='装备到武器槽后可挖掘半埋根茎、骨片和补给包。'
if not any(i['item_id']=='field_lantern' for i in items):
    items.append({'item_id':'field_lantern','name':'野营提灯','category':'utility','description':'使用后开关随身暖光，照亮夜间附近地面。放在背包或快捷栏即可使用；不占装备槽，不消耗燃料。失去最后一盏时熄灭，重新进入游戏默认熄灭。','icon':'res://assets/ui/v1/field_lantern.png','world_visual':'res://assets/ui/v1/field_lantern.png','world_size':24,'max_stack':1,'usable':True,'use_action':'light','consumable':False,'tags':['exploration','lighting'],'rarity':'common','drop_rules':{'source':'徒手制作'},'effects':{},'equippable':False,'equip_slot':'','equipment_type':'','capabilities':[],'action_id':'','visual_id':'','stats':{},'durability':None})
items_path.write_text(json.dumps(items,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Packaged',len(records),'art files; registered field_lantern')
