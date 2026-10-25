from pathlib import Path
import json,hashlib
from PIL import Image
p=Path('reports/mine-blast-v4');files=sorted(p.glob('fx-*.png'))
frames=[Image.open(f).convert('P',palette=Image.Palette.ADAPTIVE,colors=128) for f in files]
frames[0].save(p/'blast-preview.gif',save_all=True,append_images=frames[1:],duration=50,loop=0)
checks=[]
for path in sorted(Path('assets/exploration/mine-blast-v4').glob('*.png')):
 im=Image.open(path);a=im.getchannel('A');checks.append({'file':path.name,'size':im.size,'alpha_extrema':a.getextrema(),'bbox':a.getbbox(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(p/'assets-qc.json').write_text(json.dumps(checks,indent=2),encoding='utf8')
report='''# 矿洞爆破 V4

旧序列尾部的大烟团重新缩成地面小烟，逐帧碎石也不是连续物体；二维对齐或插值无法修正运动语义。因此停用旧16帧合成，重新绘制并拆分为8帧向外爆闪、独立碎石和独立烟尘。

素材通过 generate2dsprite / generate2dmedia 的本地 codex-cli 图像生成路线制作。原图、提示、任务来源见 art/mine-blast-v4 的两个 source 目录；package.py负责按格切分、去品红及边缘残色，输出透明PNG。assets-qc.json记录尺寸、alpha、边界及SHA。未将素材统计称为审美验收。

每块碎石只创建一次，固定方向抛出后落下，横向不会折返；烟尘同样只创建一次，沿各方向扩散、上飘、放大并逐渐减淡，爆闪结束后继续保留，4.8秒消失。实际单调时钟采样，不改变爆破权威或资源消耗。

用户追加要求后，爆心从矿洞基点y+35上移到y-30，共65世界单位；三层共用同一根节点，从洞口出发。五秒倒计时与带图标、文字、进度条的过场保持原有逻辑。

验证：Godot4.7.2真实窗口专项4项通过（逐颗碎石横向不折返、烟尘连续减淡、爆闪后仍有残烟、尾段完全隐藏），97张实际窗口采样组成blast-preview.gif，已查看爆闪和消散阶段。必要矿洞回归38项0失败，日志regression.log。本轮未重复双端、异机及多尺寸测试；视觉效果仍以试玩反馈为准。
'''
(p/'REPORT.md').write_text(report,encoding='utf8')
for name,entry in [('PROJECT_STATUS.md','- 2026-10-25 爆破V4：重新生成分层爆闪/碎石/烟尘，碎石固定向外抛落，烟尘扩散并缓慢淡出4.8秒；爆心上移65世界单位至洞口。专项4项、矿洞回归38项通过。[实景与来源](reports/mine-blast-v4/REPORT.md)。\n\n'),('DEVLOG.md','## 2026-10-25 · 矿洞爆破V4与洞口爆心\n\n检查确认旧画稿尾段存在烟尘回缩和石子不连续，改为新绘制8帧爆闪加独立绘制碎石/烟尘。每颗碎石保持同一向外轨迹，残烟扩散上飘并缓慢消散；按追加反馈爆心上移65世界单位到洞口。真实窗口专项4项及矿洞回归38项通过，未重复双端/多尺寸；来源、实景与范围见reports/mine-blast-v4/REPORT.md。\n\n')]:
 path=Path(name);old=path.read_text(encoding='utf-8-sig');at=old.find('## 当前进度')+len('## 当前进度\n\n') if name=='PROJECT_STATUS.md' else 0
 path.write_text(old[:at]+entry+old[at:],encoding='utf8')
path=Path('EXPLORATION_SYSTEM.md')
with path.open('a',encoding='utf8') as f:f.write('\n\n## 2026-10-25 后续：爆破V4分层及洞口爆心\n\nV4替代上述V2/V3合成序列：8帧绘制爆闪，独立绘制碎石各自固定向外抛落，独立烟尘一次生成后扩散/上飘/渐隐，4.8秒尾段结束。禁止晚段重新在中心生成或把烟尘逐帧缩回碎石。运行资源见data/mine_rules.json，所有层共用MineView.BLAST_OFFSET=(0,-30)，比此前爆心上移65世界单位至洞口。倒计时与过场事务不变。来源及验证见reports/mine-blast-v4/REPORT.md。\n')
