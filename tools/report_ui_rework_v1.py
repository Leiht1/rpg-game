from pathlib import Path
import json,html
ROOT=Path(__file__).resolve().parents[1]
report=ROOT/'reports/ui-rework-v1'
qa=[]
for sub in ['rework_v1','refine_v1']:
    path=ROOT/'assets/ui'/sub/'provenance.json'
    value=json.loads(path.read_text('utf-8'))
    value['status']='integrated_per_current_task_visual_review_pending'
    value['runtime_review']='reports/ui-rework-v1/REPORT.md'
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2),encoding='utf-8')
    qa.append(f"## {value['version']}\n\n源图尺寸：{value['source_size']}。运行切片的透明外沿、内容区alpha/亮度QA均通过，详见来源记录。\n")
    if sub=='refine_v1':
        qa.append('WARN `source_size_mismatch`: value=1254×1254, requested=1024×1024; file=art/ui-rework-v1/refine-01/generated.png。使用真实尺寸整理。\n')
    cell_w=value['source_size'][0]/(3 if sub=='rework_v1' else 2)
    cell_h=value['source_size'][1]/2
    for index,row in enumerate(value['files']):
        own=row['ownership'];bbox=row.get('source_bbox',row.get('bbox_in_ownership'))
        x0,y0,x1,y1=own[0]+bbox[0],own[1]+bbox[1],own[0]+bbox[2],own[1]+bbox[3]
        cols=3 if sub=='rework_v1' else 2
        cell_x=(index%cols)*cell_w;cell_y=(index//cols)*cell_h
        margin=min(x0-cell_x,y0-cell_y,cell_x+cell_w-x1,cell_y+cell_h-y1)
        requested=48 if sub=='rework_v1' else 40
        if margin<requested:
            qa.append(f"WARN `nominal_cell_margin`: value={margin:g}px, requested>={requested}px; asset={row['file']}; source={value['source']}。名义格线不用于裁图，实际完整归属框已记录且不截可见像素。\n")
qa.append('无发布的最终切片FAIL；上述生成排版WARN保留，不以数字QA代替主观美术验收。')
(report/'ART_QA.md').write_text('# UI美术来源与整理QA\n\n'+'\n'.join(qa),encoding='utf-8')
cards=[('背包与装备','inventory-1280.png'),('Tooltip','tooltip-1280.png'),('快捷栏选中','hud-selected.png'),('材料不足','craft-insufficient.png'),('制作成功','craft-success.png'),('长详情固定滚动','craft-five-materials.png'),('960×540逻辑视口','craft-960.png'),('1600×900逻辑视口','craft-1600.png')]
body=''.join(f'<figure><img src="{f}" alt="{html.escape(t)}"><figcaption>{html.escape(t)}</figcaption></figure>' for t,f in cards)
(report/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>风栖原野 · UI返工实景</title><style>body{margin:32px auto;max-width:1280px;padding:0 24px;background:#f4eedf;color:#544938;font:16px/1.7 system-ui}img{display:block;max-width:100%;height:auto}figure{margin:28px 0}figcaption{padding:8px 0}a{color:#5f704b}.compare{display:grid;grid-template-columns:1fr 1fr;gap:18px}</style><h1>轻量旅行手册 · 最终实景</h1><p>无四角包角的薄边物品槽，新版轻按钮。主纸面和Tooltip保留。背包/制作点击与切换不伸缩；32项UI专项＋55项交互依赖通过。<a href="REPORT.md">详细报告</a> · <a href="ART_QA.md">来源QA</a></p><h2>用户局部参考</h2><div class="compare"><img src="../../art/ui-rework-v1/references/user-slot.png" alt="旧包角槽"><img src="../../art/ui-rework-v1/references/user-buttons.png" alt="旧按钮"></div>'''+body+'<h2>推广前样板</h2><img src="pilot.png"><h2>上一轮细线框失败版</h2><img src="before/inventory-equipment.png">',encoding='utf-8')
log=ROOT/'DEVLOG.md'
with log.open('a',encoding='utf-8') as file:
    file.write('''\n\n## 2026-10-17 · 核心UI手绘美术专项及槽位/按钮精修（core-ui-art-2.1.0）

- 本轮按最新任务仅改核心UI资源与必要视觉布局，复用当前背包/装备/快捷栏/制作功能；没有修改物品服务、配方、工具能力、地图、动画或存档格式/路径。前轮制作大任务在停止时留下的实现保留，本条不宣称其全部玩法验收完成。
- 先诊断厚木箱和纯线框两种失败方向，建立UI_ART.md。使用generate2dsprite → route_media → local:codex-cli / host_image，生成纸页/布衬/布签/纸笺和独立小枝叶，先做原生pilot实景核图再推广。主面板、分区、槽、Tooltip的视觉重量区分；文字安全区无装饰，数量改12px深暖棕、不用粗阴影；外缘枝叶忽略鼠标。
- 用户认可整体后要求物品框去四角包角与减薄、按钮再版。最终4图assets/ui/refine_v1，去包角/缝线、连续薄布沿与新纸布签/独立导航垫；保留assets/ui/rework_v1的主纸面/Tooltip/分区和外缘枝叶。所有按钮状态共享切片/内容边距、零按下偏移，修复透明侧空白挤占小按钮可见留白。
- 制作不再根据动态配方最小尺寸重设主框，固定1030×600逻辑画布，长详情内部滚动。背包/制作点击、悬停、分类/配方/数量/成功不足状态不改变主框尺寸或缩放；仅窗口变化适配，背包主动拖标题仅改位置。
- 来源/prompt/回执在art/ui-rework-v1/candidate-01、refine-01，用户参考已保留references。两正式素材目录provenance.json存裁片/哈希/alpha/内容QA。第一组1536×1024；精修返回1254×1254而非请求1024×1024，部分对象留白不足、宽按钮越名义格线，实测完整归属裁片避免截断，生成WARN逐项保留reports/ui-rework-v1/ART_QA.md。精确图片模型/实际费用未暴露，订阅路线估价0不当作已知实际费用。
- Godot4.7.2 Stable / Windows / Compatibility / RTX5060：最终无头原生GUI专项32项0失败，背包操作必要依赖55项0失败，合计87项。文字空间及尺寸稳定失败列表均空。实际窗口核查1280×720及960×540、1600×900逻辑视口，原生输出窗口1280×720；窗口截图通过原Control回调固定状态，不冒充桌面鼠标测试。初次桌面悬停夹具受指针干扰未完成，日志保留、不计通过。最终导入/专项/窗口截图日志无脚本错误。
- reports/ui-rework-v1/index.html及REPORT.md提供最终背包、装备、HUD、Tooltip、制作成功/不足、长详情与尺寸适配实景，并保留失败对照和pilot。已核图；主观美术待用户试玩。长配方需滚动详情为固定主框的设计规则，无已知本轮UI功能阻塞；未做FPS基准或无关全量回归。本轮完成后停止。
''')
print('Report, art QA, gallery, provenance and DEVLOG updated.')

