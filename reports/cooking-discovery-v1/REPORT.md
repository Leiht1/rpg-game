# 四料理、自由搭配与探索发现 V1 · 交付报告

2026-10-17，Godot 4.7.2 Stable / Windows / OpenGL Compatibility。正式入口仍为根目录 Start-Playtest.cmd，靠近篝火按 E。本轮完成后停止，不进入种植、养殖、动物或新设施。

## 实际交付

- data/campfire_rules.json：4条有效料理，共用可食用野花wildflower。烤胡萝卜1→12饥饿/12秒；棕蘑菇2+野花1→香草烤蘑菇16/10秒；浆果2+苹果1+野花1→野果混合烤盘20/16秒；胡萝卜1+蘑菇1+浆果1+野花1→原野丰收烤盘24/20秒。前两条已掌握，后两条真正完成后发现。
- data/items.json：新增herb_roasted_mushroom、roasted_fruit_platter、field_harvest_platter。沿用叠30、原eat/Tooltip/右键/快捷栏/地面掉落/库存规则。按用户明确回复，全eat食物只保留hunger；原野食饥饿值不变，烤胡萝卜保持12并去除health2。
- scripts/campfire_service.gd：原服务内精确匹配、全局发现、同一任务流程。材料顺序无关，数量须完全一致，不接收额外种类/数量；无效组合不扣料、不计时、不发物品。开始/领取在原库存副本结算，持久化失败回滚；busy和现有单任务防重复。完成才登记发现，与ready一起保存原快照。
- scripts/campfire_ui.gd：固定1030×600纸布面板增加食谱册/自由搭配。左列6卡位（4料理+2未来占位）或主料+3搭配槽。选择器统计原40格背包/快捷栏，可替换/移除/编辑数量，重复种类禁用；没有第二库存。未知食谱在详情/卡片/烹饪任务中均隐藏真实成品信息。已知组合显示真实图、材料、时间及饥饿；未发现有效组合仅提示可做新料理。完成揭晓，满包保留待领。
- scripts/item_service.gd：加载原campfires内发现记录，旧档缺字段默认空，已ready任务兼容补记；其他库存/世界/装备状态加载契约保持。
- assets/cooking/v1：3张经用户明确“可以，采用这三张图标”确认后正式推广的独立透明图。原烤胡萝卜/旧烤蘑菇图不覆盖。来源art/cooking-discovery-v1，候选副本prototypes/cooking-discovery-v1。生成/整理工具tools/package_cooking_discovery_v1.py，哈希与完整裁片在provenance.json。
- tests/test_cooking_discovery_v1.gd：专项、原生数量输入、UI信号操作、三尺寸渲染及独立进程重启检查。
- 同步AGENTS.md、CAMPFIRE_SYSTEM.md、ITEM_SYSTEM.md、CRAFTING_SYSTEM.md、NATURAL_RESOURCE_ECOLOGY.md、ART_STYLE.md、UI_ART.md、BODY_SYSTEM.md、DEVLOG.md。

## 差异与兼容决策

原需求“复用旧烤蘑菇ID并保持已有食用效果”与“新香草烤蘑菇建议16”存在冲突；用户明确选择保留旧ID/+10并新增独立香草料理/+16。旧roasted_mushroom在背包、快捷栏、地面和旧存档中仍有效，不删除、不转换、不补发。原roast_mushroom配置标记legacy_only，仅供已经扣过材料的旧任务按原10秒完成并领取旧物品；不再显示、不能新启动、不参与自由匹配。因此有效可制作料理恰为4，兼容历史物品不计作第5种开放料理。

原正式烤胡萝卜曾有health2，与“所有食物只加饥饿”冲突；用户明确选择去除该生命收益，保留饥饿12。其他eat食物也只保留原hunger，身体速率、自然恢复、疾病、体型机制不改。

现有可食用野花满足草本需求，所以未新增野香草、未修改自然资源配置或生成版本，未重排资源、地图或Seed。

保存仍原items文件、外层version1、campfires.version1。新增campfires.discovery_version1和discovered映射，缺失字段按旧档兼容；未来版本、未知发现ID和非法类型拒绝加载并保护源文件。发现不在点击开始/切换/关闭时写入，完成保存ready和发现；未领取只存在原任务中，重复领取不能重复发放。完成保存失败时保持dirty并沿用原保存重试，未承诺强制断电零进度损失。

## 实际执行的验证

| 项目 | 结果 | 证据 |
|---|---|---|
| Godot4.7.2资源导入/脚本检查 | 完成，无脚本解析错误 | ../cooking-discovery-import.log及实际运行日志 |
| 无头专项 | 87项，0失败 | tests.json、../cooking-discovery-final.log |
| 真实Godot窗口同一专项 | 87项，0失败 | window-tests.json、../cooking-discovery-window-final.log |
| 独立进程重启读取/领取 | 7项，0失败 | restart-tests.json、../cooking-discovery-restart.log |
| 1280×720、960×540、1600×900，两模式 | 实际渲染、截图检查；主框固定、左右列无重叠 | book-1280/960/1600.png、free-1280/960/1600.png |

覆盖真实物品引用、收益、顺序无关/精确数量、旧配方禁止、新旧食物、开始不发现/完成才发现、熄灭暂停/关闭继续、无效或缺料无扣除、保存失败开始/领取回滚、满包保留/不发获得事件、重复操作、独立进程恢复、旧缺字段存档、未知版本源档保护。UI覆盖真实OptionButton选择/移除信号、重复种类禁用、自由模式按钮开始与领取、关闭重开、聚焦LineEdit原生数字输入。

窗口运行使用真实Godot渲染；选择/提交等流程由专项驱动原生控件信号和回调，数量输入使用Viewport原生事件。没有声称人工鼠标逐项试玩或完整桌面拖拽验收。测试使用同一正式world脚本的固定Seed隔离夹具及专用user://cooking-discovery-v1-test.json，不写用户正式世界/背包存档。

## 检查中发现并修正

1. JSON数值为浮点，Dictionary整体比较不能代替材料数量逐项比较；改为键集合+精确整数数量匹配。
2. 空材料槽不能调用原count_item(空ID)，已跳过并显示不可编辑0。
3. 下拉框默认按最长项扩宽导致左右列重叠；限制宽度并在三尺寸实际复核。
4. 原面板吞下数字键，新增数量编辑时透传到LineEdit；聚焦测试须等待原生SpinBox焦点状态稳定。
5. 初始满包夹具只填32个索引，未覆盖原真实背包8–39，修正为40格全占后验证。旧失败/诊断日志保留，不列为通过结果。

## 美术来源与QA边界

受控generate2dsprite → route_media → local:codex-cli / host_image。source原图1536×1024，source SHA256 3329771bf08ba3d9da1a31632f837b24f77bc85cec318a64393fe7d5e273bd78。模型回执codex-image_gen，底层精确图片模型未公开；estimateUsd=0是订阅路线估价，实际费用未知。附上原熟食与野花图标参考，参考哈希、提示词、真实回执、所有权矩形均留存。

原图生成未严格遵守15%边距和等分三列；以下警告完整保留：

> WARN source_grid_alignment: right platter crosses nominal x=1024 boundary; measured ownership boundaries 510/997 preserve all subjects. Source margins below requested 15%; output padded to at least 16px.

具体原图为art/cooking-discovery-v1/candidate-01/generated.png，名义分界1024，实际所有权分界997；使用0/510/997/1536完整归属裁片，不切掉相邻主体、不用最大连通块删除细节。整理后均256透明画布、至少16px安全边，真实48pxUI查看，三图SHA256见assets/cooking/v1/provenance.json。用户已看过原候选并明确同意采用，数值QA不冒充主观批准。

能力检查doctor.json还记录python.path（PATH指向WindowsApps）、deps.scipy未安装、encoding.stdout=gbk、encoding.files=cp936、paths.cwd含非ASCII五项WARN；实际使用明确的bundled Python、UTF-8文件及带引号路径。没有为本轮安装依赖。视频/代码绘图相关resvg/ffmpeg以及未配置API钥匙不影响本轮PNG路线；未声称环境所有能力可用。

## 未验证与停止范围

未运行无关全量回归、全Seed穷举或FPS压力测试，未测异常断电。未开发种植、养殖、随机品质、失败概率、其他属性增益、动物或后续食谱。美术已获本批批准，交互手感及长期试玩反馈留待用户。任务至此完成停止。
