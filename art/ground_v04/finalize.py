from pathlib import Path
from PIL import Image,ImageDraw
import json,re
r=json.loads(Path('reports/ground-v04-checks.json').read_text('utf-8'))
print({k:v for k,v in r.items() if k!='checks'});print('checks',len(r['checks']),'failed',sum(not x for x in r['checks'].values()))
canvas=Image.new('RGB',(1920,390),'#243527');d=ImageDraw.Draw(canvas)
for i,(name,label) in enumerate(zip(['old','a','b'],['OLD - V0.3','A - Simplified','B - Moderate detail'])):
 canvas.paste(Image.open('reports/ground-v04-'+name+'.png').convert('RGB').resize((640,360)),(i*640,30));d.text((i*640+12,8),label,fill='white')
canvas.save('reports/ground-v04-comparison.png')
frames=[Image.open(p).convert('RGB').crop((350,150,930,590)) for p in sorted(Path('reports').glob('ground-v04-motion-*.png'))]
frames[0].save('reports/ground-v04-trample.gif',save_all=True,append_images=frames[1:],duration=50,loop=0)
p=Path('DEVLOG.md');s=p.read_text('utf-8');s=s.replace('平均16.640ms、P95 17.284ms、最大30.282ms；首次区块挂载峰40.163ms',f"平均{r['mean_ms']:.3f}ms、P95 {r['p95_ms']:.3f}ms、最大{r['max_ms']:.3f}ms；首次区块挂载峰{r['chunk_install_max_ms']:.3f}ms");s+='\n- 最后针对岸边干地足迹修正重查相关候选专项；测试退出曾因创建默认Stream检查未释放出现RID/资源告警，修正测试清理后末次退出无该告警。\n';p.write_text(s,encoding='utf-8')
p=Path('art/ASSET_MANIFEST.md');s=p.read_text('utf-8');s='''> 当前生效规范为根目录 ART_STYLE.md 2.1、CHARACTER_SEQUENCE_WORKFLOW.md 与 SCENE_ART_WORKFLOW.md。下方旧完整帧/程序关节说明仅约束历史资源，不是当前生成入口。

'''+s+'\n\n## 2026-10-16 地面 V0.4 候选（pending_user）\nassets/environment/ground_v04/0..5.png；受控生成1次，真实参考树石及角色同屏，route local:codex-cli / codex-image_gen。原图/提示词/哈希回执/alpha清理/拒选与比较记录位于art/ground_v04。A/B仅可玩测试区，用户未选定，不得批量替换。\n';p.write_text(s,encoding='utf-8')
