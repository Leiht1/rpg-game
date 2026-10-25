from pathlib import Path
p=Path('reports/mine-collision-v5/REPORT.md')
with p.open('a',encoding='utf8') as f:f.write('\n## 后续边界放宽\n\n用户试玩指出离边缘过远就被阻挡。将侧面最大范围从±710放宽到±790，底部门框前边界从y300放宽到y340，顶部从-340调整为-355，并放宽下侧斜边。仍按角色10半径与实际轮廓相隔，出口门框仍不可站立。专项增加两侧原空白带和门框前近处可达检查；当前验证结果见checks.json与window.log。\n')
p=Path('EXPLORATION_SYSTEM.md')
with p.open('a',encoding='utf8') as f:f.write('\n后续试玩收紧过度反馈：室内地面边界贴近绘制轮廓，左右最大±790、前端y340、顶部-355，按角色半径留隙；不再沿用V5初版±710/y300的保守范围。\n')
