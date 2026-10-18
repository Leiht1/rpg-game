from pathlib import Path
intro='''## 2026-10-17 · 埋藏物取消半透明蒙层
用户明确否定埋藏物的蒙层/泛绿半透明造型。埋藏主体现在保留清晰不透明的原色，采用实心轮廓遮挡，不再混入地表颜色或降低主体alpha；独立前景层复用原半埋画稿中的泥土像素，自然遮住下部并随挖掘清开。主体纹理、原点和脚底始终不动，完成露出完整物体。土边继续参考脚下真实地表，矿点/交互/动作/次数/掉落/存档不变；无新PNG或图片生成。原生实景专项68项通过，抽查869个露出胡萝卜像素无半透明；reports/buried-solid-v052。本条覆盖上一版埋藏物透明显露表现，本轮完成停止。

'''
for name in ['AGENTS.md','HARVEST_SYSTEM.md']:
 p=Path(name);s=p.read_text('utf-8-sig');head,_,rest=s.partition('\n');p.write_text(head+'\n\n'+intro+rest.lstrip('\n'),encoding='utf-8')
p=Path('DEVLOG.md');s=p.read_text('utf-8-sig');s+='''

## 2026-10-17 · 埋藏物取消蒙层，改为实心泥土遮挡

- 按用户截图反馈移除buried分支中主体与地表颜色混合、降低alpha的显露方式；露出部分现在保持原图清晰、不透明，隐藏部分用确定轮廓裁去，独立PaintedForegroundSoil用原半埋图的真实土块像素自然盖住下部。泥土按原画颜色/区域识别排除胡萝卜橙色、骨片亮部和物件上部，土色仍与脚下纯地表匹配；挖掘减少遮挡直至完成隐藏前景土层，不移动主体或靠整物透明度制造埋藏感。
- 仅修改scripts/harvest_hit.gdshader、harvest_node.gd并新增buried_soil.gdshader；全部PNG/来源保持，无图片生成或美术文件重绘。矿点、工具层级、长按E、快捷装备、动作/采集次数、碰撞、地图生成、掉落和存档无变化。
- Godot4.7.2 Stable / Compatibility / RTX5060：tests/test_buried_solid_v052.gd原生窗口68项0失败，覆盖三物件全进度的固定纹理/变换/不透明主体、固定前景土层与完成移除、Shader无旧透明蒙层；直接渲染抽查869个露出胡萝卜像素全部alpha≥0.99，faded=0。三类型初始/一次挖掘/完整露出已实际同镜头核图，runtime.log无脚本错误。仅验证本轮视觉与必要进度依赖，未重复无关玩法回归或测FPS。
- 实景与数据reports/buried-solid-v052/index.html；新观感仍待用户视觉复查，不冒称已获验收。本轮完成停止。
''';p.write_text(s,encoding='utf-8')
Path('reports/buried-solid-v052/index.html').write_text('''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>埋藏物实心遮挡修订</title><style>body{max-width:1050px;margin:35px auto;padding:25px;background:#f4ecdc;color:#4c4032;font:16px/1.7 system-ui}img{max-width:100%;border-radius:12px}a{color:#71512d}</style><h1>埋藏物：去掉半透明蒙层</h1><p>露出部分保持原图清晰、不透明，下部由原画中的真实泥土遮住。挖掘逐步减少泥土遮挡，主体纹理、原点和脚底不切换或移动。底部土边继续适配脚下地表，完整露出后移除前景土层。</p><p>下图三列依次为根茎、骨片、补给包；三行依次为初始、挖掘一次、完整露出。真实Godot画面，按实际像素裁取。</p><img src="game-stages-detail.png" alt="三类埋藏物实心遮挡阶段"><p><a href="game-stages.png">完整游戏截图</a> · <a href="tests.json">68项专项检查：0失败</a> · <a href="runtime.log">运行日志</a></p><p>直接渲染抽查869个露出胡萝卜像素，全部不透明，无旧蒙层。未生成或修改PNG，未改变玩法、动作、采集次数、掉落、地图或存档；仅检查本轮视觉及进度依赖。Godot4.7.2 Stable / Compatibility / RTX5060。实际观感待用户复查。</p></html>''',encoding='utf-8')
