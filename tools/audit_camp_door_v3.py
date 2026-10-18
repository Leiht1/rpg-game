from pathlib import Path
import hashlib,json
rows=[]
for folder in ['v1','v2']:
 base=Path('assets/buildings')/folder
 data=json.loads((base/'provenance.json').read_text(encoding='utf-8-sig'))
 for row in data['frames']:
  name=f"frame-{row['frame']:02}.png" if folder=='v1' else row['file']
  path=base/name
  rows.append({'file':str(path),'matches_approved':hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256']})
Path('reports/camp-door-v3/art-audit.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print('PNG unchanged:',sum(r['matches_approved'] for r in rows),'/',len(rows))
p=json.loads(Path('reports/camp-door-v3/surface-pixels.json').read_text(encoding='utf-8'))
print('Surface cases:',len(p['cases']),'failed:',p['failed'],'max channel delta:',max(r['max_channel_difference'] for r in p['cases']))
