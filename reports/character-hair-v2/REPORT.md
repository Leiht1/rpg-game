# 黑发、裁切、前刺与下拉修订 V2

2026-10-20。本轮仅处理用户反馈的下拉黑底、侧后脑多余轮廓、转向闪动、黑发、发型裁切和前刺替换；不扩展角色功能或正式推广。

## 修订结果

- 共用 `item_ui_style.gd` 现在同时给 PopupMenu 的面板、悬停和文字配置统一纸布样式，不再只给 OptionButton 外壳换皮。性别/发型两个独立弹层显式使用同一主题，另一个普通 OptionButton 的自动继承也已验证。
- 24个方向图全部重做为自然黑发，保留克制灰色明暗。男性第三种名称改为「美式前刺」，造型换为明显不同的短乱前刺；旧 `male_parted` ID保持，已有试玩人物不用重新创建。
- V1按固定水平线分拆头发，侧底头又有一条耳下连到下颌的分割线，造成多余分块和硬截痕。当前用完整发型及图中真实脸部开口，不硬切前后片，旧后层隐藏并清空；侧底头重画去掉该连线。
- 创建预览关闭物理插值，换向姿态设置完成后清除插值历史。世界人物的物理插值、骨骼/关节、原动画、碰撞与持握不改。
- 新侧底头的睡眠闭眼锚点改为从catalog读取与实际新图对应的UV，避免继承旧头图位置。

## 实际 Godot 预览

默认1280×720原生窗口，GPU实际渲染，完整预览见 [index.html](index.html)。

- [发型纸布弹层](hair-paper-menu.png)、[性别纸布弹层](gender-paper-menu.png)
- [男性四发型正/背/侧](male-hair-gallery.png)
- [女性四发型正/背/侧](female-hair-gallery.png)
- [美式前刺创建侧视](spiky-crop-creation.png)、[实际世界](world-spiky-crop.png)
- [黑发与六肤色/换装](skin-outfit-gallery.png)、[四向原生动作采样](four-way-actions.png)

从原 `Start-Character-Creation-Preview.cmd` 启动。已经运行的旧进程不会热加载新图，需正常关闭再重开。原试玩档继续恢复原世界/人物，不重置或补发服装。

## 最小定向验证

| 范围 | 检查 | 失败 | 证据 |
|---|---:|---:|---|
| 默认窗口真实点击下拉、纸布样式继承、全部发型四向首帧稳定性、完整轮廓/镜像、无创建副作用 |154|0|[runtime-checks.json](runtime-checks.json)|
| 隔离复制上轮验收快照：旧ID/Seed/位置、世界/背包渲染、装备卸下、六肤色睡眠侧头/新闭眼锚点、原子保存兼容 |35|0|[world-checks.json](world-checks.json)|
| 24张发型的源边界空白、最终画布完整性、黑色中性色检查 |72|0|[registration-qa.json](../../art/character-hair-v2/registration-qa.json)|

转向覆盖男女8发型×正背左右共32组合：每次换向第一张实际绘制画面与后续5帧比对，共160组GPU逐像素比对，差异0；人物根位置不变。创建预览的稳定性检查没有修改世界角色插值。

自动UI专项前后正式user根JSON及已有用户试玩档SHA一致；世界验收只使用本报告目录快照，没有往玩家或用户试玩档投放工具、衣服或修改外观。世界图中的工具来自上轮自动验收快照，不是新给用户发放的物品。

UI专项及图库进程无运行错误。世界专项退出仍有60个ObjectDB实例与2资源占用诊断，已保留本地日志，未附带生命周期重构。未重跑上一轮249项全清单、全设施睡眠逻辑、多分辨率、长期人工或性能回归；上一轮历史通过数没有累计成本轮结论。

## 素材与来源

- 新候选 [prototypes/character-hair-v2](../../prototypes/character-hair-v2)：24完整发型+1侧底头，共25PNG；旧V1 PNG保留。运行入口仍是原 [catalog.json](../../prototypes/character-creation-v1/catalog.json)，仅新发型/侧底头引用和眼睛锚点更新，服装和原前/背底头不改。
- [provenance.json](../../art/character-hair-v2/provenance.json)记录原图/参考/候选SHA、实际4次生成回执和兼容范围；[registration.json](../../art/character-hair-v2/registration.json)记录所有源框、透明边界、等比缩放、粘贴位置和共用头部原点。
- 实际流程：generate2dsprite → route_media → **Codex（本地CLI）**。模型回执 `codex-image_gen`，精确修订和订阅额度折算费用未知。提示词、原始生成图、用户两张问题截图、首稿/前刺修订及处理元数据完整保留。
- male-keyed、female-keyed、crop-keyed、side-head-keyed四套结构QA均pass，没有WARN/FAIL。不同造型的动作体型波动指标标记skipped，不能把它们算作额外通过。
- 没有用一张头发拉伸冒充各造型，裁切均取真实独立视图并等比注册；72项注册检查全部通过。主观轮廓、前刺风格和肩颈遮挡仍需本批试玩审核，数值不能代替视觉确认。

## 文件范围

修改：`scripts/item_ui_style.gd`、`scripts/character_creation.gd`、`scripts/character_look.gd`、`scripts/sleep_head_cover.gd`、原候选catalog，以及相关规范/状态/日志和忽略规则。

新增：`art/character-hair-v2/`、`prototypes/character-hair-v2/`、本报告目录、`tests/test_character_hair_v2.gd`、`tests/test_character_hair_world_v2.gd`、`tests/test_character_gallery_v2.gd`。

正式人物PNG、服装素材、角色场景、动作资源、物品/商人数据、存档格式均未修改。新美术仍pending_user；未提交、未推送。当前临时预览媒体留到用户确认本轮效果。
