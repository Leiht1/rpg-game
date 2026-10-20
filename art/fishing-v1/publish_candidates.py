"""Copy processed candidates and record exact provenance. Never writes assets/."""
from pathlib import Path
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[2]
source = root / 'art/fishing-v1'
out = root / 'prototypes/fishing-v1/art'
out.mkdir(parents=True, exist_ok=True)
files = {}
for name in ['rod', 'float', 'fish']:
    src = source / ('processed-rod-matched/clean.png' if name == 'rod' else f'processed-{name}/clean.png')
    dest = out / f'{name}.png'
    shutil.copyfile(src, dest)
    files[name] = {'source': str(src.relative_to(root)).replace('\\', '/'), 'candidate': str(dest.relative_to(root)).replace('\\', '/'), 'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()}
(out / 'registration.json').write_text(json.dumps({'grip_px': [73, 191], 'tip_px': [202, 36], 'scale': .24, 'canvas': [256, 256], 'float_waterline': 'lower stem', 'status': 'pending_user'}, indent=2), encoding='utf-8')
refs = ['assets/hero/cartoon/art/side_head.png', 'assets/industry/v1/fishing_rod.png']
record = {'status': 'pending_user', 'scope': 'Fishing V1 isolated preview only; no approval or formal adoption', 'art_source': 'existing native character rig + generated props; procedural ripples/shadows/splash/line/UI explicitly permitted by request', 'route': 'local:codex-cli', 'model': 'codex-image_gen', 'estimateUsd': 0.0, 'exact_model_version': 'not disclosed', 'prompt': 'art/fishing-v1/prompt.txt', 'receipt': 'art/fishing-v1/generated/job.json', 'original': 'art/fishing-v1/generated/generated.png', 'original_sha256': hashlib.sha256((source/'generated/generated.png').read_bytes()).hexdigest(), 'references': [{'path': p, 'sha256': hashlib.sha256((root/p).read_bytes()).hexdigest()} for p in refs], 'ownership': 'art/fishing-v1/ownership.json', 'processing': 'generate2dsprite process: single 256 / chroma_key magenta / soft / despill 1 / Lanczos / strict QC; no character frame generation', 'files': files, 'qa': [f'art/fishing-v1/{prefix}-{name}/{filename}' for name in files for prefix,filename in [('qc','sheet-qc.json'),('processed','pipeline-meta.json')]], 'pose_source': 'prototypes/fishing-v1/side_poses.json', 'retention': 'Generated original, prompt, receipts, QC and provenance are source records; runtime screenshots under reports/fishing-v1 are temporary pending user review.'}
record['rod_revision'] = {'user_instruction': '现在游戏里已经可以制作鱼竿了，鱼竿的造型要跟那个保持一致', 'prompt': 'art/fishing-v1/rod-match-prompt.txt', 'receipt': 'art/fishing-v1/rod-matched/job.json', 'source': 'art/fishing-v1/rod-matched/generated.png', 'source_sha256': hashlib.sha256((source/'rod-matched/generated.png').read_bytes()).hexdigest(), 'processing': 'native_alpha; alpha-hygiene both removes 4595 pixels with alpha <=4; single 256 / Lanczos / strict QC pass', 'superseded': 'First sheet rod is retained for provenance only; NOT loaded by runtime. Existing brown curved rod/reel/bindings retained in matched revision.'}
record['qa'] = [p.replace('qc-rod/', 'qc-rod-matched/').replace('processed-rod/', 'processed-rod-matched/') for p in record['qa']]
record['rod_size_revision'] = {'user_instruction': '这个鱼竿也太大了吧，要用原来的尺寸', 'scale': .24, 'canvas': [256, 256], 'reference': 'data/held_tools.json:tool:fishing_rod', 'superseded_scale': .48, 'note': 'Original held scale restored; grip and tip remain candidate texture coordinates. No formal file changed.'}
record['qa_warning'] = {'id': 'faint_specks', 'value': {'floor_px': 4595, 'detached_components': 0}, 'threshold': 0, 'file': 'art/fishing-v1/qc-rod-matched/sheet-qc.json', 'resolution': 'Removed by alpha-hygiene both; processed output QA pass, source warning retained.'}
for name in files:
    runtime = out / f'{name}.res'
    if runtime.exists():
        files[name]['runtime'] = str(runtime.relative_to(root)).replace('\\', '/')
        files[name]['runtime_sha256'] = hashlib.sha256(runtime.read_bytes()).hexdigest()
(source/'provenance.json').write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(files))
