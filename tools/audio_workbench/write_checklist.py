"""Render the data-driven catalog as a complete replacement collection checklist."""
from pathlib import Path
from core import read
root=Path(__file__).resolve().parents[2]
rows=read(Path(__file__).with_name('events.json'),[])
text=['# 风栖原野 · 全部音效重新配置清单','', '2026-10-20：按用户要求，已有音效也全部重新挑选、允许替换。以下所有条目不划线，不因旧素材已接入而完成；实际本轮进度以工作台保存与导出校验为准。原游戏音效继续保留，脚步仍停用。走路/跑步复用四种地面，不另造奔跑事件。','', '这是当前已实现玩法的声音需求，包含尚未接入声音的玩法；导出不等于游戏已绑定。稳定 ID 与源码依据见 [events.json](tools/audio_workbench/events.json)，使用方法见 [说明](tools/audio_workbench/README.md)。','']
group=None
for row in rows:
    if row['category']!=group:
        group=row['category']; text+=['','## '+group,'','| 事件 ID | 声音需求 |','|---|---|']
    text.append('| `'+row['id']+'` | '+row['name']+' |')
(root/'AUDIO_RESELECTION_CHECKLIST.md').write_text('\n'.join(text)+'\n',encoding='utf-8')
