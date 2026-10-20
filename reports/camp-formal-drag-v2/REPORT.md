# 营地扩展V2正式接入与背包拖拽修复

2026-10-20。用户明确“接入吧，然后做一些改动”，本批授权范围为当前营地V2、正视及尺寸修订、紧凑面板与鱼腐坏修订；不批准未来素材。

## 正式接入

普通Start-Playtest入口直接使用九种既有体量与四种新设施，四新配方从开始显示，无科技/前置设施条件；缺材料正常显示需求。维修原有磨损工具；供给箱仅向附近熔炉/烤箱补实际燃料、不代开火；堆肥产肥料促生长；熏制只接受未腐烂烤鱼＋木材，产出“熏制烤鱼”，常温/冰箱30游戏日。原放置/扣料、库存/世界同次原子保存及失败回滚保持。

本批正式PNG共10张：正视维修台、供给箱、堆肥桶、熏制房、冰箱；肥料、熏制烤鱼；腐烂湖鱼、烤鱼、熏制烤鱼。逐字节迁入assets/camp_expansion/v2，provenance.json记批准原话、范围、原来源及SHA。九种尺寸调整与真实底座、成本/实际物品ID见[权威规范](../../CAMP_EXPANSION_V2.md)。旧原图完整保留。四行27种全建筑对比入口仍保留，独立世界不写玩家档；普通入口不投测试材料。

## 背包拖拽

背包/装备面板原Z=12，共用原生拖拽PanelContainer默认Z=0，因此图标被背包遮住；快捷栏没有同样的高层背景。仅把共用拖拽影像Z设为100并忽略鼠标命中，仍由Godot原生拖拽移动/释放，不创建第二套跟随或库存路径。默认窗口截图已观察，背包上方可见木材影像并随鼠标移动。

## 本次实际验证

Godot4.7.2，项目默认1280×720真实窗口：

- 正式/拖拽66项0失败，window.json：关闭候选标志的隔离正式世界、10图来源/正式SHA一致及加载、四配方从开始可见、普通尺寸生效、墙门床席配置稳定、三鱼正式腐坏图、背包内移动、快捷栏到背包、背包到快捷栏、原生鼠标跟随位置/显示层级、取消无损、实际玩家JSON/tmp哈希保护。截图bag-drag.png、hotbar-drag.png、bag-to-hotbar.png为本轮临时反馈图。
- 四设施原事务专项210项0失败，facilities-window.json：实际建造与成本、位置/库存变化拦截、保存失败整体回滚、工具维修、有限供燃料/不代开火、堆肥/施肥、烤鱼加工/领取/腐坏、存档校验等；专项保留其隔离fixture标志，正式无标志入口另由上述66项覆盖。
- 独立新进程读取7项0失败，read.json：肥料待领、熏制进度、供给燃料、施肥标记、食物腐坏状态及玩家档保护。
- 导入10张正式图成功。设施专项进程退出报告CanvasItem/ObjectDB/GL纹理等资源释放警告，不能称日志完全无警告；没有在本轮附带资源生命周期重构。正式/拖拽和独立读取进程未出现该退出警告。

所有测试使用隔离世界/报告内快照，不读写正式玩家档；实际玩家JSON/tmp哈希一致。未做无关全量回归、其他分辨率、大营地FPS、长期采矿/储存平衡或人工长时间试玩。

## 本次文件

新增assets/camp_expansion/v2内10PNG与导入记录、provenance.json；tests/test_camp_formal_drag_v2.gd；本报告与断言结果。

修改data/items.json、data/buildings.json、data/camp_buildings.json、data/camp_volume_v2.json、data/camp_expansion_v2.json；scripts/camp_buildings.gd、scripts/camp_building.gd、scripts/craft_book.gd、scripts/item_service.gd、scripts/item_ui.gd（移除候选目录过滤）、scripts/item_slot.gd；tests/test_camp_expansion_v2.gd正式期断言，tests/test_camp_food_polish_v2.gd正式图期望引用（本轮未重跑其83项）。同步CAMP_EXPANSION_V2.md、INDUSTRY_SYSTEM.md、UI_ART.md、PROJECT_STATUS.md、DEVLOG.md。工作区原有其他修改保留，未提交推送。

依AGENTS“本批确认后立即清理临时媒体”，仅清理三个已确认阶段reports目录的19张窗口PNG，逐项记录accepted-media-cleanup.json；正式图、生成原图、提示词、来源/QA验收图均保留，旧报告窗口图片链接可能失效。

建议重点试背包内拖动及背包/快捷栏互拖，再从普通入口V列表建造四设施。NPC、保温棚、高级鸡舍与复杂自动工业均未开发；完成本轮停止。
