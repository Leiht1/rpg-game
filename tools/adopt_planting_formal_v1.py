"""Promote only the exact 14 PNGs identified in the user-approved review manifest."""
from pathlib import Path
import json,hashlib,shutil
r=Path(__file__).resolve().parents[1]
quote='可以 直接接入游戏吧'
manifest=r/'reports/planting-v1/pending-art.json'
accepted=json.loads(manifest.read_text(encoding='utf8'))
out=r/'assets/planting/v3';out.mkdir(parents=True,exist_ok=True)
files={}
for source,sha in accepted['files'].items():
 src=r/source;dst=out/src.name
 assert hashlib.sha256(src.read_bytes()).hexdigest()==sha,source
 if dst.exists():assert hashlib.sha256(dst.read_bytes()).hexdigest()==sha,dst
 shutil.copyfile(src,dst)
 assert hashlib.sha256(dst.read_bytes()).hexdigest()==sha,dst
 files[dst.name]={'source':src.relative_to(r).as_posix(),'sha256':sha}
assert len(files)==14
(out/'provenance.json').write_text(json.dumps({'status':'approved_user','date':'2026-10-18','user_quote':quote,
 'scope':'本次验收图指定的9张作物阶段、3张种子、2张收获物，逐字节迁入；不批准未来素材',
 'review_manifest':'reports/planting-v1/pending-art.json','review_image':'reports/planting-v1/crop-art-review.png',
 'route':'generate2dsprite -> route_media -> local:codex-cli','files':files},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
accepted.update(status='approved_user',approved_date='2026-10-18',approved_quote=quote,formal_provenance='assets/planting/v3/provenance.json')
manifest.write_text(json.dumps(accepted,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
p=r/'data/items.json';items=json.loads(p.read_text(encoding='utf8'))
for item in items:
 key=item['item_id']
 if key in ['carrot_seed','potato_seed','cabbage_seed','potato','cabbage']:
  item['icon']=item['world_visual']='res://assets/planting/v3/'+key+'.png'
 elif key=='tilled_soil':item['icon']=item['world_visual']='res://assets/planting/v2/soil.png'
p.write_text(json.dumps(items,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
p=r/'data/buildings.json';recipes=json.loads(p.read_text(encoding='utf8'))
for row in recipes:
 if row['recipe_id']=='build_tilled_soil':row['default_unlocked']=True
p.write_text(json.dumps(recipes,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
p=r/'prototypes/planting-crops-v2/provenance.json';value=json.loads(p.read_text(encoding='utf8'))
value.update(status='approved_user',approved_quote=quote,formal_provenance='assets/planting/v3/provenance.json')
p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
p=r/'prototypes/planting-v1/provenance.json';value=json.loads(p.read_text(encoding='utf8'))
value.update(status='partially_approved_user',approved_quote=quote,approved_files=[x for x in files if '_' not in x[:-4] or x.endswith('_seed.png')],formal_provenance='assets/planting/v3/provenance.json',approved_scope='仅carrot_seed/potato_seed/cabbage_seed/potato/cabbage五个图标；其余旧图不在本次批准内')
p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
for folder in ['v1','v2']:
 p=r/f'assets/planting/{folder}/provenance.json';value=json.loads(p.read_text(encoding='utf8'))
 value['final_adoption']={'date':'2026-10-18','user_quote':quote,'note':'本次采用当前92x60、压暗泥土及共用底层残根；旧土V4保留不重新启用。其余14图见v3独立范围。'}
 p.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Adopted 14/14 PNGs with matching approved hashes; default farming recipe enabled.')
