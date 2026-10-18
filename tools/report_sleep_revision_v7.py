from pathlib import Path
import json
p=Path('prototypes/sleep-occupied-v6/provenance.json');data=json.loads(p.read_text(encoding='utf8'));data['notes']=['Vertical bed quilt head-end shortened with shallow curved top meeting head lower edge; refined image generation job retained.','Horizontal heads final net upward shift five world units from V5 (seven up, then two down at user request).','No breathing shader or body movement; only zzz floats. Reuse current side head subtree; new art remains pending_user.'];p.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
p=Path('tools/package_sleep_occupied_v6.py');s=p.read_text(encoding='utf8').replace('Horizontal heads moved up seven world units in renderer. Existing other four V5 occupied assets unchanged.','Horizontal heads final net upward shift five world units from V5; two down from initial V6. Other four V5 occupied assets unchanged.');p.write_text(s,encoding='utf8')
latest='''## 2026-10-18 · 睡眠最新修订：仅 E 唤醒、静态被面与单分辨率验证

用户最新规则覆盖历史“任意键醒来”和呼吸效果：仅新按下 E 手动退出睡眠；WASD、Shift、Esc、空格、其他键与鼠标均不退出，E 长按重复不触发。提示为“按 E 醒来”。头部、被子和身体都保持静止，不挂胸口/被面呼吸 Shader，仅 zzz 上下漂浮。原渐进恢复、正常世界流速和入睡后睡袋退出即移除保持。

横向床、草席、睡袋头部相对 V5 最终上移5单位（初版上移7后按最新反馈下调2）。竖床橙色被沿再次缩短，最高被角压低，浅弧被沿接头部下缘；当前竖床候选 prototypes/sleep-occupied-v6/final/wood_bed-vertical.png，其余四张占用画稿仍为 V5。新图由 generate2dsprite→route_media→Codex(local CLI) 生成/编辑，pending_user，仅独立候选预览，不推广正式资源和配方。

开发期仅验证项目默认分辨率，当前 project.godot 为1280×720；项目完成后再做全分辨率测试，历史多尺寸验证不作为当前必跑清单。最终仅做本轮专项原生窗口86项0失败，包含五设施/方向、E独占唤醒、移动/Shift等输入保护、静止头/被面与zzz漂浮、瞬时恢复和袋消耗。未重复多分辨率或全量回归，未写玩家档。报告 reports/sleep-occupied-v6/REPORT.md；入口 Start-Sleep-Facilities-Preview.cmd。

'''
for filename in ['DEVLOG.md','SLEEP_SYSTEM.md','AGENTS.md']:
 p=Path(filename);s=p.read_text(encoding='utf8');at=s.find('\n');p.write_text(s[:at+1]+'\n'+latest+s[at+1:],encoding='utf8')
report=Path('reports/sleep-occupied-v6')
(report/'REPORT.md').write_text('''# 睡眠位置、被沿和 E 唤醒修订

横向床/草席/袋头部最终比V5上移5游戏单位，相比初次V6下调2，落于枕头区域。竖床单独重画两次：第二稿压低两侧被角，减少橙色被子伸到头后面的部分，以浅弧线衔接头部下缘。候选路径与SHA见 prototypes/sleep-occupied-v6/provenance.json；两轮原图及回执完整留存，受控路线 generate2dsprite→route_media→Codex(local CLI)。最终软抠/结构QA pass；主观验收仍待用户，本批未推广正式资源。

只允许新按下E手动醒来；WASD、Shift、Esc、空格、C和点击均不醒，重复E不醒。提示“按 E 醒来”。移除所有被面呼吸材质，头和被面保持静止；只有zzz漂浮。睡袋已入睡后E退出立即消失，床席立即恢复原图。

项目默认窗口1280×720。测试新规则已写AGENTS：开发阶段只测直接打开Godot项目使用的默认分辨率，项目完成再做全尺寸验证。此前V6首轮115项通过后，用户增加E专属/取消呼吸要求，因此只跑新的86项相关专项：五设施方向、真实输入、静止头/布料、zzz运动和醒来/消耗，不重复多分辨率和全量系统回归。最终 e-only-window.log 与 e-only-checks.json 均86项0失败，窗口日志无脚本错误。原玩家存档不读写。未做未来换装全流程、长期人工或大型营地性能测试。
''',encoding='utf8')
# Compose current real-window crops; no game art is painted by this reporting step.
source=Path('tools/report_sleep_occupied_v5.py').read_text(encoding='utf8').split('checks=json.loads')[0]
source=source.replace("reports/sleep-occupied-v5","reports/sleep-occupied-v6").replace('睡眠效果预览 · 立体被面 + 当前角色头部','睡眠修订预览 · 头部位置与竖床被沿').replace('被面轻微呼吸起伏','头与被面静止 · zzz漂浮').replace('E 入睡 · 任意键醒来','E 入睡 · 仅 E 醒来')
exec(compile(source,'report-crops','exec'))
print('Final report and current project rules updated; no additional resolution checks.')
