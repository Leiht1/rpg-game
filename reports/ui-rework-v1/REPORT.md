# UI美术返工与局部精修 · 2026-10-17

已正式接入轻量旅行手册纸面、亚麻分区、浅布面物品槽、纸布签按钮和纸笺Tooltip。用户认可整体后，进一步去掉物品槽四角包角与缝线、减薄边缘，重新绘制按钮和导航底片；主纸面、Tooltip、辅助分区与外缘小枝叶保持。

## 问题与实际修正

| 问题 | 修正 |
|---|---|
| 旧厚木框和多层高光抢内容 | 重绘薄纸层叠、浅布衬与布签，按界面用途分配视觉重量 |
| 第二版退回同色细线框 | 用真实生成的纸沿、材质结构和低对比宽笔触保留手绘质感 |
| 叶片压字、绿底承载文字 | 独立标题/内容/按钮安全区；枝叶只放快捷栏外侧，忽略鼠标 |
| 槽位包角偏重 | 无包角薄布沿，普通/选中两图统一64×64注册画布；格子显示尺寸沿用原52px |
| 按钮像厚徽章、突出尖头 | 新平直纸布签和独立轻导航底片；去侧翼与厚折端 |
| 小按钮文字贴边 | 去除多余透明侧空白，只留2px透明安全边；全部状态共享内容边距 |
| 点击配方撑大UI | 制作固定1030×600逻辑画布，长详情内部滚动，仅窗口尺寸变化才整体适配 |
| 数量白字依赖强阴影 | 12px深暖棕数量、11px数字键，无粗黑阴影描边 |

## 文件职责

| 文件 | 本轮职责 |
|---|---|
| scripts/item_ui_style.gd | 共享纸/布Texture样式、组件权重、相同按钮状态边距、零按下偏移 |
| scripts/item_ui.gd | 内容安全区、轻分区/Tooltip、外缘小枝叶，隐藏被制作界面覆盖的HUD |
| scripts/item_slot.gd | 新槽位状态、装备小记号、数量与快捷键字体；原交互保持 |
| scripts/item_nav_button.gd | 独立轻导航底片，保留原背包/地图符号 |
| scripts/craft_ui.gd | 材料列对齐、固定主框、详情内部滚动；原制作事务不动 |
| UI_ART.md / ART_STYLE.md / AGENTS.md | 设计方向、用户局部反馈与尺寸稳定规则 |
| tests/test_ui_rework_v1.gd | 原生GUI交互、文字空间、尺寸稳定与视口专项 |
| tests/capture_ui_rework_pilot.gd / capture_ui_refine_v1.gd | 推广前样板和最终实际窗口渲染证据 |

没有在本次返工中改写物品服务、库存容量、物品/配方定义、装备实例、制作事务、地图、角色动画或存档。

## 素材、来源与处理

- `assets/ui/rework_v1/panel.png`、`tooltip.png`、`accent.png`：主纸页/小纸笺/外缘枝叶；同目录原`slot.png`仅继续用于已认可的辅助分区和HUD托底。
- `assets/ui/refine_v1/slot.png`、`slot_selected.png`、`button.png`、`nav_button.png`：最终局部重绘四图，背包/装备/快捷栏物品格及相关按钮均已引用。
- 原始生成图、提示词与回执：`art/ui-rework-v1/candidate-01`及`refine-01`；精修提示词`prompt-refine.txt`。
- 用户局部参考截图保存在`art/ui-rework-v1/references`，上一轮细线框实景保存在`reports/ui-rework-v1/before`。
- 两个正式素材目录的`provenance.json`记录实测裁片、画布、哈希及透明边/内容区QA。整理工具只做色键、完整归属裁片、等比缩小与透明安全边，没有代码重绘或烘焙非等比形变。
- 通道为generate2dsprite → route_media → local:codex-cli / host_image；精确底层图片型号未暴露。订阅路线估价0不代表已核实实际费用。无外部商业素材。
- 原图存在名义格边留白不足、精修返回1254×1254而非请求1024×1024及宽按钮越名义格线的情况，完整数值见`ART_QA.md`。实测归属框保留全部可见画稿，最终透明外沿/不透明内容区/亮度检查通过。

## 实际验证

Godot4.7.2 Stable / Windows / Compatibility / RTX5060。

| 验证 | 结果 |
|---|---|
| 最终导入 | 无脚本错误，refine-final-import.log |
| 原生无头UI专项 | 32项通过，0失败；headless-checks.json / refine-final-test.log |
| 背包操作必要依赖 | 55项通过，0失败；refine-item-actions.log，含拖拽、右键使用/销毁、拆分、输入恢复与既有原子快照往返 |
| 文案空间与交互尺寸 | text-layout.json / geometry-layout.json均为空失败列表；分类、配方、1与99次数、成功/不足状态、背包点击/悬停以及按钮状态边距均检查 |
| 实际窗口渲染 | refine-final-window.log；1280×720，并检查960×540及1600×900逻辑视口，实际输出窗口保持1280×720 |

初次桌面鼠标悬停夹具受桌面指针干扰，Tooltip未出现并提前退出，保留window-first.log，不列为通过。最终窗口截图直接调用原Control回调及Tooltip工厂固定画面；窗口渲染截图不冒充原生桌面鼠标测试，交互通过证据来自无头原生GUI输入专项。没有运行无关全量回归、采集玩法验收或FPS压力基准。

## 实景与边界

先有`pilot.png`代表性组合实景，核图后才推广。最终截图为：`inventory-1280.png`（背包/装备）、`tooltip-1280.png`、`hud-selected.png`、`craft-insufficient.png`、`craft-success.png`、`craft-five-materials.png`。另有`inventory-960/1600.png`、`craft-960/1600.png`，均已按实尺寸核图。

本轮美术与布局已实现并接入，列出的UI检查已实际运行。主观美术仍待用户试玩确认；长配方材料清单需在固定详情区滚动，这是维持主框大小的规则。此前制作大任务的其他玩法验收不在本轮完成声明内。无新玩法、无存档路径变更，完成后停止。
