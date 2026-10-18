from pathlib import Path
from PIL import Image
import json,hashlib
root=Path('assets/ores/v06');files=[]
for i in range(1,11):
 src=Path(f'art/ores-v06/processed-owned/ore-{i}.png');im=Image.open(src).convert('RGBA')
 if i<=5:
  b=im.getbbox();dy=248-b[3];out=Image.new('RGBA',(256,256));out.alpha_composite(im,(0,dy));im=out
 elif i<=8:
  b=im.getbbox();crop=im.crop(b);out=Image.new('RGBA',(crop.width+16,crop.height+16));out.paste(crop,(8,8));im=out
 else:
  # Center fracture overlay within the rock face, independent of inventory anchors.
  b=im.getbbox();crop=im.crop(b);out=Image.new('RGBA',(256,256));out.paste(crop,((256-crop.width)//2,(220-crop.height)//2));im=out
 dst=root/f'frame-{i:02}.png';im.save(dst)
 files.append({'file':dst.as_posix(),'sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),'source':src.as_posix(),'bbox':im.getbbox(),'size':im.size})
p={'art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen; underlying image model unknown','estimateUsd':0.0,'actualCost':'unknown; subscription quota','authorization':'2026-10-17 user requested replacement of ordinary scenery rocks with large mineable stone/flint/copper/silver/gold resources, integrated into map. Subjective visual acceptance pending user.','source':'art/ores-v06/generated/job.json','prompt':'art/ores-v06/prompt.txt','ownership':'art/ores-v06/ownership.json','processing':'Exact ownership in blank gaps, soft magenta matte, 1px despill, shared uniform scale/feet anchors; rock canvas 256 bottom248, items trimmed+8px padding, overlays centered; no nonuniform scaling.','qa':{'raw_nominal':'FAIL cross_cell_components=5 cross_cell_visible=5, WARN boundary_band=18375 safe_frame=5; preserved in raw-qc','initial_nominal_processing':'WARN, not shipped; preserved in processed','owned_sheet':'PASS all spill/edge/safe-frame checks','published_processing':'PASS including no clamping/source/output edge contact, key residue and key ring spill'},'files':files}
(root/'provenance.json').write_text(json.dumps(p,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print([(f['file'],f['bbox']) for f in files])
