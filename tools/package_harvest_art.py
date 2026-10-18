from pathlib import Path
from PIL import Image
import hashlib,json
root=Path('assets/harvest/v05'); files=[]
# Fixed 256 canvas retained for registered stage swaps. No per-stage fitting.
for i in range(1,21):
 src=Path(f'art/harvest-v05/processed/harvest-{i}.png')
 im=Image.open(src).convert('RGBA');dst=root/f'frame-{i:02}.png';im.save(dst)
 files.append(dict(path=dst.as_posix(),sha256=hashlib.sha256(dst.read_bytes()).hexdigest(),bbox=im.getbbox(),source=src.as_posix()))
# Contact anchor is the grouped lowest visible row, shared by each triplet.
# Shift the entire triplet by one identical integer offset so earth touches root+8.
for group in [[1,2,3],[4,5,6],[9,10,11],[13,14,15],[17,18,19]]:
 bottom=max(Image.open(root/f'frame-{i:02}.png').getbbox()[3] for i in group)
 offset=248-bottom
 for i in group:
  dst=root/f'frame-{i:02}.png';im=Image.open(dst).convert('RGBA');out=Image.new('RGBA',im.size);out.alpha_composite(im,(0,offset));out.save(dst)
  files[i-1].update(bbox=out.getbbox(),registration_shift_y=offset,sha256=hashlib.sha256(dst.read_bytes()).hexdigest())
# Inventory/drop assets use alpha-trim + eight source pixels; stage canvases stay fixed.
for i in [7,8,12,16,20]:
 dst=root/f'frame-{i:02}.png';im=Image.open(dst).convert('RGBA');crop=im.crop(im.getbbox());out=Image.new('RGBA',(crop.width+16,crop.height+16));out.paste(crop,(8,8));out.save(dst)
 files[i-1].update(bbox=out.getbbox(),sha256=hashlib.sha256(dst.read_bytes()).hexdigest())
provenance=dict(art_source='host_image',route='local:codex-cli',model='underlying image model unknown',estimateUsd=0.0,actualCost='unknown; subscription quota',authorization='2026-10-17 user explicitly requests new assets integrated into playable mining/digging; aesthetic acceptance pending user',source='art/harvest-v05/generated/job.json',prompt='art/harvest-v05/prompt.txt',processing='soft magenta matte, 1px despill, registered shared 0.797069597 scale to 256 canvas; stage triplet common integer ground shift, icons trimmed with 8px padding; no nonuniform scale',qa=['raw safe_frame WARN value=18 threshold=0 files=art/harvest-v05/raw-qc/sheet-qc.json; no cross-cell/edge contact','processed pipeline qa_status=pass; see art/harvest-v05/processed/pipeline-meta.json'],files=files)
(root/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
