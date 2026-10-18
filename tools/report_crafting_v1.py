from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/crafting-progress-v1'
sources=[('制作/库存','reports/crafting-v1/headless-tests.json'),('制作进度','reports/crafting-progress-v1/headless-checks.json'),('制作工具实用','reports/crafting-progress-v1/crafted-tools-runtime.json'),('重启写入','reports/crafting-v1/restart-write.json'),('重启读取','reports/crafting-v1/restart-read.json'),('UI布局','reports/ui-rework-v1/headless-checks.json'),('背包操作','reports/harvest-fix-v051/item-actions-headless.json')]
rows=[]
for name,path in sources:
    data=json.loads((ROOT/path).read_text('utf-8-sig'))
    checks=data if isinstance(data,list) else data['checks']
    failed=[x for x in checks if not x['pass']]
    assert not failed,(name,failed)
    rows.append({'name':name,'count':len(checks),'failures':0,'source':path})
summary={'engine':'Godot 4.7.2 Stable','date':'2026-10-17','checks':rows,'count':sum(x['count'] for x in rows),'failures':0,'window_progress_recheck':35,'window_source':'reports/crafting-progress-v1/window-checks.json','note':'Check-item counts across scoped suites; not exhaustive coverage. Crafted tool test uses Engine.time_scale=3 only in its headless fixture.'}
(OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
table='\n'.join(f"| {x['name']} | {x['count']} | 0 | {x['source']} |" for x in rows)
report='''# 制作系统V1收尾与制作进度

2026-10-17 · 已实现并正式接入。

按钮上方的进度条现在控制真实制作：每笔1.5秒，满格才扣除全部材料并将完整产出放入原背包；批量也一次整体结算。开始/中途没有物品变动。制作期间锁定选择/数量/按钮，关闭或切换面板取消且不扣材料，重启不保存未完成进度、不补发成品。

已补齐原制作任务的工具实用、原子事务、失败保护和跨进程验收。铲子原先骨片需求会造成先有铲子才能挖骨片的起步循环，已改为木材2/石块2/燧石1/植物纤维3；其他配方不变。正式共有六配方，完整材料表见根目录CRAFTING_SYSTEM.md。

## 修改职责

- scripts/item_service.gd：单笔临时任务、每帧进度、取消与完成前重新验证；复用原craft/原子快照，无新存档字段。
- scripts/craft_ui.gd：固定空间进度条、过程锁定、成功/失败/取消反馈及数量输入处理；主框仍1030×600。
- scripts/craft_book.gd / data/recipes.json：校验0.1–30秒制作时间，正式配方各1.5秒，修复铲子起步材料。
- scripts/item_ui_style.gd：数量只读仍用同纸布样式；scripts/item_ui.gd的Tooltip只显示实际可用操作。
- 原始ItemInventory私有副本交换、三工具独立实例、提灯/补给包功能沿用前轮已实现代码，本次完成其相关验收，不重写工作系统。
- 测试：test_crafting_progress_v1.gd、test_crafted_tools_runtime_v1.gd及必要旧制作/重启/UI夹具；文档为CRAFTING_SYSTEM.md、ITEM_SYSTEM.md、EQUIPMENT_SYSTEM.md、UI_ART.md、README.md和DEVLOG.md。

## 事务、存档与资源

开始先检查材料/完整空间，走满再按当前状态复查。只有原ItemInventory副本上消耗和成品全部成功，才一次替换活库存并发changed。满包、材料改变、保护存档、取消、重复启动或回调重入均不会部分扣料/补发。非堆叠工具生成独立实例，可拖入快捷栏并装备原能力。原Seed、生成器/采集版本、原存档路径与未知版本保护不变；进度、选择、配方不写玩家档。

没有新PNG或新美术生成；使用用户已认可的assets/ui/rework_v1及refine_v1纸布资源，进度条为原生辅助控件。既有材质源图、prompt、回执与哈希见UI_ART.md和reports/ui-rework-v1/REPORT.md。提灯原画追溯在assets/ui/v1/provenance.json及art/ui-v1/candidate-01。

## 实际测试

| 范围 | 检查项 | 失败 | JSON证据 |
|---|---:|---:|---|
'''+table+f'''

共{summary['count']}个检查项通过。进度还在真实Windows / RTX5060 / Compatibility窗口复核35项并核图。工具实用以3倍测试时钟执行原生E砍树、石矿5次完整开采、骨片完整挖掘、普通拾取；正式动作/速度未变。UI布局覆盖960×540、1280×720、1600×900逻辑尺寸，并保持操作期间框体不伸缩。跨进程写/读保留成品、实例state、装备引用、地面/采集记录，并确认未完成任务只保留原材料。

初次进度测试发现非聚焦时apply旧编辑文本覆盖已选数量，已修正；追加原生数量输入测试需等待SpinBox焦点初始化，已修正测试时序后通过。工具初次夹具手工清理掉落未同步注册数组导致释放引用，已修正夹具并完整重跑，没有改生产采集逻辑。历史失败日志保留，不计通过。没有运行无关全量回归或FPS压力基准。

## 运行截图与状态

- making.png：真实窗口制作进行中，材料尚未扣除，按钮上方进度条推进。
- complete.png：真实窗口进度满后，库存和材料已原子结算。
- summary.json：本轮范围内最终结果索引。

制作系统V1及新增进度已接入，列出的测试已实际运行；当前无已知功能阻塞。主观视觉待玩家试玩，未声称所有Seed穷举或性能基准。下一阶段的工作台、自由建造、冶炼、战斗和NPC未实现，也未纳入本轮范围。完成本轮后停止。
'''
(OUT/'REPORT.md').write_text(report,encoding='utf-8')
(OUT/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>风栖原野 · 制作V1与进度</title><style>body{margin:32px auto;max-width:1280px;padding:0 24px;background:#f5efdf;color:#564a3a;font:16px/1.7 system-ui}img{max-width:100%;height:auto}a{color:#607447}</style><h1>物品制作V1 · 进度满后完成</h1><p>每笔1.5秒，按钮上方显示进度。满格才原子扣料/入包；关闭取消未完成操作，UI大小不变。</p><p><a href="REPORT.md">完整报告与测试</a> · <a href="../../CRAFTING_SYSTEM.md">六条正式配方与系统规则</a></p><h2>制作中</h2><img src="making.png"><h2>制作完成</h2><img src="complete.png">''',encoding='utf-8')
readme=ROOT/'README.md'
intro='> 2026-10-17 · 制作V1：C或快捷栏“C 制作”打开六配方面板，每笔1.5秒，按钮上方进度满后整体扣料/入包；关闭取消未完成制作，材料不动。UI保持已确认纸布风格与固定尺寸。[配方规则](CRAFTING_SYSTEM.md) · [进度实景与验收](reports/crafting-progress-v1/index.html)。\n\n'
if not readme.read_text('utf-8-sig').startswith(intro):readme.write_text(intro+readme.read_text('utf-8-sig'),encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2))
