# 营地面板、腐烂显示与烤鱼熏制修订

2026-10-20，Godot 4.7.2，默认1280×720。最新规则见 [CAMP_EXPANSION_V2.md](../../CAMP_EXPANSION_V2.md)。

- 堆肥桶420×232、熏制房420×180固定纸布框，替代原共用600×520。保留字号、36px图标与48px按钮最小高度；长列表用原生滚轮滚动，不扩框。空闲、加工、成品状态保持外框尺寸。
- 食物腐烂显示“原名（腐烂）”，不改物品ID/存档；背包/快捷悬停、储物悬停、堆肥投入、产物待领、数量/拆分/丢弃窗及地面提示使用实例名称。背包悬停原错误的新鲜图改用实际实例图。地面自然腐坏同步更新实例显示元数据。
- 湖鱼、烤鱼、熏制烤鱼的腐烂图保留完整鱼形，以变色、少量霉斑/腐气表现；不再在候选入口复用碗装蘑菇。三新图 pending_user，只在候选使用，正式美术未替换。来源/提示词/处理/SHA/QA见 [provenance.json](../../art/rotten-fish-v1/provenance.json)。正式入口仍保留之前获批的复用图，待本批确认后再迁入。
- 熏制仅接受未腐烂烤鱼×1＋木材×1，产出“熏制烤鱼”×1，ID仍smoked_fish，常温/冰箱均30游戏日，沿正常120游戏分钟加工与原领取体系。生鱼、腐烂烤鱼、蔬菜及鱼汤不接收；未新增其他熏制配方。

## 验证

[window.json](window.json)记录默认真实窗口83项、0失败：全部可腐坏食物名称/图标可用、三鱼候选图统一引用、悬停名称与图标、紧凑框、40项原料列表原生滚轮、工作/待领尺寸固定、成品腐坏后名称与图标更新、烤鱼白名单、实际扣料、保存失败回滚、正常加工/领取、30日前后边界、待领记录校验和实际玩家JSON/tmp哈希保护。

查看本轮实景截图：compost-short.png、compost-scroll.png、smokehouse-idle.png、smokehouse-working.png、smokehouse-ready.png。均为临时验收媒体，待确认按项目规则清理；文字记录及来源记录长期保留。

美术QA：初次湖鱼 `key_ring_spill` WARN，value=0.087655，threshold=0.01，文件art/rotten-fish-v1/processed/lake_fish/clean.png；采用despill-radius1修订，最终art/rotten-fish-v1/processed-despill/lake_fish及另两鱼QA均pass。历史警告保留在provenance；主观画风/腐坏程度等待用户。

未执行全量回归、多分辨率、长期保鲜/平衡试玩及其他设施完整功能回归。上一轮测试记录不冒充本轮复测。

## 文件范围

scripts/camp_expansion_ui.gd、camp_expansion.gd、camp_expansion_preview.gd；data/camp_expansion_v2.json、items.json；scripts/item_service.gd、item_ui.gd、camp_storage_slot.gd、industry_ui.gd、industry_service.gd、campfire_ui.gd；tests/test_camp_food_polish_v2.gd；既有tests/test_camp_expansion_v2.gd同步最新配方/保质期及陈列数量断言（未重跑）；art/rotten-fish-v1及prototypes/rotten-fish-v1；CAMP_EXPANSION_V2.md、UI_ART.md、INDUSTRY_SYSTEM.md、PROJECT_STATUS.md、DEVLOG.md与本报告。

入口仍为Start-Camp-Expansion-V2-Preview.cmd，隔离同Seed世界；新增烤鱼和腐烂鱼类样品仅在候选进程背包供对比，关闭即丢弃，不投放玩家存档。无正式素材迁入，无提交推送，无NPC。本轮停止待验收。
