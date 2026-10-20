# 正视候选与全部建筑对比

2026-10-20，Godot 4.7.2，项目默认 1280×720。

按最新要求，将维修台、燃料供给箱、堆肥桶、熏制房及冰箱改为正对镜头，消除原侧向偏转。其余已正对镜头的设施保留原图。五张图仅候选，未替换任何正式 assets；肥料和烟熏鱼沿用上一批候选。

独立地图四行固定排列全部26种注册建筑及独立篝火，共27种，每种标名，保留正常交互。行间距192，初始总览缩放0.65；墙门为正面默认方向，床席为现有横向默认方向，并未移除它们原有的旋转功能。全部种类均已陈列，不表示所有旋转/开关/占用状态均同时陈列。

入口：[Start-Camp-Expansion-V2-Preview.cmd](../../Start-Camp-Expansion-V2-Preview.cmd)。截图 overview.png 属本轮临时验收媒体，待用户确认后按项目规则清理。

## 本轮验证

真实窗口72项、0失败，详见 preview.json：26种齐全、27种可见、原建筑状态校验、四新设施底座与E交互、床席睡眠/醒来、V列表、实际玩家JSON/tmp哈希不变。首轮发现清景误隐藏同样带prop_id的建筑，已将清景限定为scenery_prop，并增加逐个可见断言；修复后截图人工核对27种均显示。

五张最终单图 strict QC 通过。原始四图等分裁切时燃料箱区域混入下行烟囱，source-cell-edge失败，未采用；改在空白间隙y470划分所有权并无损补边后处理。完整提示词、源图、SHA、处理和QA：[provenance.json](../../art/camp-expansion-front-v2/provenance.json)。美术主观确认仍待用户。

未重跑上轮四设施完整功能210项、全量回归、多分辨率、长期平衡和大营地性能。此次不改变配方、功能、存档格式或正式玩家档。

## 文件

- scripts/camp_expansion_preview.gd：全种类有名称的对比陈列与独立清景。
- scripts/camp_building.gd、data/camp_volume_v2.json：仅候选的冰箱图片覆盖。
- data/camp_buildings.json、data/items.json：四新设施候选路径更新。
- prototypes/camp-expansion-front-v2/final/：五张候选PNG。
- art/camp-expansion-front-v2/：生成原图、提示词、处理、来源与QA记录。
- tests/test_camp_expansion_front_v2.gd：本轮定向验证。
- PROJECT_STATUS.md、CAMP_EXPANSION_V2.md、DEVLOG.md、本报告：当前状态记录。

无正式素材批准，无提交推送，无NPC开发。完成后停止等待本批验收。
