from pathlib import Path
import json,hashlib
for folder in ['assets/sleep/v1','assets/sleep/occupied-v9']:
 manifest=json.loads((Path(folder)/'provenance.json').read_text(encoding='utf8'))
 for name,row in manifest['files'].items(): assert hashlib.sha256((Path(folder)/name).read_bytes()).hexdigest()==row['source_sha256']==row['sha256']
report=Path('reports/sleep-formal-v9');checks=json.loads((report/'checks.json').read_text(encoding='utf8'));assert len(checks)==84 and all(c['pass'] for c in checks)
latest='''## 2026-10-18 · 睡眠设施正式接入 V9（最新）

用户明确“横向草席的被子太短了，头下面都漏出来了一节空的，再调整一下，然后就可以接入游戏了”，授权最后延长横席被沿并正式接入当前本批。横席新图经generate2dsprite→route_media→Codex(local CLI)，补上头下空段，完整来源art/sleep-formal-v9；其他获准图原样迁入。正式未占用/图标assets/sleep/v1，五占用图assets/sleep/occupied-v9，来源/授权原话/逐字节SHA见各provenance，不批准未来图。候选pending条款仅为确认前历史。

床席建造及工具台睡袋配方默认开放，无sleep_preview开关依赖；睡袋图标/地面图用正式路径。床席R横竖、工具台包含徒手配方且徒手不能制睡袋、E入睡/仅E醒来、睡袋入睡后退出立即消失、滚轮原范围缩放、静态头/被与zzz漂浮均保持。原状态/存档路径和格式不改。Start-Playtest普通入口直接生效，未向玩家存档投放任何测试物品。

Godot4.7.2关闭预览开关、默认1280×720原生窗口84项0失败，核对正式资源、配方归属/图标、五设施方向、睡眠输入/滚轮与醒来消耗；所有迁入PNG哈希与来源一致。测试隔离，不写玩家档；未重复全量回归、多分辨率、长期人工平衡或大营地FPS。报告reports/sleep-formal-v9/REPORT.md。本轮完成停止。

'''
for name in ['DEVLOG.md','AGENTS.md','SLEEP_SYSTEM.md','ART_STYLE.md']:
 p=Path(name);s=p.read_text(encoding='utf8');at=s.find('\n');p.write_text(s[:at+1]+'\n'+latest+s[at+1:],encoding='utf8')
(report/'REPORT.md').write_text('''# 睡眠设施正式接入 V9

用户明确授权先延长横草席头端被沿补空，再接入游戏。新横席延长被沿经generate2dsprite→route_media→Codex(local CLI)实际生成，软抠结构QA pass。源图、提示词、回执在art/sleep-formal-v9。五占用图正式assets/sleep/occupied-v9：横席V9、横床/竖席V8、竖床V6、袋V5。未占用设施/睡袋图标在assets/sleep/v1。正式provenance记录具体授权原话和每图来源/SHA，所有迁入文件与对应来源逐字节一致，不将授权扩展至未来画稿。

原三条睡眠配方默认开放：V建造床/草席，可R换横竖；睡袋工具台制作入包，徒手不可做，工具台仍含徒手配方。睡袋补齐正式背包及世界图标。运行睡眠图引用正式路径，移除sleep_preview配方解锁及候选路径覆盖，不靠临时世界开关。普通Start-Playtest直接生效。既有物品、建筑ID、材料、恢复率、原子存档路径/格式不改。

关闭sleep_preview的隔离真实窗口84项0失败，默认1280×720，包含开放配方/工具台归属/正式图标、五设施正式空闲与占用资源、E入睡/仅E醒来、W/Shift保护、鼠标不唤醒、滚轮双向/上下限、不解锁移动、静止头/被面/zzz漂浮、睡袋退出消耗与床席恢复。window.log无脚本错误。未写玩家存档，未重复跨进程存档/全量系统/多分辨率回归或长期人工/大营地FPS测试。
''',encoding='utf8')
source=Path('tools/report_sleep_occupied_v5.py').read_text(encoding='utf8').split('checks=json.loads')[0]
source=source.replace('reports/sleep-occupied-v5','reports/sleep-formal-v9').replace('睡眠效果预览 · 立体被面 + 当前角色头部','睡眠设施 · 正式接入效果').replace('被面轻微呼吸起伏','滚轮缩放 · 保持睡眠').replace('E 入睡 · 任意键醒来','E 入睡 · 仅 E 醒来')
exec(compile(source,'formal-window-crops','exec'))
print('Formal art hashes verified; 84 checks passed; current documentation finalized.')
