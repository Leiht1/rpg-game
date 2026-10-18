from pathlib import Path
import json,hashlib,html
out=Path('reports/harvest-v05')
checks=[]
for folder in ['assets/items/v03','assets/tools/v04']:
 root=Path(folder);data=json.loads((root/'provenance.json').read_text('utf-8-sig'))
 files=data['files']
 if isinstance(files,dict):pairs=files.items()
 else:pairs=[(Path(r['file']).name,r['sha256']) for r in files]
 for name,sha in pairs:
  p=root/name
  checks.append(dict(file=p.as_posix(),pass_=p.exists() and hashlib.sha256(p.read_bytes()).hexdigest()==sha))
(out/'approved-art-protection.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
# Preserve every raw warning/failure, with exact IDs, values, thresholds and paths.
issues=[]
for file in [Path('art/harvest-v05/raw-qc/sheet-qc.json'),Path('art/harvest-v05/frame-qc/sheet-qc.json')]:
 data=json.loads(file.read_text('utf-8'))
 for check in data['checks']:
  if check['status'] in ['warn','fail']:issues.append(dict(file=file.as_posix(),**check))
qa='# 美术 QA 原始异常记录\n\n原始留白警告保留；透明处理器检查通过。frame-qc 将这张包含岩石、骨片、根茎、补给包和碎屑的混合道具图集当成同一人物动画，人物头部比例、躯干漂移、脚底和帧间接缝指标不适用于本图集。该诊断原样保留，不宣称所有 QA 通过，也不将它当作角色动作检查。本轮角色动作来自原生支点关键帧，实际检查见 native-actions.gif。\n\n'
for issue in issues:
 qa+='```json\n'+json.dumps(issue,ensure_ascii=False,indent=2)+'\n```\n\n'
(out/'ART_QA.md').write_text(qa,encoding='utf-8')
p=Path('assets/harvest/v05/provenance.json');data=json.loads(p.read_text('utf-8'));data['qa'].append('Mixed-prop character-frame diagnostic: identity_head_ratio FAIL, torso_drift/row_baseline/seam WARN; inapplicable character-motion metrics, exact values/thresholds in reports/harvest-v05/ART_QA.md. Retained without concealing failure.');p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('approved art protection',sum(r['pass_'] for r in checks),'/',len(checks))
print('QA issues',[(r['id'],r['status']) for r in issues])
