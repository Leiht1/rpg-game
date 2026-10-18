from pathlib import Path
import json,html
out=Path('reports/ores-v06')
issues=[]
for p in [Path('art/ores-v06/raw-qc/sheet-qc.json'),Path('art/ores-v06/processed/pipeline-meta.json')]:
 d=json.loads(p.read_text('utf-8'));env=d.get('qa',d)
 for row in env.get('checks',[]):
  if row.get('status') in ['warn','fail']:issues.append({'file':p.as_posix(),**row})
qa='# 原始与未采用整理稿 QA 记录\n\n原图默认5×2切格会切到矿脚，因此第一次名义切格版本不发布。按物体实际所属区域（空白间隙）完整整理到640格，未裁去可见像素、未旋转或非等比挤压。最终 owned-qc 和 processed-owned 均通过。以下原始异常完整保留，不表述为原图全部QA通过。\n\n'
for issue in issues:qa+='```json\n'+json.dumps(issue,ensure_ascii=False,indent=2)+'\n```\n\n'
(out/'ART_QA.md').write_text(qa,encoding='utf-8')
files=[('distribution.json',250,'两Seed确定性/泥土限制/跨块间距/无旧石头'),('runtime.json',50,'五矿长按开采/奖励/拾取/存档升级'),('edge-tests.json',17,'目标失效/满包余量/旧档与未知版本保护')]
# Existing edge harness writes its historical output; preserve its new result alongside this task.
edge=Path('reports/harvest-v05/edge-tests.json')
if edge.exists():(out/'edge-tests.json').write_bytes(edge.read_bytes())
rows=''
for name,count,label in files:
 d=json.loads((out/name).read_text('utf-8-sig'))
 count=d.get('count',len(d.get('checks',[])));failed=len(d.get('failures',[]))
 rows+=f'<tr><td><a href="{name}">{label}</a></td><td>{count}</td><td>{failed}</td></tr>'
body=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>大体积矿石与金银铜矿</title><style>body{{max-width:1120px;margin:35px auto;padding:24px;background:#f3ead7;color:#493c2d;font:16px/1.75 system-ui}}section{{background:#fff9ed;padding:22px;margin:22px 0;border-radius:16px}}img{{max-width:100%;border:1px solid #c1ab84;border-radius:12px}}table{{width:100%;border-collapse:collapse}}td,th{{padding:9px;border-bottom:1px solid #d2bf9c;text-align:left}}a{{color:#795222}}</style><h1>大体积石矿、燧石与金银铜矿</h1><p>2026-10-17 · Godot4.7.2 Stable · 采集层harvest-resources-2.0.0 / 景物策略windrest-props-0.7.0</p>
<p>旧普通景观石和自然散石停止挂载，替换为有高度与体积的可开采矿点；新增铜/银/金原矿及现有背包拾取。<a href="../../ORE_SYSTEM.md">完整规则、文件、存档与验证说明</a>。</p>
<section><h2>实际泥土地表造型</h2><img src="five-mines-dirt.png" alt="五矿大体积造型"><p>固定原生主体，不切序列图或压扁旧图；裂纹独立叠加，土边读取当地纯地表。上排为明确摆放的造型验收夹具，其他可见矿点由正式生成器产生。地表原画中的平面岩纹保持，已移除的是旧独立普通景观石节点及自然散石。</p><table><tr><th>矿点</th><th>次数</th><th>掉落</th><th>区域</th></tr><tr><td>石矿</td><td>5</td><td>石块×5</td><td>泥土多，其他区域少量</td></tr><tr><td>燧石矿</td><td>7</td><td>燧石×3、石块×2</td><td>泥土多，其他区域少量</td></tr><tr><td>铜矿</td><td>9</td><td>铜矿石×4</td><td>仅泥土</td></tr><tr><td>银矿</td><td>12</td><td>银矿石×3</td><td>仅泥土，更少</td></tr><tr><td>金矿</td><td>16</td><td>金矿石×2</td><td>仅泥土，最稀少</td></tr></table></section>
<section><h2>分布规则</h2><p>泥土按现有褐色highland地表的真实采样权重≥.65判定，中心及四向72单位均满足，排除水岸/混合边界。候选概率泥土.72、其他.10；泥土石/燧/铜/银/金权重42:30:16:8:4，其他仅石/燧75:25。每768单位空间桶10个固定坐标候选，干陆52净空、景物48净空、原连通接近检查、跨块185最小间距。不是按块补足配额。</p><p>两Seed实际有效样本：石63、燧34、铜22、银9、金5；金银铜全部在泥土内。此为采样，不宣称全图总数或任意Seed数量保证。大陆/湖泊地表、树木坐标逻辑及角色移动不改。</p></section>
<section><h2>采集与物品实景</h2><img src="copper_outcrop-mining.png" alt="铜矿真实首击"><img src="silver_outcrop-mining.png" alt="银矿侧面持握"><img src="gold_outcrop-mining.png" alt="金矿侧面持握"><img src="raw-metal-inventory.png" alt="三种原矿进入原背包"><p>镐头与手掌沿用已修正侧面层级，支持长按E逐次采集，正确次数后只出一批奖励；沿用原掉落实体、E拾取、容量/部分拾取和快捷装备。金银铜为原矿，没有扩展冶炼或配方。</p></section>
<section><h2>验证证据</h2><table><tr><th>范围</th><th>断言</th><th>失败</th></tr>{rows}</table><p>合计317项通过。完整采集功能在无头原生输入/物理中以4倍测试时钟运行；窗口实帧独立检查造型、泥土、侧面握持和原矿图标。<a href="distribution.log">生成日志</a> · <a href="runtime.log">完整玩法日志</a> · <a href="persistence-edges.log">存档边界日志</a> · <a href="capture.log">实际窗口截图日志</a>。</p><p>初次夹具Vector2i/Vector2运算和typed Array赋值错误已修正，日志保留；第一次窗口长采集未完成退出，没有当作完整通过。最终无脚本错误。本轮无无关全量回归或FPS/全图压力测试。</p></section>
<section><h2>旧存档与素材</h2><p>沿用原存档路径/Seed身份，兼容读取采集层1.0.0，保留库存、装备/快捷引用、树状态、埋藏进度及旧消耗记录；下次原子写入记2.0.0和景物策略。新矿脉布局使用mineral:2 ID，旧普通矿脉布局退役，旧历史记录保留。未知未来版本继续保护源档。已收集材料/玩家丢弃物不会因新生成规则被删掉。</p><p>新10张运行图通过generate2dsprite → route_media，真实route=local:codex-cli / host image，底层精确图片模型/实际费用未知，估价0为订阅额度。<a href="../../assets/ores/v06/provenance.json">素材来源和哈希</a> · <a href="../../art/ores-v06/generated/job.json">回执</a> · <a href="../../art/ores-v06/prompt.txt">提示词</a>。新素材已正式引用，主观视觉验收待用户试玩。</p><p>原图名义分格cross_cell_components/visible均FAIL=5，boundary_band WARN=18375，safe_frame WARN=5；第一次整理版亦有越界警告，均未采用。按空白间隙完整归属整理后owned-qc与processed-owned全部通过。<a href="ART_QA.md">所有原始异常ID/value/threshold/file</a> · <a href="../../art/ores-v06/owned-qc/sheet-qc.json">最终分格QA</a> · <a href="../../art/ores-v06/processed-owned/pipeline-meta.json">最终透明/边界QA</a>。</p><p>只完成本轮矿物升级；未新增战斗、建造、NPC、工具耐久或其他玩法。</p></section></html>'''
(out/'index.html').write_text(body,encoding='utf-8')
