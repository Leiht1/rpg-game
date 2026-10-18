from pathlib import Path
import json
report=Path('reports/sleep-occupied-v8')
checks=json.loads((report/'checks.json').read_text(encoding='utf8'));assert all(c['pass'] for c in checks)
latest='''## 2026-10-18 · 被沿衔接与睡眠滚轮缩放 V8（当前候选）

保留用户认可的竖木床头部及V6被沿。新画横木床橙被、横草席米白被及竖草席米白被，缩短靠头一端，浅弧线衔接下巴下缘，来源art/sleep-occupied-v8，候选prototypes/sleep-occupied-v8/final，generate2dsprite→route_media→Codex(local CLI)，pending_user。睡袋及现有头锚点不改。

睡眠时ItemUI仍拦截角色动作输入，但把滚轮交给原玩家相机缩放方法；保持原每档1.1、范围0.65–1.65，缩放不醒来、不解锁移动。仅E醒来、头/被静止、zzz漂浮保持。项目默认1280×720原生窗口本轮76项0失败，只做被沿、缩放和必要睡眠输入专项，不重复其他分辨率或全量回归，不写玩家档。源图未遵循等分三行，按0/480/800/1536所有权边界重排保留完整画稿，软抠结构QA通过；主观自然度待本批确认。报告reports/sleep-occupied-v8/REPORT.md。

'''
for name in ['DEVLOG.md','AGENTS.md','SLEEP_SYSTEM.md']:
 p=Path(name);old=p.read_text(encoding='utf8');at=old.find('\n');p.write_text(old[:at+1]+'\n'+latest+old[at+1:],encoding='utf8')
(report/'REPORT.md').write_text('''# 睡眠被沿与滚轮缩放 V8

缩短横木床、横草席与竖草席的被子靠头一端，自然浅弧被沿衔接下巴。橙床被、米白草席被继续各自材质；用户认可的竖木床V6及睡袋V5保持，头锚点保持。新三候选由generate2dsprite→route_media→Codex(local CLI)实际生成，完整原图/提示词/回执在art/sleep-occupied-v8；透明PNG、等比注册及SHA在prototypes/sleep-occupied-v8/provenance.json。原图三件不均分行，使用明确所有权边界0/480/800/1536重排保留完整轮廓，没有截成矩形被面。软抠结构QA pass，仍pending_user，未推广正式资源。

睡眠滚轮失效来自ItemUI睡眠拦截及Player动作门禁。现在睡眠期间直接调用与普通游玩共用的zoom_from_wheel，只调整相机；原每档1.1、范围0.65–1.65不变。仍仅E手动醒来，移动/Shift保持锁定，头/被面静止，仅zzz漂浮。

Godot4.7.2实际窗口76项0失败，window.log无脚本错误。五设施/方向均验证真实滚轮放大/缩小、上下限、不醒来及不解锁动作，兼顾E醒来/睡袋移除、静态画面/zzz运动；截图均在项目默认1280×720，不切换分辨率。未重复全量功能/存档回归或长期人工测试，原玩家存档未写入。

入口Start-Sleep-Facilities-Preview.cmd，预览窗口已打开的旧进程需要重新打开该入口才会读取最新脚本与候选。
''',encoding='utf8')
source=Path('tools/report_sleep_occupied_v5.py').read_text(encoding='utf8').split('checks=json.loads')[0]
source=source.replace('reports/sleep-occupied-v5','reports/sleep-occupied-v8').replace('睡眠效果预览 · 立体被面 + 当前角色头部','睡眠预览 · 缩短被沿衔接下巴').replace('被面轻微呼吸起伏','滚轮缩放 · 保持睡眠').replace('E 入睡 · 任意键醒来','E 入睡 · 仅 E 醒来')
exec(compile(source,'current-window-crops','exec'))
print(len(checks),'checks passed; current report and comparison ready.')
