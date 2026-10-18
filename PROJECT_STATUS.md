# 《风栖原野》当前项目状态

更新：2026-10-19。此页仅为当前状态与按需导航；通用执行规则见 [AGENTS.md](AGENTS.md)，参数与细则以对应配置/系统规范为准。各项验证范围以所链接报告为准。

## 当前进度

- 当前工程素材已分类核对，明确弃用且无引用的7张旧UI框图及导入文件已删除，原提灯与正式来源/报告保留；本轮工程同步见[整理报告](reports/material-cleanup-20261019/REPORT.md)。

- 木箱标题下移至空白处，格/图标缩小、框156×184；开关图统一缩小采样。左右背包在木箱上层且鼠标顺序一致，背包打开可E交互，整理按横向显示。最新窗口与重启验证见[专项报告](reports/chest-ui-v2/REPORT.md)。

- 背包已改为左右固定分框，木箱为独立世界锚定九宫格；建筑血条命中后2秒隐藏、支持长按E连续砸，床席床头/上沿接地碰撞已修订。专项窗口66项、重启3项及播种依赖20项通过，见[报告](reports/inventory-chest-v1/REPORT.md)。新开盖画稿已获“接入吧”确认并正式采用，无预览开关依赖；新增窗口9项及重启3项通过，见[正式报告](reports/chest-open-formal-v1/REPORT.md)。

- 播种已改为空耕地E打开种子小窗、点击即种，背包无种子显示“没有种子”；锤毁生长中耕地不返种、不发产物且重启仍移除。木地板缩小采样已启用mipmap以减轻运动细纹伪影；最新定向窗口、GPU及重启结果见 [修订报告](reports/planting-ui-floor-v2/REPORT.md)。

- 种植 V1 已获用户“可以 直接接入游戏吧”确认并正式开放。14 张作物/种子/收获物 PNG 按验收哈希原样迁入 `assets/planting/v3`，普通 `Start-Playtest.cmd` 无需种植预览开关；原 92×60 暗色耕地、96×64 格及残根共用底层保持。规则见 [种植规范](PLANTING_SYSTEM.md)，正式路径验证见 [报告](reports/planting-formal-v1/REPORT.md)。

- 正面工具的衣身遮挡、空闲手显示与肩部连接已按四工具共用规则修复；新增工具同样复用，当前约定见 [装备规范](EQUIPMENT_SYSTEM.md)，证据见 [专项报告](reports/front-tool-layer-v12/REPORT.md)。

- 正式 Godot 4.7.2 Windows 工程已有探索、资源采集、库存/装备、制作/料理、营地建造与身体系统。已获批的方形铺面、月牙精力图标和背包一键整理已接入；各系统当前细则见下表，不在此复写参数。
- 火把火苗飘动、建筑中心返料动画与篝火照明/燃料条局部调整已完成；当前规则见营地/篝火规范，默认窗口专项证据见 [本轮报告](reports/camp-effects-v11/REPORT.md)。
- 睡眠设施V9已获用户授权正式接入；V10保持原头部大小并适配设施；最新V11修复放大后碰撞偏移及中心交互距离问题。当前规则见 [睡眠规范](SLEEP_SYSTEM.md)，定向验证见 [V11报告](reports/sleep-collision-v11/REPORT.md)。

## 已知问题与待办

- 本批种植素材已确认并正式接入，不扩大到未来素材。长期人工种植平衡和大量耕地性能仍未验证。

- 当前睡眠画稿已正式采用；本轮未新增画稿，未扩大授权到未来素材。
- 未来头部扩展需兼容侧视及闭眼位置配置；尚未开发换装系统。长期人工平衡、大营地性能与完整未来换装兼容性仍无完整验证结论。
- 旧文档和日志包含已被替代的阶段描述（例如睡眠快进/旧睡姿、候选未采用、三尺寸清单）；按最新有效要求与对应规范判断，不直接照搬旧标题或参数。发现影响本任务的具体冲突时再核查实现。

## 下一步（不自动开展）

本轮修订及木箱开盖图正式接入完成，等待试玩反馈；不自动进入新的玩法阶段。

## 按任务选择入口（不是必读列表）

| 本次任务涉及 | 优先定位的规范 |
|---|---|
| 种植、耕地、留种、生长与残根 | [PLANTING_SYSTEM.md](PLANTING_SYSTEM.md) |
| 睡眠设施、占用造型与唤醒 | [SLEEP_SYSTEM.md](SLEEP_SYSTEM.md) |
| 身体属性、食物效果 | [BODY_SYSTEM.md](BODY_SYSTEM.md)；涉及食用/库存再查 [ITEM_SYSTEM.md](ITEM_SYSTEM.md) |
| 背包、快捷栏、装备 | [ITEM_SYSTEM.md](ITEM_SYSTEM.md)、[EQUIPMENT_SYSTEM.md](EQUIPMENT_SYSTEM.md) 中相关章节 |
| 制作、料理、营地 | [CRAFTING_SYSTEM.md](CRAFTING_SYSTEM.md)、[CAMPFIRE_SYSTEM.md](CAMPFIRE_SYSTEM.md)、[CAMP_BUILD_SYSTEM.md](CAMP_BUILD_SYSTEM.md) 中对应系统 |
| 采集、矿点、自然资源 | [HARVEST_SYSTEM.md](HARVEST_SYSTEM.md)、[ORE_SYSTEM.md](ORE_SYSTEM.md)、[NATURAL_RESOURCE_ECOLOGY.md](NATURAL_RESOURCE_ECOLOGY.md) 中对应系统 |
| 地图或世界时间/天气 | [MAP_SYSTEM.md](MAP_SYSTEM.md) 或 [WORLD_ENVIRONMENT.md](WORLD_ENVIRONMENT.md) |
| UI或新美术 | [UI_ART.md](UI_ART.md) 或 [ART_STYLE.md](ART_STYLE.md)；再按资源类型及适用约定定位必需工作流 |

定位规范后，用具体符号/配置路径查实现与专项测试；只有发现明确依赖或冲突才扩展读取。历史决策仅按问题搜索 [DEVLOG.md](DEVLOG.md) 或对应报告。
