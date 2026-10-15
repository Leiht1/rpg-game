"""Archive review artifacts, exact source provenance, and the documented workflow."""
from pathlib import Path
import hashlib, json, zipfile
from PIL import Image

ROOT=Path(__file__).resolve().parent; GAME=ROOT.parent.parent
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d): p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
source={}
for d in ['front','back','side']:
    source[d]={'raw':f'{d}/take1/generated.png','job':f'{d}/take1/job.json',
        'rawSha256':sha(ROOT/d/'take1/generated.png'),
        'actualSize':list(Image.open(ROOT/d/'take1/generated.png').size),
        'prompt':f'{d}_prompt.txt','promptSha256':sha(ROOT/f'{d}_prompt.txt'),
        'reference':f'references/{d}_locked_four_frame_target.png',
        'referenceSha256':sha(ROOT/f'references/{d}_locked_four_frame_target.png'),
        'referenceConstruction':'Four copies of v01 complete neutral figure, one common scale matching current idle height. Reference only, not final animation.',
        'operations':'New generated whole-body poses; native alpha<=8 cleaned; Gorest grid; common direction scale and whole-frame subpixel rigid translation, one premultiplied sampling pass.'}
save(ROOT/'provenance.json',{'date':'2026-10-15','revision':'v02','status':'needs-visual-review','previewOnly':True,
    'route':'host:image_gen','adoption':'generate2dmedia cli_media.py adopt','actualImageCalls':3,'videoCalls':0,
    'underlyingModel':None,'estimateUsd':None,'actualUsd':None,
    'costNote':'Image model and per-call price not exposed. Zero-dollar adoption receipts are not image generation cost evidence.',
    'sources':source,'leftDerivation':'Whole-frame horizontal mirror of right/side in the same time order',
    'license':'Generated artwork subject to provider/account terms; no third-party commercial game assets used; no public-domain or open-source claim.',
    'previousVersion':'../hero_idle_breathe_preview_v01/','previousStatus':'rejected by user: motion too small and obvious displacement',
    'gameIntegration':False})
archive=ROOT/'hero_idle_breathe_preview_v02.zip'
excluded={'gorest_library.before.json','game_files_before.json','delivery.json'}
files=[p for p in ROOT.rglob('*') if p.is_file() and p.suffix not in ['.pyc','.zip'] and '__pycache__' not in p.parts and p.name not in excluded]
files+= [GAME/'CHARACTER_SEQUENCE_WORKFLOW.md',GAME/'ART_STYLE.md',GAME/'CHARACTER_MODULAR_RULES.md']
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for p in files:
        name=str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else 'project_rules/'+p.name
        z.write(p,name)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    count=len(z.namelist())
save(ROOT/'delivery.json',{'archive':archive.name,'bytes':archive.stat().st_size,'sha256':sha(archive),'files':count,'zipIntegrity':'pass','previewOnly':True})
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'files':count,'zipIntegrity':'pass'}))
