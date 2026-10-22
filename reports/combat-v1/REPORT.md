# 战斗、死亡与卷牙野猪 V1 · 交付报告

2026-10-22，当前 Godot 工程源码。正式世界和现有原生联机场景直接接入，无候选开关。未打包、部署、提交或推送；既有其他工作区改动保留。本报告只覆盖本模块和必要依赖，不代表全项目回归。

## 本轮完成

- F 徒手/木棍/猪牙棒攻击，独立起手、有效窗口、收招及每目标一次命中；采集工具拒绝攻击，移动和 E 原交互保持。原生角色部件制作徒手、棍棒、死亡动画，猪牙棒复用棍棒。正面双手沿原共用层级与肩部连接。
- 服务端双方同意的切磋，拒绝/撤回/结束；生命下限保护，不触发正式死亡遗物。受击闪烁、轻微权威击退与本机 UI 上层平滑红边。
- 生命大于零正常行动，移除旧 15 点休养；归零一次死亡、原地倒地及独立灵魂上浮，保存遗物后从固定出生门复活。只恢复生命上限，其他属性沿原规则推进。死亡可安全结束睡眠并处理原设施占用。
- 明确物品死亡分类，普通原始资源完整转移，稀有/加工/制作/装备默认保留；遗物独立 ID、所有者保护、E 查看、滚动内容、分批领取及原子回滚，无自动过期。连续死亡和跨进程恢复不覆盖旧遗物。
- 固定出生门持续旋转旋涡与粒子，出生/复活渐入、门柱碰撞、区块就绪后恢复输入。用户追加修订已执行：整门为首版 **2 倍**；野猪头部由 .16 放大到 .25，颈根内移并重叠，完整保留原画轮廓。
- 卷牙野猪为 Skeleton2D/Bone2D 拆件，森林/岩石自然生成，稳定身份与刷新代次、警戒/追击/攻击/受击/返回/死亡，命中后短时血条，唯一身份掉落。与鸡羊状态分开。
- 膏药、医药包、两把武器及对应制作；野猪牙/肉、肉丸、胡萝卜炒肉、腊肉、熏肉丸及独立图标/腐烂图接原库存、料理、冰箱、熏制与保存。
- 复用 Godot 规则进程、认证角色投影、SQLite 外层事务及请求回执；客户端无直接扣血/死亡/掉落接口。跨角色伤害、遗物转移及复活都由服务端结算。

## 初始数值与设计假设

本表为交付时配置快照；后续只维护对应 data 配置，不回写历史报告。

| 攻击 | 伤害 | 距离 | 起手/有效/收招（秒） | 体力 |
|---|---:|---:|---|---:|
| 徒手 | 4 | 48 | .18 / .08 / .30 | 3 |
| 木棍 | 9 | 66 | .24 / .10 / .40 | 5 |
| 猪牙棒 | 15 | 72 | .24 / .10 / .40 | 6 |
| 野猪 | 12 | 52 | .38 / .10 / .70 | 0 |

攻击扇区为朝向点积至少 .5，距离加目标脚部半径；共用实际遮挡检查。玩家非致死击退 12 世界单位；切磋最低 1 生命。死亡表现 3 秒、入场至少 1 秒，并等待出生视口加载。

野猪上限 8，生命 45，速度 115，发现范围 260，离巢活动上限 420；出生点避让 1000，既有营地避让 240，受击停顿 .18 秒。死亡后按授权模拟秒计时 3600 刷新，同一身份增加代次；每次掉野猪牙 1、野猪肉 2。先取保守小规模初值，未作长期平衡承诺。

| 制作 ID / 成品 | 材料 | 设施 | 效果 |
|---|---|---|---|
| combat_plaster / 膏药 | plant_fiber 3 + wild_berry 2 | 徒手 | 生命 +15 |
| combat_medical_kit / 医药包 | plaster 3 + wool 2 | 原工作台 | 生命 +55 |
| combat_wood_club / 木棍 | wood 4 + plant_fiber 2 | 原工作台 | 初级武器 |
| combat_tusk_club / 猪牙棒 | 背包 wood_club 1 + boar_tusk 2 | 原工作台 | 棍棒动作复用 |

四条制作均为 2 秒。选择已有工作台承担医药包，未新造医疗或科技树；未添加金属武器、盾牌或格挡。

| 食物 ID | 原料/加工 | 饥饿 | 常温/冷藏保质（游戏日） |
|---|---|---:|---|
| boar_meat | 野猪掉落；不可生吃 | 不适用 | 1 / 7 |
| meatballs | boar_meat 2，24 秒 | 28 | 2.5 / 7 |
| carrot_pork | boar_meat 1 + wild_carrot 1，28 秒 | 38 | 2.5 / 7 |
| cured_pork | 野猪肉 1 + 木材 1，熏制 120 游戏分钟 | 24 | 30 / 30 |
| smoked_meatballs | 肉丸 1 + 木材 1，熏制 120 游戏分钟 | 28 | 30 / 30 |

原烤鱼→smoked_fish 继续允许；胡萝卜炒肉不在熏制白名单。腐烂材料拒绝加工，不清零新鲜度。新熟食沿原腐烂后 25% 饥饿、生命 -5 与不适效果；旧食物数值未新增回血。

死亡 `relic` 明确名单为存在于物品表中的 wood、branch、stone、flint、plant_fiber、broad_leaf、pine_cone、wild_berry、brown_mushroom、wild_carrot、wild_apple、wildflower；未登记或缺字段均保留。矿石、野猪专属掉落、武器、医疗、料理等保留。装备不作为材料自动消耗；猪牙棒只取背包中的木棍。

## 实际修改入口

- 新增：`scripts/combat_service.gd`、`combat_world_view.gd`、`data/combat_rules.json`、`assets/combat/v1/`、`assets/hero/cartoon/combat_actions.tres`、`tools/build_combat_actions.gd`、`tools/package_combat_v1.py`。既有未完成的 `combat_rules.gd`、`combat_attack.gd`、`combat_hit_overlay.gd` 继续整理/使用，辅助测试不代替正式调用验收。
- 世界/角色/表现：`world.gd`、`player.gd`、`world_interaction.gd`、`held_tool.gd`、`body_state.gd`、`body_ui.gd`、`item_ui.gd`。
- 事务/加工：`item_service.gd`、`item_inventory.gd`、`craft_book.gd`、`food_freshness.gd`、`campfire_service.gd`、`camp_expansion.gd`、`camp_expansion_ui.gd`、`industry_service.gd`、`industry_ui.gd`、`camp_buildings.gd` 及相关 data 配置。仅扩展肉类、医疗、武器和遗物依赖。
- 联机：`network_game_worker.gd`、`network_game_world.gd`、`network_actor.gd`，`tools/network/game_host.py`、`gameplay.py`、`server.py`。公开白名单只增加攻击、切磋和遗物领取意图；保留原回执及数据库提交。
- 测试：`tests/combat_integration_v1.*`、`test_combat_network_v1.py`、`network_combat_native_v1.gd`、`network_combat_server_v1.py`、`run_combat_native_v1.py`。隔离服务的野猪夹具只存在于测试服务脚本，不是正式服务接口。
- 文档：新增 [COMBAT_SYSTEM.md](../../COMBAT_SYSTEM.md)，更新实际涉及的身体、物品、装备、制作、料理、熏制、工业、动物、联机及美术/UI规范入口，另更新状态页和 DEVLOG。

## 实际验证

Godot 4.7.2 / Compatibility，默认 1280×720；窗口设备为 NVIDIA RTX 5060。没有切换其他分辨率。

| 分组 | 实际结果 | 证据 |
|---|---|---|
| 正式世界专项 | 无头 71 条、原生窗口 71 条通过 | final-headless-complete.log、final-native-complete.log |
| 规则/真实服务 | 14 个用例通过 | final-rules-service.log；最后新增非法方向样本在 invalid-request-final.log 单独复测同一用例 |
| 双真实客户端 | 先正常请求 12/9 条通过；最终注入 220ms 请求处理延迟后 12/13 条通过，退出码均 0 | native-client*.log、delay-native-client*.log |
| 独立进程恢复 | 新进程读取死亡阶段、无重复转移、一次复活等 4 条通过 | final-restore.log |
| 连续死亡 | 两份遗物数量 7/11，ID 不同，新 Godot 规则进程重载内容相同 | multiple-relics.log；最终 14 用例也包含本项 |
| 必要旧依赖 | 食用/整理、个人库存身体隔离、木箱过期领取保护、鸡羊投喂/冷却、睡眠占用/唤醒通过 | dependencies.log 的对应成功项及 dependencies-retry.log |
| 基础规则 | 伤害/方向/距离/切磋/分类 12 断言及攻击辅助取消/单命中测试通过 | tests/combat_rules_v1.gd、combat_attack_v1.gd 的实际运行 |

正式专项包含四方向×三种攻击的动画选择与正面双手、实际命中时刻、采集工具拒绝、重复攻击、野猪攻击与唯一掉落、生命 1 正常行动、唯一死亡、分类与完整装备保留、区块卸载重载后遗物 ID/数量保持、权威内容变化后的遗物列表刷新、遗物取回、失败回滚、医疗及生肉拒食、8 只自然野猪的地貌/安全范围/稳定身份和鸡羊状态不变。食品保鲜检查含原肉常温/冰箱、独立腐烂图及两种熏制成品。

服务用例包含双方同意前免伤、命中一次与取消、切磋不致死、正式死亡、疾病/致幻/腐烂食物致死、睡眠死亡、遗物所有者与容量不足分批领取、两种料理、三条熏制/腐烂拒绝、医药包/满血、真实冰箱转入与新鲜度保留、SQLite 故障注入整体回滚、请求回执去重及服务重开恢复。

最终双客户端通过真实 F 输入与武器显示互相切磋、拒绝/结束免伤、野猪致死与一次复活、共享遗物、另一人物品保持；第二客户端停止旧世界发送后重新登录取得不同会话 token，再进世界恢复遗物和自身物品。220ms 是对 game_command/move 的额外请求处理延迟，不宣称等同双向真实网络 RTT。

## 过程失败及修复

1. 首轮脚本静态类型、物品来源字段和 Bone2D 属性用法错误，分别修正，后续默认窗口无对应脚本错误。原失败日志保留。
2. 设施重载后旧碰撞体尚未释放，导致熏制领取/下一次投入被误判遮挡；规则进程等待延迟销毁与物理注册后再处理，熏制专项复测通过。
3. 真实服务测试最初缺 gameplay_revision，另一次精确生命断言未计正常慢速回血；修正夹具与容差。两次引用了不存在的旧测试方法名，不计为通过；改用实际方法后必要依赖通过。
4. 本地指南曾被规则宿主当作本地新角色发放，占用旧木箱测试的空目标格；限制原本就仅供本地的发放入口，避免把该既有本地功能带入宿主。木箱与睡眠依赖复测通过。
5. 一次双端野猪夹具放在两人之间，按“最近玩家”规则先击倒了另一玩家，造成两份遗物，断言失败。将夹具放在指定受击者外侧；保留最近目标规则，最终延迟双端通过。失败日志为 nearest-fixture-failure-client*.log。
6. 首版死亡整体旋转绕画布角偏移，改为原骨盆/腿部支点倒地；红边离散线条改连续渐变。传送门/野猪比例按用户追加要求修订。
7. 遗物列表补上权威内容变化后的自动刷新。首个 UI 观测夹具只等到帧开始，尚未运行表现更新，改为等待实际 UI 更新后通过；原失败为 final-native-delivery.log，最终窗口为 final-native-complete.log。
8. 出生门入口作为固定设施保留放置空间，避免墙/家具/篝火封住复活点；原铺面层继续允许，新增窗口断言验证。切磋按钮在背包等页面打开时隐藏，避让关闭按钮。

## 美术来源与 QA

16 张源部件/物品图及 5 张由其生成的腐烂图，来自 generate2dsprite → generate2dmedia/route_media → **Codex(local CLI)**，记录模型标识 `codex-image_gen`。提示、正式场景参考、原图、修订、各裁切坐标、处理方法、运行 PNG SHA 和派生关系在 `art/combat-v1/` 与 `assets/combat/v1/provenance.json`。原角色 PNG 未重画；新动画库、构建脚本、原骨骼场景与实时效果代码/着色器也登记 SHA。灵魂、旋涡、红边为实际运动/着色效果。

首稿野猪躯干两端误画为切面，单独编辑修复，仅取修订中的躯干；其他 15 个源图保持首稿。源图部分野猪画稿跨越名义四等分线，使用留在空白处的所有权边界完整切取后再缩放，未把名义网格 QA 失败写成通过。所有发布 QA 的 FAIL/WARN 原值列在下方；运行图无跨格失败，仍有软 alpha 警告。

`art/combat-v1/raw-qc/sheet-qc.json`：
- FAIL `cross_cell_components`：value=2；threshold=0。
- FAIL `cross_cell_visible`：value=2；threshold=0。
- WARN `boundary_band`：value=1387；threshold=0。
- WARN `safe_frame`：value=15；threshold=0。

`art/combat-v1/raw-qc-keyed/sheet-qc.json`：
- FAIL `cross_cell_components`：value=2；threshold=0。
- FAIL `cross_cell_visible`：value=2；threshold=0。
- WARN `boundary_band`：value=1387；threshold=0。
- WARN `safe_frame`：value=15；threshold=0。

`art/combat-v1/repair-qc/sheet-qc.json`：
- FAIL `cross_cell_components`：value=2；threshold=0。
- FAIL `cross_cell_visible`：value=2；threshold=0。
- WARN `boundary_band`：value=1379；threshold=0。
- WARN `safe_frame`：value=15；threshold=0。

`art/combat-v1/runtime-qc/sheet-qc.json`：
- WARN `faint_specks`：value={"floor_px":7260,"detached_components":0}；threshold=0。


主观美术观感仍供用户反馈；本轮功能授权与具体比例修订不替代用户对所有最终画面的审美确认。来源图和 provenance 引用的 QA 图保留；`reports/.tmp/combat-v1/` 中窗口图为本轮临时媒体，依项目约定在效果确认后清理。

## 未验证边界

- 未做 16 人负载、异机长期联网、真实丢包/网络分区、长时间强杀循环或极大数量遗物/建筑性能验证。
- 尚未长期人工平衡武器、野猪密度/威胁、医疗材料成本与肉食收益；8 只野猪的本 Seed 检查不是多 Seed 分布基准。
- 本轮只测默认窗口；按项目约定不做多分辨率或无关全量回归。
- 测试世界、账号和服务器数据库均隔离，未把真实玩家存档作为输入、未投放测试物品；未作真实玩家文件前后哈希审计，不宣称未测的字节级对照。
- 本地源码已接正式入口。现有部署/分发包没有自动更新，运行联机应统一采用本轮客户端与规则服务源码；本轮未部署、提交或推送。
