from pathlib import Path
report='''# 矿洞碰撞修订 V5

洞外原来只有两侧窄矩形和一条横框，围不住完整岩体；清除塌方后可绕入图像内部，Y排序让角色被整幅洞口遮住。改为按岩体轮廓闭合的凹多边形碰撞，屋顶、背面、左右岩壁均保留实体，前方门槛仍可站立并用E进入。塌方独立碰撞仍按开启状态移除。

洞内背景图包含前景门框，旧矩形行走范围延伸至门框上。改为沿地面收口的凸多边形，按角色半径预留边缘，底部止于门框之前；两侧边缘也收回至岩壁内。入口落点与出口交互距离仍可达。保留现有整体绘制方案，通过不可达边界避免站上横梁或门柱。

验证：Godot4.7.2真实窗口10项通过，实际角色从洞外正面、左右、背面持续行走均被边界挡住；洞内向出口持续行走停在横梁前，可E往返。01-exterior-threshold.png和02-interior-threshold.png为到达边界后的实景。相关矿洞回归38项通过（regression.log）。未重复双端或多尺寸测试。独立试玩同步更新，不改正式玩家档。
'''
Path('reports/mine-collision-v5/REPORT.md').write_text(report,encoding='utf8')
p=Path('DEVLOG.md');p.write_text('## 2026-10-25 · 矿洞内外碰撞V5\n\n补齐洞外岩体闭合碰撞，门槛前保留E入口；洞内行走区域沿地面收口，避免角色站上背景门框及两侧岩壁。真实行走专项10项与矿洞回归38项通过，来源和实景见reports/mine-collision-v5/REPORT.md。\n\n'+p.read_text(encoding='utf-8-sig'),encoding='utf8')
p=Path('PROJECT_STATUS.md');s=p.read_text(encoding='utf-8-sig');s=s.replace('## 当前进度\n\n','## 当前进度\n\n- 2026-10-25 矿洞碰撞V5：洞外完整岩体轮廓封闭，洞内地面边界避开门框和岩壁；实际行走专项10项、相关回归38项通过。[报告及实景](reports/mine-collision-v5/REPORT.md)。\n\n',1);p.write_text(s,encoding='utf8')
p=Path('EXPLORATION_SYSTEM.md')
with p.open('a',encoding='utf8') as f:f.write('\n\n## 2026-10-25 后续：内外碰撞V5\n\n洞外MineShell按完整岩体轮廓闭合，屋顶背面与两侧常驻实体；塌方独立移除，门槛保留E通行。洞内mine_rules.walkable按地面多边形和角色半径约束，前景出口横梁、门柱及两侧岩壁不可站立，入口落点和E出口仍可达。实景与范围见reports/mine-collision-v5/REPORT.md。\n')
