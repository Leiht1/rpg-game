from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib
paths=['reports/ground-v04-old.png','reports/ground-v04-a.png','reports/ground-v04-b.png']
canvas=Image.new('RGB',(1920,390),'#243527');d=ImageDraw.Draw(canvas)
for i,(p,label) in enumerate(zip(paths,['OLD - V0.3','A - Simplified','B - Moderate detail'])):
 canvas.paste(Image.open(p).convert('RGB').resize((640,360)),(i*640,30));d.text((i*640+12,8),label,fill='white')
canvas.save('reports/ground-v04-comparison.png')
frames=[]
for p in sorted(Path('reports').glob('ground-v04-motion-*.png')):
 frames.append(Image.open(p).convert('RGB').crop((350,150,930,590)).resize((580,440)))
frames[0].save('reports/ground-v04-trample.gif',save_all=True,append_images=frames[1:],duration=50,loop=0)
refs=['assets/environment/cartoon_v2/tree_0.png','assets/environment/cartoon_v2/rock_0.png','reports/scene-cartoon-v2.png']
Path('art/ground_v04/selection.json').write_text(json.dumps({'status':'pending_user','approved_style_references':[{'path':p,'sha256':hashlib.sha256(Path(p).read_bytes()).hexdigest()} for p in refs],'route':'local:codex-cli','art_source':'host_image','model_receipt':'codex-image_gen; underlying precise model unknown','actual_cost':'unknown; subscription receipt estimate 0 is not verified zero cost','A':'same atlas sparse tufts, no contact decoration','B':'same base plus more tufts and sparse root leaf/rock pebble contact decoration','selected':None,'scope':'movable local test pocket 1300px radius; official default preserved'},indent=2),encoding='utf-8')
Path('art/ground_v04/QA.md').write_text('''# 地面候选 QA 与比较记录
状态 pending_user；A/B 均未正式批准，不覆盖 V0.3 原素材。
实际路线 local:codex-cli / codex-image_gen，1次受控调用；1536×1024 RGBA。真实参考附件及哈希见 selection.json 和 generated/job.json；提示词和原图完整保留。
原图警告：6个cell边界alpha最大值均为1（期望0），带明显彩色柔光雾边，不能直接作为正式素材。整理采用原生alpha>=210保留、其余透明，再按cell各自bbox裁片；各cell清理数量及crop见processing.json，不用最大连通区域删草叶。阈值会使轮廓稍硬，实际尺寸线性过滤，仍需用户视觉确认。未生成新树石或角色。
首轮场景问题：裸土贴片多且大、色彩量化产生条带，拒绝该摆放/材质版本；改为4.5%网格概率小裸土，恢复连续宽色场；B的叶片/碎石接触点缀缩小。岸边裸土新增九点干地足迹排除。当前对比截图为实际Godot渲染，不是合成新景物。
A：保留大色块，稀疏可响应草簇与少量裸土。B：同样基底增加草簇数量、少量树根叶片/石底碎石；主体纹理、尺寸、碰撞未改。左右/上下草根不会移动，根为裁片底部中心；草尖局部剪切与压低，不是角色周围跟随的贴图。
专项报告 reports/ground-v04-checks.json、ground-v04-seams.json；真实走跑/停止演示ground-v04-trample.gif。已有位移/砍树/拾取实现未改，本轮未做无关全量回归。
限制：草簇同层绘制在人物后，非逐叶遮挡；贴片近看可识别复用，测试区边界只做地色渐隐；首次挂载仍有约40ms峰值，不能宣称全程无卡顿。无新增存档/玩法。模型精确版本与实际费用未知。
''',encoding='utf-8')
p=Path('ART_STYLE.md');s=p.read_text('utf-8').replace('版本 2.0','版本 2.1',1);p.write_text(s,encoding='utf-8')
p=Path('DEVLOG.md');s=p.read_text('utf-8');s+='''

## 2026-10-16 · 美术生产标准化与地面 A/B 候选体验
- ART_STYLE 2.1、SCENE_ART_WORKFLOW、AGENTS与角色流程入口统一：正式角色/树石实际附图→少量候选→真实Godot对照→用户确认→批量推广。废止V0.3地面细化优先条款与旧的直接替换授权表述。保留旧图、原图、提示词、真实参考哈希、回执、清理坐标、候选对比及pending_user状态。
- 1次generate2dsprite受控route_media图片调用，local:codex-cli / codex-image_gen，1536×1024 RGBA，6格草/裸土/叶片/碎石；未重画主体。原图6格边缘alpha=1（期望0）、彩色柔光雾边为警告，已按alpha>=210整理，详见art/ground_v04/QA.md；不宣称全部美术QC通过，实际模型与费用未知。
- 独立Start-Ground-Preview.cmd；1旧/2A/3B，0出生、4森林/5山地/6岸边，只在所选位置1300px测试口袋切换，正式入口仍旧版。A去高频纹理、少量草簇裸土，B增适量草与区别树石接触点缀；同Seed同位置同镜头截图与实际走跑停止GIF保存reports/ground-v04-*。
- 草簇由Seed/世界网格稳定摆放，每区块一个绘制节点、无物理草碰撞，镜头外不更新；实际位移与跑态触发43px内局部草尖剪切/压低、固定根，静止指数恢复。排除水面、山地及裸土贴片区域。区块卸载释放节点，重载位置一致。
- Godot4.7.2 Stable / Compatibility / RTX3060：走路弯曲、跑步增强、静止恢复、根不平移、干地排除、同Seed重建、正式默认不变专项通过；共享边界纹理样本一致。实际检查森林/山地/水岸并修正岸边贴片越水。地形采样、原地图生成规则、树石碰撞和玩家交互代码未改；原地图生成器仍windrest-0.3.0-cartoon，新增仅视觉布局版本ground-preview-0.4.0。
- 12秒本地正常走/跑722帧：平均16.640ms、P95 17.284ms、最大30.282ms；首次区块挂载峰40.163ms、2171节点。短时采样非压力测试，首次挂载仍有尖峰；不能宣称每帧流畅。未做无关全量回归。首次调试发现脚本类型推断与预览文字编码错误，修正后实机检查通过。
- 遗留：单绘制层草叶没有人物前后逐叶排序，重复草型可识别，预览边缘仍可察觉贴片密度变化；用户视觉选择未完成。本轮到候选交付即停止，不全图推广。
''';p.write_text(s,encoding='utf-8')
p=Path('README.md');p.write_text(p.read_text('utf-8')+'\n\n当前地面候选预览：双击 Start-Ground-Preview.cmd，1旧版/2A/3B，0出生点、4森林/5山地/6水岸。WASD、Shift、E、M沿用；Start-Playtest.cmd仍为旧地面正式体验。候选生产门槛见 SCENE_ART_WORKFLOW.md，未选定不全图推广。\n',encoding='utf-8')
