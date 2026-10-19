from pathlib import Path
import json
p=Path('PROJECT_STATUS.md');s=p.read_text(encoding='utf-8-sig');s=s.replace('## 当前进度','## 当前进度\n\n- 鸡、羊动物生态与养殖 V1 已接入：侧视骨骼拆件、投喂/跟随留守、真实围栏碰撞、产蛋剪毛、自动繁殖和三阶段成长；新增画稿待本批视觉确认。见[动物规范](ANIMAL_SYSTEM.md)与[专项报告](reports/animals-v1/REPORT.md)，独立试玩入口 Start-Animals-Preview.cmd。',1);s=s.replace('本轮世界资源生态与路标完成，等待试玩反馈；不自动进入动物、任务、传送或其他下一阶段。','本轮动物生态与养殖 V1 完成后等待试玩与本批美术反馈；不自动进入更多动物、交易、屠宰或其他下一阶段。');s=s.replace('| 种植、耕地、留种、生长与残根 |','| 动物生态、投喂、围栏养殖、繁殖成长、鸡蛋羊毛与羊毛剪 | [ANIMAL_SYSTEM.md](ANIMAL_SYSTEM.md) |\n| 种植、耕地、留种、生长与残根 |');p.write_text(s,encoding='utf-8')
p=Path('ANIMAL_SYSTEM.md');s=p.read_text(encoding='utf-8').replace('远处野生动物用至多 12 单位的分段移动检查','远处迁移动物每累计 10 游戏分钟移动一次，用至多 12 单位的分段移动检查').replace('跟随模式不触发这项游走。','跟随模式不触发这项游走。远处驯养动物走离原锚点 620 单位后休眠移动（位置保留、时间状态继续），重新接近时恢复实体行为，避免持续远距离移动开销。');p.write_text(s,encoding='utf-8')
for name in ['integrate','refine','readiness','fix','debug','pairfix','pairdebug','pairdebug2','normalize','cooldownfix','visualfix','edges-extra','remote','roam','capfixture','movement-batch']:
 p=Path(f'art/animals-v1/{name}.py')
 if p.exists():p.unlink()
p=Path('reports/animals-v1/parse.log')
if p.exists():p.unlink()
