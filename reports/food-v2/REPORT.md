# 食物与烹饪扩展 V2 · 本轮报告

2026-10-19，Godot 4.7.2 stable ed1daf0bf。仅本地修改，不提交/推送。

## 实现

- 原三作物总周期改为2/4/6游戏日，三静态阶段、自然累计、留种/残根流程保持。新增可选planting_cycle_version=2，旧周期按比例换算一次，已成熟旧作物保持成熟。未知/非整数版本保护源档。
- 四道新料理进入原篝火食谱/自由搭配/发现/领取流程；烤土豆12/12秒、烤卷心菜16/15秒、汤24/20秒、炖杂蔬36/30秒。两道简单烤菜初始已知，汤与炖菜完成后发现。未新增设备。
- 香草蘑菇改为正式broad_leaf×2+brown_mushroom×1；旧已付料任务保持ID、产物、时长，不追补材料。恢复单蘑菇烤制正常入口。正式16种食物逐项实际食用，见FOOD_AUDIT.md；未指定调整的拼盘36/40与土豆5/卷心菜6保留。
- 野生蘑菇复用原ID、正式PNG及原自然分布，仅切换地面pickup交互；布局、资源身份和已取记录保持。真实自然候选经过WorldInteraction.execute距离/遮挡路径拾取入包并保存。
- 生蘑菇立即+2饥饿，独立60分钟状态；匀速每分钟1/3生命损失，总20。重复生吃刷新一个计时器，不叠速；熟食不解毒。期间普通营养回血暂停，原低生命照料保持，照料时净生命变化可能抵消伤害。正常睡眠继续推进，暂停/离线不推进。
- 世界扭曲与半透明轻重影加入既有世界环境Shader，无输入限制；HUD/文字/背包在更高CanvasLayer。强度、淡入退出秒数、时长及伤害可配置。body.version2保留，可选剩余时长字段兼容旧档并校验有限范围。

## 验证与证据

只用同Seed隔离fixture，正式玩家身份/存档未读写；实际窗口读取project.godot默认1280×720。

| 专项 | 结果 | 证据 |
|---|---|---|
| 逻辑、食用、配方、自然拾取、作物阶段 | 165项，0失败 | headless.json |
| 原生默认窗口功能部分 | 同一165项通过 | window.json |
| 独立新进程恢复与领取防重复 | 9项，0失败 | restart.json |
| 睡眠真实推进、回滚、满包、成熟不枯萎、非法版本 | 9项，0失败 | edges.json |
| GPU世界变化、面板文字逐像素不变、淡入淡出 | 6项，0失败 | visual.json |

窗口完整控制器曾报告167项中的1项失败：GPU面板比对包含顶部透明边缘透出的世界。像素差仅在y65–70的854像素，面板内部差异为0。修正为不含透明边缘的内容区后，独立visual专项6项全部通过；旧失败日志和窗口JSON如实保留，未将其改写为167项全过。首次重启失败定位为新迁移版本的JSON浮点整数兼容，已修复后独立9项通过。初次只搜索出生点附近未找到蘑菇，改为现有生态核心邻区自然候选，未注入伪造资源。

GPU截图暂存在本目录hallucination-book.png/normal-book.png供本轮查看，确认后按AGENTS规则清理；文字及指标保留。没有测试多分辨率、全量回归、长期人工饮食平衡、大量耕地/大营地性能。没有新增动物或其他系统。

## 待确认美术

四张128×128透明图：prototypes/food-v2/final；对照预览prototypes/food-v2/preview.png，顺序为烤土豆、烤卷心菜、蔬菜汤、炖杂蔬。正式暂复用已有食材图标，不引用候选，不覆盖正式素材。pending_user，不扩大授权。

流程generate2dsprite → route_media → Codex(local CLI)，route=local:codex-cli，工具返回model=codex-image_gen，estimateUsd=0.0（本地订阅路由；不表示已核实实际计费）。源图、提示词、job、SHA与来源清单保留在art/food-v2和final/provenance.json。原图实际1254×1254，2×2整数分格，无跨格主体、无源图边界接触，完整所有权裁片；软抠、保留全部部件、128像素归一化。

原图QA警告（不隐瞒或改称全美术无警告）：
- boundary_band：value=118，threshold=0，art/food-v2/spill/sheet-qc.json；13px格线邻域存在主体像素。
- safe_frame：value=4，threshold=0，同文件；4格未满足15%空白框。

处理后pipeline-meta.json结构QA为pass，已查看原图及最终实际尺寸预览。未修剪主体来掩盖原图留白偏差，主观美术待用户确认。doctor另记录python.path、encoding.stdout、encoding.files、paths.cwd环境WARN；无API密钥及可选resvg/Grok能力缺失不阻塞本地Codex图像路线。实际运行采用UTF-8并保留完整路径。
