"""Adopt only explicitly accepted soil and the requested stubble overlay derivative."""
from pathlib import Path
import hashlib,json,shutil
r=Path(__file__).resolve().parents[1]
out=r/'assets/planting/v1';out.mkdir(parents=True,exist_ok=True)
entries={}
for name,source in [('soil','art/planting-soil-v4/processed/clean.png'),('roots','art/planting-roots-v2/processed/clean.png')]:
 dst=out/(name+'.png');shutil.copyfile(r/source,dst)
 entries[dst.name]={'source':source,'sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),
   'authorization':'approved_user' if name=='soil' else 'requested_derivative',
   'note':'获准PNG逐字节迁入' if name=='soil' else '按本轮要求，仅残根叠层，不含泥土；底层共用获准soil.png以保证色调完全一致；非额外主观验收结论'}
(out/'provenance.json').write_text(json.dumps({'date':'2026-10-18',
 'user_quote':'可以就这版作为可以种植的吧，然后有残留的色调跟这版保持一致。继续后面的开发，记得土地的排列方式要跟地板一样',
 'scope':'soil-v4获准；残根按照最新指示派生；不将本次批准扩大到尚未确认的作物/种子/收获物候选',
 'route':'generate2dsprite -> route_media -> local:codex-cli','files':entries},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
