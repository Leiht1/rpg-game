from pathlib import Path
import json
checks=json.loads(Path('reports/sleep-collision-v11/checks.json').read_text(encoding='utf8'));assert all(c['pass'] for c in checks)
entry='''## 2026-10-18 · 睡眠碰撞对齐与边缘交互 V11

保留V10设施画面及头部大小。睡眠碰撞矩形不再以建筑原点居中，而用data/sleep_rules.json中collision_rect/vertical_collision_rect明确位置与尺寸，对齐现有未占用图的可见轮廓。放置采样、资源近距保护、整块重叠检测和真实CollisionShape共用camp_buildings.footprint_rect，避免前方透明阻挡；旧实例位置/存档格式不改，重新加载按当前规则生成碰撞。

睡眠交互距设施矩形最近边缘计算，提示与提交复用同一含角色半径的路径遮挡检查，不再要求走到建筑中心；隔墙不可交互。其他类型交互保留原规则。图像、缩放、输入、恢复和消耗规则不变。默认1280×720 Godot4.7.2原生窗口87项0失败，五设施方向覆盖放置、偏移碰撞、四边靠近/不能穿透/可交互和入睡，床席另测墙挡住边缘时提示与提交均拒绝；睡袋入睡后按原规则消耗，所以只测一个接近方向。初轮短距离旧射线辅助触发坐标警告，现睡眠交互直接共用原睡眠路径检查，最终window-final.log无警告/脚本错误。未全量或多分辨率回归，测试不写玩家档。报告reports/sleep-collision-v11/REPORT.md。

'''
p=Path('DEVLOG.md');s=p.read_text(encoding='utf8');i=s.find('\n');p.write_text(s[:i+1]+'\n'+entry+s[i+1:],encoding='utf8')
p=Path('SLEEP_SYSTEM.md');s=p.read_text(encoding='utf8');i=s.find('\n');p.write_text(s[:i+1]+'\n## 当前碰撞与交互 V11\n\n睡眠设施真实碰撞、放置采样和重叠检查统一使用配置中的带偏移矩形（`camp_buildings.footprint_rect`），不再把视觉大小居中套成碰撞。交互距矩形最近边缘计算，并与睡眠提交复用原路径遮挡检查，墙体仍阻断。画面/头部大小、原存档格式保持。见[验证报告](reports/sleep-collision-v11/REPORT.md)。\n\n'+s[i+1:],encoding='utf8')
p=Path('PROJECT_STATUS.md');s=p.read_text(encoding='utf8');s=s.replace('本轮V10修复围墙内放置误判、头部闪动，并按原头部大小同步适配设施。','V10保持原头部大小并适配设施；最新V11修复放大后碰撞偏移及中心交互距离问题。').replace('[V10报告](reports/sleep-fit-v10/REPORT.md)','[V11报告](reports/sleep-collision-v11/REPORT.md)');p.write_text(s,encoding='utf8')
Path('reports/sleep-collision-v11/REPORT.md').write_text('# 睡眠碰撞与交互修复\n\n'+entry,encoding='utf8')
print(len(checks),'checks passed; current specs and status updated.')
