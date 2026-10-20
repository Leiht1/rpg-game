"""Record candidate additions and QC; never writes formal assets or item data."""
from pathlib import Path
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[2]
source = root / 'art/fishing-v2'
out = root / 'prototypes/fishing-v1/art'
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
files = {}
for name in ['coin', 'locked_chest']:
    src = source / f'processed-{name}/clean.png'
    dest = out / f'{name}.png'
    shutil.copyfile(src, dest)
    files[name] = {'source': str(src.relative_to(root)), 'candidate': str(dest.relative_to(root)), 'sha256': sha(dest)}
    runtime = out / f'{name}.res'
    if runtime.exists():
        files[name].update(runtime=str(runtime.relative_to(root)), runtime_sha256=sha(runtime))
qa_files = ['art/fishing-v2/qc-source/sheet-qc.json'] + [f'art/fishing-v2/processed-{name}/pipeline-meta.json' for name in files]
warnings = []
for path in qa_files:
    envelope = json.loads((root/path).read_text(encoding='utf-8'))
    envelope = envelope.get('qa', envelope)
    for check in envelope.get('checks', []):
        if check.get('status') in ['warn', 'fail']:
            warnings.append({'file': path, **check})
record = {'status': 'pending_user', 'scope': 'Fishing V1 independent preview only; no formal item adoption', 'route': 'local:codex-cli', 'model': 'codex-image_gen', 'exact_model_version': 'not disclosed', 'estimateUsd': 0.0, 'prompt': 'art/fishing-v2/prompt.txt', 'receipt': 'art/fishing-v2/generated/job.json', 'source': 'art/fishing-v2/generated/generated.png', 'source_sha256': sha(source/'generated/generated.png'), 'references': [{'path': p, 'sha256': sha(root/p)} for p in ['assets/industry/v1/fishing_rod.png','prototypes/fishing-v1/art/fish.png']], 'ownership': 'art/fishing-v2/ownership.json', 'processing': '2 ownership crops; single 256; chroma_key magenta / soft / despill 1 / Lanczos / strict QC; all visible components retained', 'files': files, 'qa_files': qa_files, 'warnings': warnings, 'warning_resolution': 'Chest is fully inside its ownership cell with no crossing or edge cut; retained entire source and normalized to a padded 256 canvas. Raw safe_frame margin warning retained, processed geometry QA passes. Not an aesthetic approval.', 'runtime_rules': 'prototypes/fishing-v1/fishing_preview.gd', 'item_descriptions': {'coin': '闪闪发光，看起来很值钱。', 'locked_chest': '带着密码锁的宝箱。'}, 'no_uses_added': True}
(source/'provenance.json').write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'files': files, 'warnings': warnings}, ensure_ascii=False))
