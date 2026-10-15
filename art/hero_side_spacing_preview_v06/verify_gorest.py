"""Read-only post-publish check against the saved live-library snapshot."""
from pathlib import Path
import json
from PIL import Image
OUT=Path(__file__).resolve().parent
GEN=Path(r'C:/Users/HT/Documents/Codex/2026-10-15/https-github-com-0x0funky-agent-sprite/outputs/gorest-2d-animation-spritesheet-generator-main/public/generated')
before=json.loads((OUT/'gorest_library.before.json').read_bytes())
after=json.loads((GEN/'game_asset_library.json').read_bytes())
changed=[f'asset_windrest_hero_{di}_walk_v04' for di in ['right','left']]
assert [a['id'] for a in before['assets']]==[a['id'] for a in after['assets']]
assert all(a==b for a,b in zip(before['assets'],after['assets']) if a['id'] not in changed)
assert all(before[k]==after[k] for k in before if k not in ['assets','updatedTime'])
for di,aid in zip(['right','left'],changed):
    a=next(a for a in after['assets'] if a['id']==aid);s=a['sprite']
    href=f'/generated/windrest_hero_{di}_walk_v06.png'
    assert a['confirmed'] is False and s['previewOnly'] is True
    assert s['spritesheetPng']==href and s['frameCount']==8 and s['fps']==12
    assert len(s['frames'])==8 and all(href in f for f in s['frames'])
    for clip in a['animations']:assert clip['sprite']==s and clip['fps']==12
    assert (GEN/f'windrest_hero_{di}_walk_v06.png').read_bytes()==(OUT/f'{di}_walk_preview/{di}_walk_sheet.png').read_bytes()
    assert Image.open(GEN/f'windrest_hero_{di}_walk_v06.png').size==(512,256)
(OUT/'gorest_library_change.json').write_text(json.dumps({'status':'pass','changedIds':changed,
    'assetCount':len(after['assets']),'idAndOrderPreserved':True,'otherAssetsUnchanged':True,
    'otherDataUnchanged':True,'sheetCopiesMatch':True,'confirmed':False,
    'note':'Initial publisher post-write comparison used Python tuples for bboxes against JSON lists. Corrected comparison; read-only verification confirms actual published data and unchanged unrelated assets.'},indent=2)+'\n',encoding='utf-8')
print(f'Pass: 2 updated walk previews; {len(after["assets"])-2} other entries, IDs/order and scene data unchanged.')
