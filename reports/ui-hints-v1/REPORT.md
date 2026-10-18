# 配方卡与地图交互提示局部修订

2026-10-17，已正式接入。

- 配方卡的暗黄来自材料不足时整卡modulate染暗，现全部保留浅纸底。选中项使用已批准的slot_selected金色细边画稿与“已选”文字，未选中仍用轻纸布签；所有状态内容边距一致，不改变面板/卡片尺寸。
- 配方Button的tooltip_text置空，取消灰色悬停描述；右侧原描述继续保留。
- 地图靠近目标提示改用独立单层薄纸画稿，无偏移底页、无右下折角，紧凑围绕文本。背包物品悬停纸笺保持。原2秒隐藏、离开后再显示、切目标重计时规则不改。

## 资源与文件

- scripts/craft_ui.gd：配方卡浅底、选择标记、移除重复Tooltip。
- scripts/item_ui_style.gd：配方专用选中样式与紧凑单层target_hint样式，状态内容边距一致。
- scripts/item_ui.gd：仅将target_tip指向新单层样式；库存、制作、世界交互判定与存档未修改。
- assets/ui/hints_v1/target_hint.png / provenance.json：正式单层图、完整裁片/哈希/alpha与内容区QA。
- art/ui-hints-v1/candidate-01：原图/prompt/route回执，提示词亦保存prompt.txt。
- tools/package_ui_hint_v1.py：完整色键轮廓裁片、等比整理与2px透明安全边；无代码重绘。
- tests/test_recipe_hint_ui_v1.gd：浅底、选择、悬停、尺寸和新提示路径专项；UI_ART、ART_STYLE、AGENTS和DEVLOG同步。

受控generate2dsprite → route_media → local:codex-cli / host_image；精确图片模型未暴露。新生成图只有目标提示一张，配方复用原资源。源图WARN `source_size_mismatch`: value=2182x721, requested=1024x1024; file=art/ui-hints-v1/candidate-01/generated.png。按实际完整轮廓整理，未截可见像素；运行图透明外沿通过、中心alpha=255、最低亮度0.925。来源异常如实保留，不以数字QA代替主观验收。

## 实际验证

Godot4.7.2 Stable / Windows / Compatibility / RTX5060。最终无头专项24项、原2秒时序9项、必要UI布局/交互32项均0失败，合计65检查项。另真实窗口复核24项并核对recipes.png、target-hint.png。初次专项临时创建Tooltip比较对象未释放，退出提示泄漏；已修正测试夹具，最终无头/窗口日志均无该错误，没有生产运行泄漏修复或玩法改动。

日志：reports/ui-hint-final-headless.log、ui-hint-window.log、ui-hint-timeout.log、ui-hint-layout.log；详细断言headless.json、window.json。本轮没有无关全量回归或性能基准，完成后停止。
