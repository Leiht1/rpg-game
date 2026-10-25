from pathlib import Path
p=Path('reports/ore-collision-v1/REPORT.md');p.write_text('''# 可采集矿石碰撞修订

旧五类矿石共用居中31×17椭圆，但画稿主体偏左、底座轮廓宽度和深度不同。data/harvest_resources.json为石矿、燧石、铜、银、金分别增加collision_outline（基准显示宽192）；harvest_node按实际显示尺寸应用多边形，其他资源沿原椭圆或无碰撞规则。轮廓考虑画稿底座及左右少量身体余量，避免只有脚底接触而肩膀嵌入石头。保留原Y排序和画稿定位，未改变生成、开采次数、掉落或存档。

Godot4.7.2真实窗口专项：五类矿石各从左右前后实际靠近，检查阻挡且仍在开采距离内，并验证完成反馈移除碰撞，共25项；最终结果见checks.json、window.log。各矿石左侧贴边实景为*-left.png。夹杂水域的初版测试场景被修正为四侧可走的干燥地面，最终记录不含该场景影响。本轮未重复联网或全量测试。
''',encoding='utf8')
for file,entry in [('DEVLOG.md','## 2026-10-25 · 可采集矿石碰撞\n\n五类矿石由共用椭圆改为按画稿底座设置的独立轮廓，修正偏左主体和侧面身体余量；其他采集物保持原规则。测试及实景见reports/ore-collision-v1/REPORT.md。\n\n'),('ITEM_SYSTEM.md','\n\n## 2026-10-25 · 矿石实体轮廓\n\nharvest_resources中的可选collision_outline以collision_outline_width为显示基准，harvest_node同比缩放应用；五类矿石按底座及侧面人物身体余量分别配置。未配置的资源继续原碰撞方式，完成采集仍移除实体。验证见reports/ore-collision-v1/REPORT.md。\n')]:
 p=Path(file);old=p.read_text(encoding='utf-8-sig');p.write_text(entry+old if file=='DEVLOG.md' else old+entry,encoding='utf8')
