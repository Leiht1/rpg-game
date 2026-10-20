# 营地扩展 V2 · 候选开发交付

2026-10-20。已完成本轮功能与独立候选试玩，等待用户具体确认本批新图、尺寸和体验；未推广正式素材，未自动提交或推送，未进入野外NPC系统。详细规则、逐项实际成本/ID及尺寸表见 [CAMP_EXPANSION_V2.md](../../CAMP_EXPANSION_V2.md)。

## 结果与试玩

启动项目根目录 `Start-Camp-Expansion-V2-Preview.cmd`。同Seed271828独立世界，`persistent_world=false`，覆盖世界身份保存入口为空操作。预置十五设施＋地板/大地毯，磨损铜工具/剪刀/钓竿、腐坏鱼、肥料和建造材料仅存在于候选进程。E打开四新设施，V自行选择、放置；关闭即丢弃候选进度，不读写玩家正式世界。尚未向正式入口开放候选。

九种既有设施分别设置画稿边界、接地、底座及最近点交互：木箱降低到约56×43，柜69×69，冰箱73×91，普通台76×63，烤箱87×96，金属台108×84，熔炉132×132，路标38×41，羊毛地毯144×96（原96×64，面积2.25倍）。这是逐设施配置及真实底座调整，不是全体同倍率缩放；所有既有PNG原样保留。篝火/火把、铺面拼接、墙/栅栏/门、床席/睡袋维持原规则。

新增四设施为有功能候选：维修现存磨损工具；储存真实燃料并自动补给附近熔炉/烤箱且不点火；腐坏食物/鱼或植物发酵肥料，使本季作物×1.25生长；湖鱼＋木材熏制常温8日/冷藏14日的烟熏鱼。均沿原库存与建筑 items 原子快照，保存失败回滚；领取成功才进入获得提示队列，满包保留待领。

四新配方开始即见，`conditions=[]`、默认开放，无科技/等级/图纸/剧情/先建某台限制。候选开关仅用于本批未获美术批准的入口隔离，并非玩法阶段解锁。材料不足显示原界面的拥有/需要；取消/失效不扣料。

## 最终材料映射

| 建筑 | 实际材料名称、ID、数量 |
|---|---|
| 精密维修台 | 木材 `wood`14；石块 `stone`12；燧石 `flint`6；铜制零件 `copper_parts`8；银锭 `silver_ingot`3 |
| 自动燃料供给箱 | 木材 `wood`18；石块 `stone`18；植物纤维 `plant_fiber`12；铜板 `copper_plate`6；铜制零件 `copper_parts`4；银锭 `silver_ingot`4 |
| 发酵堆肥桶 | 木材 `wood`18；石块 `stone`14；植物纤维 `plant_fiber`16；铜板 `copper_plate`3；金属连接件 `metal_connector`2 |
| 高级熏制房 | 木材 `wood`28；石块 `stone`24；燧石 `flint`8；植物纤维 `plant_fiber`12；铜板 `copper_plate`6；金属连接件 `metal_connector`4；银锭 `silver_ingot`4 |

与建议的数量差异为0；将铜类别8/10/5/10件映射为现有不同结构加工件，银类别改为正式银锭3/4/0/4，因为现有九条金属加工配方无银零件。没有新增虚构材料、金矿或金币消耗。

核对加工产出：铜板每铜锭1件，铜制零件/连接件每铜锭2件，熔炼每锭耗对应矿石2。四设施折合铜矿8/16/8/16及银矿6/8/0/8，不含燃料/工具成本。与普通工作台（木12石8纤维4）、熔炉（石16木6燧3）、金属台（铜锭3木12石6）相比，靠多材料与金属加工形成门槛；没有额外解锁条件。原九配方和产量未改。

## 实际验证

版本 Godot **4.7.2.stable.official.ed1daf0bf**。真实窗口使用当前项目默认 **1280×720**，Compatibility/OpenGL，RTX3060。没有切换其他分辨率。实际断言逐条保留于本目录JSON。

| 专项 | 结果 | 证据 |
|---|---:|---|
| 新功能与原建造事务，真实窗口 | 210项、0失败 | `window.json`、`window.log` |
| 独立候选场景/交互/睡眠/V列表，真实窗口 | 18项、0失败 | `preview.json`、`preview.log` |
| 新进程读取本轮隔离快照 | 7项、0失败 | `read.json`、`read.log` |
| 连接/门/铺面/睡眠几何定向对照，无头 | 21项、0失败 | `geometry.json`、`geometry.log` |
| 原库存自然腐坏建造依赖，早期定向验证 | 31项、0失败 | `build-freshness.log` |

功能项覆盖：四种建筑真实材料成本与无前置、开始/取消不扣料、库存变化/失效位置拒绝、保存失败建筑/扣料回滚、十工具保存失败与满耐久/不存在拒修、装备别名同实例修复、真实鼠标点击维修；燃料存取失败回滚、非燃料拒绝、距离及熔炉/烤箱白名单、实际消耗、不自动点火、已点火低燃料续供；堆肥允许/拒绝材料、正常分钟推进、重复领取拒绝与失败回滚、施肥一次性/生长125%/收获数量不变且清标记；烟熏鱼投入与领取回滚、满包保留、正常分钟加工、常温/冷藏腐坏与获得通知；非法进度状态拒绝、旧建筑无扩展字段仍合法、普通入口无候选配方和新尺寸。

候选场景确认十五设施全显示、四设施实际世界交互与底座相符，木床/草席可睡眠/醒来，V能选择高级熏制房。独立进程读取已完成肥料、部分熏制进度、供给箱库存、本季施肥标记及烟熏鱼新鲜度；读取本身不推进加工。

几何对照为候选开关前后逐项比较真实形状、底座位置、门扇碰撞多边形、子部件数、端点及连接数；覆盖木/石墙栅栏与门横竖/开关，床/席两方向和睡袋，木/石混铺南侧邻接。并非重跑旧全量建筑验收，也不声称测了所有动态门避让。

各世界测试前后实际 `user://` JSON/tmp文件SHA字典完全相同。仅本目录隔离快照曾落盘，独立重启验证后清除。未修改正式玩家物品、世界身份或存档路径/版本。

早期失败已定位：测试夹具用StringName作为建筑ID导致校验拒绝，改为与正式保存一致的String；候选场景动态向量缺少显式类型导致解析失败，已修复；陈列原流程按真实成本检查，缺少床/金属台材料造成漏摆，已补候选夹具材料。无头鼠标warp不执行，真实鼠标验证限定窗口环境；最终真实窗口点击通过。早期失败日志/JSON保留为诊断，不作为最终通过数。最终窗口/预览/重启/几何日志无SCRIPT ERROR或ERROR。

## 美术、来源与QA

- 六张新512×512 RGBA均在 `prototypes/camp-expansion-v2/final`：四设施、肥料、烟熏鱼，**全部 pending_user**。没有把候选写成正式批准。
- 既有九设施重用正式PNG，只改变候选绘制/底座配置；原PNG的SHA登记在 `art/camp-expansion-v2/provenance.json`。普通入口尺寸不变。
- 第一张由 generate2dsprite→generate2dmedia route_media→本地Codex CLI生成；请求模型 `codex-image_gen`，工具内部具体版本未公开。修订CLI返回 `TOOL_UNAVAILABLE`（run `7dd333cd33cc41e6b36f0010d87cc147`），未掩盖该失败；随后用内置image_gen完成编辑，模型版本与精确计费未公开。无API密钥/付费API请求；本地订阅路线的0美元估算不表示没有订阅额度消耗。
- 保留逐次原图、原始提示词、实际输入引用哈希、失败、无损切图所有权、处理脚本、软抠记录和六张最终SHA。原图没有按等分行守边，因此按空白区 **y=470** 划所有权，完整保留各部件后不缩放地重排到640方格，再经技能soft key/Lanczos/feet锚点处理。无程序重画/补绘像素。
- 原图QA实际失败留档：首图 `cross_cell_components=3>0`、`cross_cell_visible=3>0`，`boundary_band=10434>0`、`safe_frame=5>0`；修订原图对应值1、1、1719、4。前两项FAIL，后两项WARN，不能称原图QA全通过。
- 重排图跨格、切边、空格、边界带均通过；仍有 **`safe_frame` WARN：3>0**，格为(0,0)/(0,1)/(1,0)，阈值为边缘至少留15%，已人工检查完整轮廓；这不是素材获批。六单图strict QC均pass，关键色残留0、ring spill0；单张图无动作/多帧一致性检验。
- doctor为WARN：`python.path`（WindowsApps解释器）、`encoding.stdout`（gbk）、`encoding.files`（cp936）、`paths.cwd`（中文路径），以明确Python、UTF-8文件读写/环境及路径引用处理。另有7项MISSING（resvg、五API配置、Grok），本次不需这些路线；具体原因原样见doctor.json。没有伪称全环境无警告。
- 观察了浅色/深色透明边、默认窗口实景及四设施纸布界面。留作来源验收参考的 `acceptance-sheet.png` 保留；reports内窗口PNG仅暂留待本批验收确认后按AGENTS清理。

## 修改/新增文件

新增运行/数据：`scripts/camp_expansion.gd`、`scripts/camp_expansion_ui.gd`、`scripts/camp_expansion_preview.gd`、`data/camp_expansion_v2.json`、`data/camp_volume_v2.json`、`scenes/camp_expansion_preview.tscn`、`Start-Camp-Expansion-V2-Preview.cmd`（以及引擎产生的对应UID）。

增量接入：`data/buildings.json`、`data/camp_buildings.json`、`data/items.json`；`scripts/camp_buildings.gd`、`scripts/camp_building.gd`、`scripts/craft_book.gd`、`scripts/item_service.gd`、`scripts/item_ui.gd`、`scripts/world.gd`、`scripts/world_interaction.gd`、`scripts/planting.gd`、`scripts/industry_service.gd`、`scripts/industry_effects.gd`、`scripts/food_freshness.gd`。

测试与来源：`tests/test_camp_expansion_v2.gd`、`tests/test_camp_expansion_geometry.gd`，`art/camp-expansion-v2/`内生成/处理/QA/来源文件，`prototypes/camp-expansion-v2/final/`六PNG，本目录报告与断言结果；`.gitignore`仅追加隔离快照规则。

文档：`CAMP_EXPANSION_V2.md`、`CAMP_BUILD_SYSTEM.md`、`INDUSTRY_SYSTEM.md`、`PLANTING_SYSTEM.md`、`PROJECT_STATUS.md`、`DEVLOG.md`。保留任务开始前工作区已有修改，不把其他钓鱼/废弃营地/音效等既有改动算作本轮工作。

## 验收重点与未做

建议先看同屏箱→柜→冰箱、普通台→金属台→熔炉、熏制屋与熔炉差异，走近并绕行大设施，再试地毯实际展开范围；再各修一次剪刀/钓竿、给供给箱存木材并手动开炉、投入腐坏鱼做肥料施于未成熟作物、熏鱼并放入冰箱。画风、轮廓、屋顶倾斜、管口与桌腿比例仍以用户审美验收为准。

没有正式推广候选、美术批准、全量回归、多分辨率、长期从零采矿成本/数日囤积平衡、极大量供给箱/大营地FPS、写盘过程中进程被强制终止的注入测试，或动画中途新进入障碍的门动态避让测试。正常写入失败路径已测，不等同覆盖所有硬件断电情形。未做保温棚、高级鸡舍、NPC、科技树、复杂自动化、额外鱼种/大量额外烟熏食材、新农业系统、多格地毯占地或独立腐坏烟熏鱼新图。完成本轮停止，等待验收。
