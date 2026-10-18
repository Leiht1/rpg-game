# 基础营地建造 V1 · 实现与验证报告

日期：2026-10-18。运行 Godot 4.7.2.stable.official.ed1daf0bf，Windows，Compatibility/OpenGL 3.3，NVIDIA RTX 5060。

## 交付状态

已正式接入，包括原篝火在内共十种建筑、独立结构网格、连接、门、连续铺设、木箱、工作台、火把、锤拆、四工具耐久、产量和原子存档扩展。

**本批已获具体确认并正式推广。** 用户明确回复“采用这批美术”，16图按哈希原样迁入 assets/buildings/v1，批准原话与具体范围记录于正式 provenance.json。运行、预览、物品图标和石锤持握全部改用正式路径。`Start-Playtest.cmd` 无需预览开关即可在V中建造全部十种建筑，石锤在C制作；`Start-Camp-Build-Preview.cmd` 继续作为不读写正式存档的独立临时试玩。未来新素材不自动获批。

## 本轮文件

新增逻辑：

- scripts/camp_grid.gd：全局格、边段身份、连接图、交点归属和门内外侧解析。
- scripts/camp_buildings.gd：建筑占用、合法性、放置/替换/拆除事务、门、箱子操作与存档校验。
- scripts/camp_building.gd：真实节点、脚底碰撞、门轴与门板碰撞、Y 排序和损伤反馈。
- scripts/camp_storage_ui.gd、camp_storage_slot.gd：原纸布风格储物 UI，原库存/装备引用与拖拽。

修改原脚本：

- item_inventory.gd：耐久迁移、有效动作扣损和损坏清引用。
- item_slot.gd、item_ui.gd：细条、精确耐久、储物转移及实际悬停来源定位。
- item_service.gd：同一原子快照的建筑字段/校验/流式节点，以及奖励和耐久提交。
- chunk_stream.gd：原砍树命中耐久及两批奖励数量。
- world_interaction.gd、player.gd、held_tool.gd：E 目标/能力与原生四方向石锤动作。
- campfire_service.gd、campfire_ui.gd、craft_ui.gd：复用 V/C 菜单、预览、材料与差额说明、连续放置。
- world.gd：独立预览与储物 UI 生命周期。
- environment_view.gd：火把复用原暖光通道。

数据：data/items.json、recipes.json、buildings.json、harvest_resources.json、held_tools.json；新增 data/camp_buildings.json。

其他：Start-Camp-Build-Preview.cmd、tests/test_camp_build_v1.gd、tools/prepare_camp_art.py、CAMP_BUILD_SYSTEM.md、DEVLOG.md、AGENTS.md、ART_STYLE.md、UI_ART.md；本目录结果与截图、assets/buildings/v1、art/camp-build-v1、prototypes/camp-build-v1。

工程原来已有大量未提交工作，本清单仅列本轮实际编辑/新增文件，不将其他现存修改归为本轮成果。

## 数据与交互

完整逐项成本、ID、命中次数见 ../../CAMP_BUILD_SYSTEM.md 及 ../../data/camp_buildings.json。九种新建筑材料精确采用任务表；篝火 wood4/stone6/flint1 保持。石锤 wood3/stone2/flint1，原 1.5 秒制作。没有增加其他材料或额外建筑。

V/C 和原十卡分类界面复用；选中后 R 横纵/F 开启侧，左键单放或拖动结构/地面；取消不回退已成功提交的段。费用逐段提交，保存失败回滚。门替换仅扣差额且保留实例 ID；返料仅真实拆除发生。工作台仍调用原制作面板。

96×64 全局格与地形 CELL48 区分。当前角色脚底直径20，边段厚8，纵向内部通道56。图内柱端共享、石木混接与15种连接 mask 均基于稳定结构数据，不靠图片判定。

门开启侧转为持久化 swing=±1，0.25 秒轴转动画与真实碰撞多边形共用角度；开门移开通道碰撞，关闭前拒绝角色处于运动范围。JSON 数值读回转为浮点的问题已由独立重启测试发现并修正，swing 经数值校验及整数归一化。

四工具实例耐久100；有效提交消耗1，末次动作仍有产出。原已有实例字段/背包/快捷/装备及丢弃流程都复用；箱子不是第二套玩家库存。

12格箱支持存取、交换、合并、箱内拖动、拆分、使用/装备/销毁；工具在装备→箱→快捷别名→箱→背包往返保持实例及耐久。被保护的箱/篝火不先扣锤耐久。拆除返材落地，满包无需接收材料；返料原子写入 loose，不能因重复敲击再次生成。

## 实际运行结果

| 运行 | 结果 | 证据 |
|---|---:|---|
| 正式路径专项无头 | 112项、0失败 | formal-tests.json、formal-headless.log |
| 正式路径真实窗口 | 112项、0失败 | formal-window-tests.json、formal-window.log |
| 正式路径退出后新进程读取 | 7项、0失败 | restart-tests.json、formal-restart.log |
| 原料理/发现必要依赖 | 87项、0失败 | cooking-dependency.log |
| 原数量投放必要依赖 | 19项、0失败 | drop-dependency.log |
| 生成切片结构检查 | 16帧、pass | ../../art/camp-build-v1/processed-owned/pipeline-meta.json |

测试覆盖所有15种端点连接、真实地形放置/重复占用/连续墙和地板/缺料保留前段、差额替换、真实开关碰撞射线、角色避让、最后一点耐久完成砍/矿/挖/拆、真实返料数量、箱子及三种篝火保护、箱子拖拽/拆分与陈旧快照、保存失败回滚、非法版本/重复实例、卸载重载，以及三分辨率UI。另验证未启用预览meta时十条建造和石锤默认开放、图标使用正式获批路径。确认前110项结果保留为历史。

独立新进程恢复39个展示建筑、开门状态、石墙受损2次、两个箱子中73/41耐久工具及地面拆除返料，二次加载不复制实例。使用报告专用存档，未改写玩家正式存档。

最终日志只有引擎/显卡和通过计数，无脚本报错或退出泄漏提示。早期调试日志保留，不作为通过证据。

## 原生窗口图片

均为真实 Godot 渲染。界面与游戏动作由测试调用原 UI/交互处理器；不是完整人工鼠标键盘通关测试。

- build-menu-960.png / 1280.png / 1600.png：原建造面板及分类/材料。
- storage-960.png / 1280.png / 1600.png：12格箱、32格背包及装备，耐久41/73/25。
- durability-960.png / 1280.png / 1600.png：原背包/装备预览、细条及精确悬停73/100。
- storage-split.png：纸布数量窗、合法拆分数量。
- camp-candidate-day.png：4×4作者布置样板的墙/混接/地板/设施/角色同屏。
- camp-candidate-gate-open.png：单扇门打开后的门轴/落点。
- camp-candidate-night.png：原环境夜色及火把暖光。

展示营地由测试布置用于检查画面，不将它冒充玩家从零采集并全程拖建的6×6营地。实际成本提交由前述独立原生控制器测试验证。

## 资源与标准营地平衡

树木仍两/四次有效砍击，每两击一批4–6木，大树总8–12；石矿仍5击，完成12–16石；纤维点4–6；普通石矿独立 hash 约30%额外燧石1。10000个 hash 样本验证在28–32%范围，真实矿完成验证产石范围和不重复结算。

23墙+1门+篝火+工作台+箱：石158、木32、纤维11、燧1，自动求和一致。另6木地板/4石路：木24、石20。石材相当于约10–14个完整石矿，木料约6–8棵小树或3–4棵大树，纤维约2–3点；这是产量计算，不是实测采集总耗时。

没有改变采集次数、动画时长、体力速率、地图生成位置或 Seed。矿物/自然层版本和 ID 保持；旧已采记录和剩余 loose 数量继续生效。

## 美术来源与确认

实际 route local:codex-cli，工具回执 model=codex-image_gen；不声称获知底层图片模型。estimateUsd=0 是订阅路线估计，不等于核实账单费用。

附现有角色实景和原树石图。生成原图1254×1254，默认四等分使火把越过源格边；按实图所有权边界修正为 y=[0,313,627,917,1254] 后重新运行受控切片，16帧严格结构检查通过，保留首次告警结果。最终透明裁片与 SHA256 位于 prototypes/camp-build-v1/provenance.json。

原角色、原地表、树石、篝火图未替换。本批已由用户明确“采用这批美术”批准，16张正式图与展示候选SHA256一致；本次正式采用没有重新生成或视觉修改。原候选provenance的pending状态作为确认前历史保留，当前批准以assets/buildings/v1/provenance.json为准。

## 尚未完成/未验证

1. 尚未人工从零采集并实测搭建完整6×6营地的总耗时，未据此宣称平衡已获最终验收。
2. 未进行大规模营地/全地图FPS、长期运行内存及强制断电测试；无性能提升结论。
3. 家具第一版只提供原图及镜像两种可见朝向，没有新增四套家具透视；门和边段支持横纵。
4. 极大或两侧均围合的门以内外侧明确选择为准；自动内部检测有1024格计算上限，但没有营地规模限制。

没有开放屋顶、房屋/室内、多层、种植、NPC、战斗、修理或额外配方。本批已确认接入，本轮完成停止，不进入其他玩法。
