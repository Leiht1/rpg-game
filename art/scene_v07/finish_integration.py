from pathlib import Path
import json,hashlib
before=json.loads(Path('art/scene_v07/integration-before.json').read_text())
unchanged={p:hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in before.items()}
assets={p.name:{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'source':'approved prototypes/scene-study-v07; see art/scene_v07/processing.json and job receipts'} for p in Path('assets/environment/stylized_v3').glob('*.png')}
result={'status':'user_approved_integrated','art_version':'scene-stylized-3.0','map_generator_version':'windrest-0.3.0-cartoon','unchanged_files':unchanged,'assets':assets,'ground_sampling':'world coordinates, spawn anchored, 1280x720 triangle-wave mirror; no new image generation','decorations':'original prop coordinates; visual-only thinning with salt682 and clearing radius160; no physics/prop-generation change','checks':'reports/scene-v3-integration-tests.json','limitations':['ground mirror repetition can be recognized over long travel; not a newly authored seamless texture','original raw-sheet layout/glow warnings retained in QA.md','no performance benchmark or unrelated full regression']}
Path('art/scene_v07/integration.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
assert all(unchanged.values()),unchanged
print(json.dumps({'unchanged_files':unchanged,'assets':len(assets)}))
p=Path('README.md');s=p.read_text(encoding='utf-8-sig');s='''> 当前场景美术（2026-10-16）：已确认的自然绿轻手绘 V0.7 正式接入。双击 **Start-Playtest.cmd** 游玩；WASD移动、Shift奔跑、E砍树/拾取、M地图。树石、地表和低密度花叶使用 `assets/environment/stylized_v3`，无踏草反馈。主角及玩法保持。专项结果见 `reports/scene-v3-integration-tests.json`，实际出生点画面见 `reports/scene-v3-after.png`。历史预览与下文旧版本记录仅供追溯。

'''+s;p.write_text(s,encoding='utf-8')
