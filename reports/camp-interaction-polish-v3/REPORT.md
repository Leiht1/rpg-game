# 营地交互修订 V3

2026-10-20，Godot 4.7.2，默认 1280×720 原生窗口。

## 本轮改动

- 自动燃料供给箱：主界面分开显示已投入材料总量、各材料小图标与数量；投入按钮打开材料卡片与数量二级窗口。取消不扣料，成功提交更新库存和总量；投入后禁止取回，服务范围和自动补燃料规则保持。
- 高级熏制房：删除名称下描述，按钮信息不变，面板收至420×144。
- 动物饲料槽：已投放饲料使用24像素真实物品图标及名称、数量。
- 施肥：E直接播放现有弯腰伸手动作，接触时提交原有施肥事务；成功提示“肥料 -1”，作物短暂发光。失败不显示成功反馈，不弹窗口。动作期间目标已成熟时拒绝转为收获。
- 动物饲料槽、发酵堆肥桶的V建造配方移至种植类别，成本和开放规则不变。
- 发酵堆肥桶保持420×232，按钮不再撑大滚动容器；长列表在框内滚动。燃料供给箱420×220，未缩小字体或物品按钮图标。

## 验证

运行 tests/test_camp_interaction_polish_v3.gd，最终80项、0失败，结果见window.json。覆盖燃料材料卡片选择/取消、原生数字输入、指定数量提交、总量与图标、禁止取回及保存失败回滚；堆肥40条列表边界、长名称、原生滚轮；熏制房尺寸和按钮文案；饲料图标与类别；E施肥动作、接触结算、仅扣一次、提示/发光、失败回滚及无成功反馈。实际窗口截图已检查堆肥按钮位于框内、供给箱总量与投入分区清楚。

数量输入使用原生按键验证，窗口可见性断言等待既有淡出动画结束。此前排查中的失败未记为通过，以上数量仅指最终运行。

测试使用独立展示世界（persistent_world=false）和报告内保存路径，保存失败使用报告内不存在路径；不修改或回滚玩家存档。失败注入会显示预期“物品存档未能写入”提示。无新美术、无素材替换、无存档格式变更。

未重复全量回归、设施完整210项旧测试、新进程读取、多分辨率、长期人工平衡或大营地性能。临时截图等待本轮反馈后清理，文字报告保留。不提交推送，不进入NPC。

## 文件

运行：scripts/camp_expansion_ui.gd、scripts/camp_expansion.gd、scripts/industry_ui.gd、scripts/player.gd、scripts/world_interaction.gd、scripts/planting.gd、scripts/item_ui.gd、data/buildings.json。
测试：tests/test_camp_interaction_polish_v3.gd；同步旧断言 tests/test_camp_expansion_v2.gd、tests/test_camp_food_polish_v2.gd（本轮未重新运行这两套）。
文档：CAMP_EXPANSION_V2.md、PLANTING_SYSTEM.md、UI_ART.md、INDUSTRY_SYSTEM.md、PROJECT_STATUS.md、DEVLOG.md、本报告。
