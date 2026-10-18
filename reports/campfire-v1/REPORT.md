# 营地篝火与基础烹饪V1交付

2026-10-17，Godot 4.7.2 Stable，Windows / Compatibility，真实窗口适配器 NVIDIA GeForce RTX 5060。当前正式入口仍为 Start-Playtest.cmd；不改变原应用名/user://身份。已实现制作→放置→拖拽投料→烹饪→领取→食用→保存恢复闭环。

## 最终玩法

- 简易篝火：C制作，木材4、石块6、燧石1，仍1.5秒后完整结算。原五配方保持，补给包配方没有恢复。
- 使用后绿色/红色实物预览，左键确认，右键/E/Esc取消。成功才扣原格1个；检查干燥陆地、水岸、出生点、边界、通道、碰撞/资源与周围通行空间。碰撞18、交互88、显示88分别配置，不使用显示尺寸当碰撞。
- 按最新反馈，面板不支持添加柴火、点燃或熄灭。将快捷栏/背包可燃物拖到火堆，角色原生投掷；主手有装备使用左手。背包拖出边缘时临时收起露出场景，松手恢复，包内整理保持。
- .95秒投掷，.42秒出手，.70秒落点才扣物品并续燃/重新点燃。容量1200正常模拟秒，按整组最多容纳的件数投入，余量保留。中断、来源移动、装备切换、距离失效、保护存档均不会白扣。
- 木材120秒、树枝30、纤维15、宽叶10、松果45、野花5；浆果/生熟蘑菇10；生熟胡萝卜/苹果15。用户已确认可燃物白名单，石头、矿石、工具、提灯不消耗，也不误变成地面丢弃物。
- 燃时归零自动熄灭。72宽的常驻燃时条固定在火堆下方，按用户最后要求纵向缩为前版1/3，宽度/位置保持。点燃显示轻量火焰与200半径暖光，熄灭撤下；原提灯/夜间/天气不调参。

## 实际熟食

| 食谱/物品 | 食材 | 时长 | 原BodyState结算 |
|---|---|---:|---|
| roast_carrot / roasted_carrot 烤胡萝卜 | wild_carrot×1 | 12秒 | 饥饿+42、生命+2 |
| roast_mushroom / roasted_mushroom 烤蘑菇 | brown_mushroom×1 | 10秒 | 饥饿+32 |

两种熟食均有正式图标/描述/获取来源，叠30，进原背包和快捷栏、Tooltip与右键/数字使用流程。满饥饿且没有其他收益不消费。不新增体力恢复或改变原身体速率。

篝火每次一份：开始即原子扣食材并保存任务，燃烧时推进，关闭面板继续；熄火暂停，投料后恢复。完成只生成待领状态，满包留在火堆，成功领取才清空，不能重复领取。没有队列、烤焦、腐坏或其他烹饪阶段。

## 文件及职责

| 文件/目录 | 新增或修改职责 |
|---|---|
| scripts/campfire_service.gd（新增） | 放置校验、区块索引、燃料白名单、投料/食材/领取事务、计时、状态校验 |
| scripts/campfire.gd（新增） | Y排序画稿、轻量火焰、碰撞、E入口、常驻薄燃时条 |
| scripts/campfire_ui.gd（新增） | 放置预览与取消、固定烹饪界面、进度与领取 |
| scripts/campfire_throw.gd（新增） | 单次原生投掷会话、左右手选择、物品弧线、落点提交与取消清理 |
| data/campfire_rules.json（新增） | 燃料/容量/空间参数、两烹饪食谱及时间 |
| data/items.json / data/recipes.json | 新增篝火和两熟食，追加一条原制作配方 |
| scripts/item_service.gd | 接入原使用信号/原子快照/验证/区块安装与释放/正常保存 |
| scripts/item_inventory.gd | 篝火使用只发放置请求，成功放置时再扣除 |
| scripts/item_ui.gd / item_ground_drop.gd | 原拖拽路由分辨篝火目标，非可燃物不误丢弃，事件位置驱动落点，包外拖拽临时收起 |
| scripts/player.gd / world_map.gd | 原动作循环接独立投掷库，装备/地图取消与恢复 |
| scripts/world.gd | 初始化轻量篝火界面与正常窗口关闭时保存原物品快照 |
| scripts/environment_view.gd / world_environment.gdshader | 正常环境dt推进、已加载火堆的最大软光贡献 |
| assets/campfire/v1 / art/campfire-v1 | 正式画稿及完整来源、提示词、回执、原图、参考哈希 |
| assets/hero/cartoon/campfire_throw.tres | 六段原生部件投掷，世界左向仍镜像；原角色PNG和原动画不改 |
| tools/build_campfire_throw.gd / package_campfire_v1.py | 可复查的动作构建及画稿完整归属整理 |
| tests/test_campfire_v1.gd / test_campfire_drag_v1.gd / test_campfire_persistence_v1.gd | 本轮核心、原生拖拽与跨进程存档专项 |
| tests/test_item_actions_followup_v051.gd | 必要依赖夹具补hunger=50，使食用断言满足新身体系统的真实收益规则 |
| CAMPFIRE_SYSTEM.md、AGENTS、DEVLOG及相关物品/制作/身体/环境/装备/UI规范 | 最终规则、兼容性、验证与边界 |

未重写库存、采集、地图、天气、时间或身体服务。原世界生成器、Seed、自然/采集版本及已有装备快捷引用保持。

## 画稿来源与正式接入

`generate2dsprite → route_media → local:codex-cli / host_image`真实生成一张1536×1024的3×2画稿，原图 `art/campfire-v1/candidate-01/generated.png`；提示词实际附了原游戏同屏及两树两石。六完整裁片：base、lit_reference、flame、icon、roasted_carrot、roasted_mushroom。lit_reference保留作参照，运行用未燃底座加独立火焰，不将几何图形当美术。

各裁片原轮廓完整、不碰格边，色键去背景，等比Lanczos整理到256画布；哈希、坐标、透明边及五参考哈希见 `assets/campfire/v1/provenance.json`。底层精确图片模型和实际费用未暴露，0估价不等于已知实际费用。已按本轮完整接入授权使用，新素材主观审美仍待用户试玩复查。

能力检查记录 `art/campfire-v1/doctor.json`：0 FAIL、5 WARN、8 MISSING。保留了Python路径冲突/GBK编码/非ASCII路径、scipy缺失等提示，以及resvg/ffmpeg/API密钥/Grok CLI缺失；实际生成使用已验证的本地Codex通道，PNG整理使用已就绪numpy/Pillow，不宣称环境全部通过。未额外安装依赖。

## 持久化

原items快照新增campfires.version1，保存唯一ID、x/y、lit、fuel、recipe、elapsed、ready。食材扣除和非空recipe同一原子快照，领取物品和清空recipe同一快照。投料落点也在同一快照保存原格扣量、燃时与点燃；未落点动作不保存、不扣物品。

原区块卸载释放显示节点，状态不删除。仅正在燃烧的状态接收正常环境dt，卸载期间继续正常燃烧/烹饪；重载只恢复一份显示。旧档缺字段默认空，未知版本/非法数据保护源档。沿用15秒自动保存，并补上原世界入口缺少的WM_CLOSE_REQUEST物品快照保存；运行测试实际调用窗口关闭通知验证当前数据落盘。燃时变化不每帧写磁盘，无离线追赶。暂停/调试一天预览/直接设小时不会推进。

## 实际运行验证

以下均为Godot原生执行，不把静态源码阅读当成运行通过。

| 执行 | 实际结果 | 证据 |
|---|---|---|
| 本轮核心无头最终 | 74项，0失败 | headless-final-close.log、headless.json |
| 核心真实窗口 | 70项，0失败；对应核心同一套，不重复计算 | window-final.log、window.json、fire-night/off、panel-960/1280/1600截图；额外湖泊/通道及定期/关闭保存四项后补在无头74中 |
| 拖拽专项无头最终 | 48项，0失败 | drag-headless-final.log、drag-headless.json |
| 拖拽专项真实窗口最终 | 48项，0失败；同一套功能复核 | drag-window-final.log、drag-window.json、throw/pose/cooking-drag-only截图 |
| 独立进程：中途读入→完成保存 | 6项，0失败 | persistence-mid-final.log、persistence-mid.json |
| 另一进程：待领读入→领取保存 | 6项，0失败 | persistence-ready-final.log、persistence-ready.json |
| 再一进程：已领读入→重复领取拒绝 | 5项，0失败 | persistence-claimed-final.log、persistence-claimed.json |
| 必要制作进度依赖 | 37项，0失败 | crafting-dependency.log |
| 必要身体依赖 | 533项，0失败 | body-dependency.log |
| 必要现有背包操作依赖 | 58项，0失败 | item-actions-final.log；原生右键/拆分/销毁/拖放/保存恢复 |

覆盖：真实干燥地面放置、实际左键确认、取消不扣、真实湖水与主要通道拒绝、重叠拒绝；燃料/食材/领取原子性；满包保留；两种熟食右键与快捷栏食用；原BodyState饱腹保护；真实区块unload_chunk/install_chunk恢复；旧档/未来版本/非法数值保护；暂停/调试预览/设时；跨进程未完成/待领/已领；快捷栏及背包原生GUI拖拽；非可燃物不丢弃；左右手/四方向选择；主手持镐时工具保留；动作取消、物品移位、装备改变、地图切换、超距及燃时容量余量；正常物理帧自动完成投掷。真实窗口核对夜间开/灭光、火焰、三尺寸与1/3高度薄条。

### 中间失败与夹具修正

- `reports/campfire-import-first.log`：最初UI常量Skin遮蔽引擎类，改为CampSkin，后续原生加载与运行正常。
- `first.log`：新增物品drop_rules缺source影响图鉴；补齐真实获取来源。960夹具未设置逻辑视口，修正content_scale_size。最终原生日志干净。
- `drag-first.log`、`drag-diagnostic*.log`：合成输入下原生拖拽位置回调取到桌面指针而不是事件落点，错误进入原地面丢弃；改为沿现有输入路由记录实际MouseMotion/MouseButton位置，目标和背包收起均用该位置。最终无头与真实窗口均通过。
- `drag-window-first.log`：首轮窗口一次拖拽未启动；夹具补一次可见日志的重新按下/移动机会，不跳过最终拖拽断言，最终48项通过。没有把旧失败计为通过。
- `headless-final.log`：真实区块重建夹具传入未带元素类型的空stamps数组；修为与正式worker相同的Array[Dictionary]后重跑。
- `headless-chunk-final.log`：未来存档夹具写临时JSON后未显式关闭句柄，造成空JSON读取而非目标未来版本测试；修为write_fixture显式关闭。`headless-final-clean.log`72项无脚本错误；再补定期/窗口关闭保存，`headless-final-close.log`最终74项无脚本错误。
- `item-actions-dependency.log`：误以无头方式启动旧窗口截图夹具，其等待frame_post_draw没有完成，已停止，不计通过。改跑适配无头的followup夹具，并为当前BodyState补真实饥饿收益前提，最终58项通过。

## 尚未验证与限制

- 未做数小时平衡试玩、全Seed/全地图穷举、FPS压力基准或任意数量篝火压力测试，不给性能结论。
- 已加载屏幕附近暖光最多32个，取最大软光贡献而非相加。更多密集篝火不承诺同时独立照明；其燃料/烹饪/存档状态仍独立。
- 四向左右手关键姿态均在真实窗口核图，自动物理完整投掷已运行；未将八种组合都描述为人工长时间逐帧试玩。
- 美术及实际操作手感等待用户试玩复查。未新增拆除、搬迁、房屋、工作台、种植、燃烧蔓延、雨水灭火、NPC、战斗或其他阶段。

本轮功能已完成，停止继续扩展。详细参数与实现契约见 `CAMPFIRE_SYSTEM.md`。
