"""Publish the approved v11 side walk as complete, unchanged PNG frames."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
HERO = ROOT / 'assets/hero'
WORK = ROOT / 'art/hero_v11_runtime_v05'
SOURCE = ROOT / 'art/hero_v08_pose_redraw_preview_v11'
VERSION = 'windrest-character-template-5'


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def stage():
    assert not WORK.exists(), 'Preserve the integration snapshot; do not restage.'
    WORK.mkdir(parents=True)
    shutil.copytree(HERO, WORK / 'previous_runtime')
    for name in ['CHARACTER_MODULAR_RULES.md', 'README.md', 'DEVLOG.md',
                 'tools/verify_character.py', 'tests/test_player.gd',
                 'tests/test_character_smoke.gd', 'reports/CHARACTER_VALIDATION.md',
                 'reports/character-art-tests.json', 'reports/character-smoke-tests.json',
                 'reports/character-smoke-poses.png', 'reports/character-world.png',
                 'reports/character-godot-poses.png']:
        path = ROOT / name
        if path.exists():
            shutil.copy2(path, WORK / ('previous_' + path.name))
    baseline = {str(p.relative_to(ROOT)).replace('\\', '/'): sha(p)
                for folder, pattern in [('scripts', '*.gd'), ('scenes', '*.tscn')]
                for p in (ROOT / folder).rglob(pattern)}
    baseline['project.godot'] = sha(ROOT / 'project.godot')
    save(WORK / 'unchanged_game_baseline.json', baseline)
    staged = WORK / 'staged'
    for folder in ['final_sprite', 'animation', 'modular_plan', 'reference']:
        (staged / folder).mkdir(parents=True)
    for path in (HERO / 'final_sprite').glob('*.png'):
        shutil.copy2(path, staged / 'final_sprite' / path.name)
    for name in ['animation/clips.json', 'animation/registration.json',
                 'animation/runtime.json', 'modular_plan/template.json']:
        shutil.copy2(HERO / name, staged / name)
    registration = read(staged / 'animation/registration.json')
    registration['template_version'] = VERSION
    registration['source'] = ('User-approved v11 side walk; front/back walk v04 and '
                              'all idle v05 preserved from template 4. No new art during integration.')
    registration['source_provenance'].append('art/hero_v08_pose_redraw_preview_v11/provenance.json')
    template = read(staged / 'modular_plan/template.json')
    template['version'] = VERSION
    runtime = read(staged / 'animation/runtime.json')
    runtime['template_version'] = VERSION
    for i in range(8):
        source = SOURCE / f'right_walk_preview/frames/right_walk_{i:02}.png'
        with Image.open(source) as im:
            assert im.mode == 'RGBA' and im.size == (128, 128), str(source)
        key = f'side_walk_{i:02}'
        shutil.copy2(source, staged / f'final_sprite/{key}.png')
        digest = sha(source)
        record = next(f for f in registration['directions']['side']['frames'] if f['name'] == key)
        record.update(source=str(source.relative_to(ROOT)).replace('\\', '/'),
                      source_sha256=digest, output_sha256=digest, source_frame=i,
                      source_to_output_scale=1.0, offset=[0, 0], source_root=[64, 112],
                      output_anchor=[64, 112],
                      operation='Byte-identical approved v11 complete PNG; right maps to side; no resampling.')
        pose = next(f for f in template['directions']['side']['frames'] if f['key'] == key)
        pose['sha256'] = digest
    for name, value in [('animation/registration.json', registration),
                        ('animation/runtime.json', runtime), ('modular_plan/template.json', template)]:
        save(staged / name, value)
    untouched = {p.name: sha(p) for p in (HERO / 'final_sprite').glob('*.png')
                 if not p.name.startswith('side_walk_')}
    assert len(untouched) == 28
    save(WORK / 'unchanged_frames.json', untouched)
    review = Image.new('RGB', (12 * 128, 3 * 148), '#e3e9ce')
    draw = ImageDraw.Draw(review)
    for row, direction in enumerate(['front', 'back', 'side']):
        keys = [f'{direction}_idle_{i:02}' for i in range(4)] + [f'{direction}_walk_{i:02}' for i in range(8)]
        for col, key in enumerate(keys):
            frame = Image.open(staged / f'final_sprite/{key}.png')
            review.paste(frame, (col * 128, row * 148 + 20), frame)
            draw.text((col * 128 + 3, row * 148 + 4), key, fill='#374533')
    review.save(staged / 'reference/frame-review.png')
    overlay = review.copy()
    draw = ImageDraw.Draw(overlay)
    for row in range(3):
        for col in range(12):
            x, y = col * 128 + 64, row * 148 + 132
            draw.line((x - 15, y, x + 15, y), fill='#c96545')
            draw.line((x, y - 105, x, y + 5), fill='#d6ab44')
    overlay.save(staged / 'modular_plan/pose-templates.png')
    preview = []
    for tick in range(0, 216, 3):
        image = Image.new('RGB', (512, 296), '#e3e9ce')
        draw = ImageDraw.Draw(image)
        for col, direction in enumerate(['front', 'back', 'side', 'side']):
            for row, action, index in [(0, 'idle', tick // 27 % 4),
                                       (1, 'walk', int(tick / 60 * 115 / (200 / 3) * 8) % 8)]:
                frame = Image.open(staged / f'final_sprite/{direction}_{action}_{index:02}.png')
                if col == 3:
                    frame = frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                image.paste(frame, (col * 128, row * 148 + 20), frame)
                draw.text((col * 128 + 4, row * 148 + 4),
                          ['front', 'back', 'right', 'left'][col] + ' ' + action, fill='#374533')
        preview.append(image)
    preview[0].save(staged / 'reference/animation-preview.webp', save_all=True,
                    append_images=preview[1:], duration=50, loop=0, lossless=True)
    save(WORK / 'acceptance.json', {
        'date': '2026-10-15', 'userApproval': '接入游戏吧',
        'acceptedPreview': 'art/hero_v08_pose_redraw_preview_v11',
        'scope': 'Replace eight side_walk PNGs only; preserve all 28 front/back walk and idle PNGs.',
        'selection': 'take2, original indices 0..7; v08 pose design; whole-frame left mirror',
        'template': VERSION, 'art_source': 'existing', 'newImageCalls': 0, 'newVideoCalls': 0,
        'scale': 1.0, 'offset': [0, 0], 'canvas': [128, 128], 'anchor': [64, 112],
        'movement_speed': 115, 'stride_world_units': 200 / 3, 'idle_cycle_ms': 1800,
        'sourceQA': 'Source needs-visual-review entries retained; user acceptance does not rewrite QA.'})
    print(json.dumps({'staged': str(staged), 'replacement_frames': 8, 'preserved_frames': 28,
                      'template': VERSION}))


def publish():
    staged = WORK / 'staged'
    engine = WORK / 'engine/godot'
    assert (engine / 'hero.tres').exists(), 'Export through generate2dsprite first.'
    assert read(WORK / 'engine/engine-export.json')['qa']['status'] == 'pass'
    for name, digest in read(WORK / 'unchanged_frames.json').items():
        assert sha(HERO / 'final_sprite' / name) == digest, 'Runtime changed since staging: ' + name
    for folder in ['final_sprite', 'animation', 'modular_plan', 'reference']:
        for path in (staged / folder).iterdir():
            if path.is_file():
                shutil.copy2(path, HERO / folder / path.name)
    for path in engine.iterdir():
        if path.is_file():
            shutil.copy2(path, HERO / 'animation' / path.name)
    shutil.copy2(ROOT / 'CHARACTER_MODULAR_RULES.md', HERO / 'modular_plan/CHARACTER_MODULAR_RULES.md')
    print(json.dumps({'published': str(HERO), 'replacement_frames': 8, 'template': VERSION}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('step', choices=['stage', 'publish'])
    args = parser.parse_args()
    {'stage': stage, 'publish': publish}[args.step]()
