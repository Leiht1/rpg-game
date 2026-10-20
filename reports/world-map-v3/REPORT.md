# 世界与地图 V3 · 交付与验收报告

2026-10-20 · Godot 4.7.2 stable · Compatibility / OpenGL 3.3 · NVIDIA GeForce RTX 5060 · 项目默认1280×720。

## 交付与边界

完整可游玩的隔离版本已实现，具有真实世界移动、1536格大陆、世界永久探索、地图缩放拖动、回到人物、退出保存与重进恢复。独立入口为项目根目录 **Start-World-Map-V3-Preview.cmd**，可同步脚本为 **tools/Start-World-Map-V3-Preview.ps1**。本轮没有提交、推送或发布。

普通入口接入新建尺寸、世界探索、交互与缓存；新手绘配色/纹理/地貌图案仅在独立V3试玩启用，等本批审美确认。没有覆盖或替换任何正式PNG，没有批准未来素材。人物外观候选仍维持之前的独立审批状态，本轮地图试玩使用正式角色。

最终定向断言 **174项，0失败**；另有两次新旧世界原生窗口性能测量。受保护的15份既有玩家JSON/tmp前后SHA256完全一致，只新增独立 `world-map-v3-preview/state.json`。断言通过不代表退出日志无诊断，见后文限制。

## 1. 世界规模与生成

- 原1024格、48单位/格为49152边长；新建1536格为73728边长。矩形面积2.25倍，实际陆地没有声称精确2.25倍。区块24格/1152单位保持，世界由约43×43区块范围扩大到64×64，仍只流式加载附近区块。
- 旧尺寸不改随机流、节点数量、湖泊、海岸、资源或地貌。3 Seed各100×100实际采样的地形/海岸一致，湖泊与出生锚点一致，抽查物件一致。比较基准为本轮开始时冻结的正式生成器 `prototypes/world-map-v3/baseline_generator.gd`；它只服务验证。
- 新尺寸的连续房间数量由12–18改为18–24，湖泊尝试目标由3–5改为5–7；仍先生成连通图、再房间海岸并集、生态和水系，不采用扇形三分区、不单纯拉伸原噪声。实际三Seed为18/23/18房间、各6湖及4–6条原算法连续支流。
- 真实生态仍是原草原、森林、泥地及岩石区，没有新生态类型。三Seed160×160抽样陆地占世界矩形约18.52%、20.45%、15.90%，大面积海洋是原不规则大陆构造的结果，并非新增矩形陆地。
- 实际出生沿 `choose_entry_point` 的干燥、岸距、树根/景物/建筑净空筛选；地形旧锚点不改。正常窗口已真实物理步行约563世界单位，没有向正式世界注入测试物品。

## 2. 旧世界与身份

世界保存Seed、自身尺寸、`world_id` 和 `world_generation`（生成器/布局修订/格单位）。正式旧身份缺尺寸时仍兼容1024；缺ID时使用原生成器+Seed+尺寸的稳定兼容ID，新世界独立生成ID。人物创建沿用已有世界ID；1024和1536的JSON数字都可恢复，创建新世界才用1536。

身份文件改为临时文件写完后原子替换；失败不切新世界，原身份保留。非法尺寸、非整数、未知生成配置不被静默夹成另一个世界。原V0.6与原物品存档路径/根版本保持；非常早期biome身份的历史迁移入口保持旧尺寸上限，不因本轮扩容放大。

新旧尺寸都进行了独立进程恢复测试，真实预览入口另做了创建与重进。损坏探索会保护整个原快照，不以空记录覆盖源文件。没有擅自恢复旧版本从未记录的历史路线。

## 3. 资源适配

| 项目 | 旧世界 | 新1536世界 |
|---|---|---|
| 普通资源/树木/矿点 | 原世界单位网格与生态权重 | 原密度、候选间距和规则保持 |
| 废弃营地 | 最多3组 | 最多5组；仍成组、有限尝试、旧档不追加 |
| 全图活动鱼群 | 上限20 | 上限28 |
| 每湖/每群/补充 | 每湖0–3群、每群6条、耗尽后2–3日随机换位 | 全部保持；湖岸最大候选搜索距离适配较大湖泊 |
| 商人 | 全图唯一 | 仍唯一；完整73728范围均匀候选，再检查可达性 |
| 动物 | 原有限数量与周期 | 不变，没有按面积倍增 |

三Seed×两种尺寸，分散抽样每组32个干燥陆地区块，资源均非空。下表为抽样而非全世界资源总量；生态构成不同，不能把样本差值解释成修改了单位密度。商人每组抽24次合法候选，覆盖3–4个世界象限，未改为玩家附近选点。

| 格数 | Seed | 有资源区块 | 自然拾取 | 采矿/挖掘点 | 树 | 营地组 | 鱼群 | 商人覆盖象限 |
|---|---|---|---|---|---|---|---|---|
| 1024 | 81273 | 32/32 | 198 | 78 | 128 | 3 | 20 | 4 |
| 1024 | 271828 | 32/32 | 144 | 105 | 127 | 3 | 20 | 4 |
| 1024 | 902106 | 32/32 | 186 | 127 | 148 | 3 | 20 | 4 |
| 1536 | 81273 | 32/32 | 165 | 76 | 105 | 5 | 28 | 4 |
| 1536 | 271828 | 32/32 | 158 | 134 | 105 | 5 | 28 | 4 |
| 1536 | 902106 | 32/32 | 126 | 122 | 86 | 5 | 28 | 3 |

## 4. 永久探索与共享数据

世界根快照新增同级 `world_id/world_generation/world_exploration`。探索字段包含版本、世界ID、范围、统一网格、位图宽度、Base64位集和SHA256；不放进角色的专用地图字段。同一世界多份记录可做OR并集；重复贡献不增大记录、玩家离开不撤销贡献。

探索网格96单位、半径1152单位，以真实玩家位置更新；地图、拖拽、缩放和后台区块生成均不触发探索。传送只揭开合法落点，不填两点之间的假路线。保存时补齐当前位置圆形范围，避免移动节流使重启后边缘轻微增加。新世界大部分未知，旧档缺记录仅初始化当前合法位置。

1536世界位集固定72KiB，显示用768×768单通道纹理。合并、反复探索和存档不使用海量JSON单格对象。位图校验先于世界/库存状态落入内存；失败不全图解锁，不覆盖原快照。探索修订会沿原15秒脏快照或退出保存；写失败保留原文件与尚未落盘的探索。

`merge_local` 是离线工具接口，**没有网络提交权威**。未来服务器须自行验证玩家真实探索，不可把可自行计算SHA的客户端位图当作探索授权。本轮不实现网络、房主、服务器或多玩家状态分发。

2500个模拟合法落点的探索更新耗时138.49ms，序列化1.37ms，含校验/显示掩码重建的恢复29.85ms，JSON 98480字节。重复100次并集后长度保持不变。此为合成世界数据测量，并非100个并发玩家实测。

## 5. 地图表现与操作

每次M打开回到人物，初次局部8倍；滚轮连续1–32倍、鼠标锚定缩放、左键拖拽、回到人物按钮、M/Esc关闭。地图在边缘夹紧视口，人物不强制居中；滚轮不会操作世界相机，拖动后不会自动跳回。路标读取原建筑实例，未知区不显示路标或文字，已知区保持命名、拆除及原存档规则；不显示出生地或商人导航。

静态地形直接读取实际世界生态/海岸/水域，候选增加柔和低频明暗、稀疏树冠、岩脊与水纹，没有绘制不存在的地貌。动态标记独立，迷雾盖在全部地理装饰之上，像素对比验证未知区域更换底层地形后画面不变。迷雾只作用地图，正常世界不遮黑。

地形为64像素分块缓存、4档采样精度（最大虚拟索引4096，不是4096整图纹理）、单块66×66含边框、最多192块LRU。按已探索可见区请求，隐藏地图不建图；每帧在行边界检查1.8ms预算，单行可能轻微超时。最细缓存原RGB数据理论约2.4MiB，驱动对齐、节点和全游戏资源另计。首次冷缓存渐进绘制，重复打开不重新全量生成。

## 6. 实际游戏截图与对照

下列全部来自Godot原生1280×720窗口，诊断Seed81273；**旧图是同一实际地貌、同一新版视口中的原 overview_color 渲染，不能当成旧UI全屏截图**。诊断局部揭雾只在测试夹具内，未写入真正试玩世界；真实试玩初次使用随机Seed，位置可能不同。

| 内容 | 原地形绘制 | V3候选 |
|---|---|---|
| 草原/森林 | [原图](old-grass-forest.png) | [候选](v3-grass-forest.png) |
| 森林/岩石区 | [原图](old-forest-rock.png) | [候选](v3-forest-rock.png) |
| 湖泊与湖岸 | [原图](old-lake.png) | [候选](v3-lake.png) |
| 大陆海岸 | [原图](old-coast.png) | [候选](v3-coast.png) |

[真实可移动世界](00-playable-world.png) · [初始已探索/未知边缘](01-initial-fog.png) · 同一湖泊的[缩小4倍](v3-lake-zoom-4.png)、[默认8倍](v3-lake.png)、[放大16倍](v3-lake-zoom-16.png)。4倍截图露出的成片边缘来自诊断脚本为审美对照揭开的局部范围，不代表玩家普通移动的圆形边缘。

![草原与森林的V3实际渲染](v3-grass-forest.png)

所有12张PNG尺寸、可解码性与SHA在 [rendered-qa.json](rendered-qa.json)，本轮确认前保留。它们不是美术生成输入或长期批准参考；用户确认后按约定清理临时媒体，文字指标保留。

## 7. 性能实测

同硬件、相同Seed81273、独立进程、默认1280×720、60FPS上限。启动包括生成/导航/资源和首批区块；帧时间用真实帧间墙钟，普通行走180帧、地图缩放平移180帧。两个尺寸均使用本轮V3渲染器以隔离世界规模影响，**不是旧版渲染器性能基准**。

| 指标 | 1024格 | 1536格 |
|---|---|---|
| 世界进入可操作（ms） | 6910.28 | 9400.36 |
| 世界就绪静态内存（MiB） | 118.35 | 120.04 |
| 世界普通行走帧 P95（ms） | 16.78 | 16.86 |
| 地图首次响应（ms） | 21.56 | 16.13 |
| 局部已探索地形冷缓存完成（ms） | 2194.84 | 2149.93 |
| 缩放/平移帧 P95（ms） | 23.01 | 16.72 |
| 缩放/平移最大帧（ms） | 24.30 | 16.98 |
| 最终总显存（MiB） | 115.33 | 111.86 |

首帧地图打开和冷缓存完全完成是不同指标：界面立即响应，地形约2.1秒渐进填齐；这段时间显示绘制状态，不能称为首次开图所有地形瞬时出现。已有缓存重开不重建。174项中的窗口压力段另跑240帧多档缩放/远处平移/反复开关，P95约16.77ms、最大17.06ms，缓存保持上限内，静态内存增量约0.10MiB。

三Seed纯地貌生成，新世界约2.68–3.44秒、旧世界约1.88–2.55秒（见logic.json，单次测量）。不是长期基准，未用这些数字承诺所有Seed或硬件表现。

## 8. 定向验证清单

| 测试 | 断言 | 失败 | 证据 |
|---|---|---|---|
| 三Seed生成、旧算法等价与位集合并 | 35 | 0 | [logic.json](logic.json) |
| 六组新旧世界资源/商人/营地/重载 | 54 | 0 | [distribution.json](distribution.json) |
| 身份原子保存、损坏保护、创建兼容、大探索记录 | 17 | 0 | [storage.json](storage.json) |
| 原生窗口输入、正常步行、迷雾GPU遮挡与缓存 | 29 | 0 | [window.json](window.json) |
| 新世界独立进程重启 | 9 | 0 | [resume.json](resume.json) |
| 旧尺寸世界独立进程重启 | 9 | 0 | [resume-old.json](resume-old.json) |
| 路标、音效与共享并集脏状态 | 10 | 0 | [markers.json](markers.json) |
| 真实独立试玩入口与保存 | 4 | 0 | [preview-create.json](preview-create.json) |
| 真实独立试玩入口重进 | 7 | 0 | [preview-resume.json](preview-resume.json) |

原先已有的未提交工作完整保留，未扫描/重写无关美术。15个既有JSON/tmp完整性见 [player-integrity.json](player-integrity.json)，总览见 [summary.json](summary.json)。测试世界快照在reports专用文件或独立预览目录，不读取/修改正式玩家世界状态。

## 9. 来源、哈希与QA

`art_source=code`；按任务明确允许的程序化手绘纹理，用Godot原生采样/绘制。**code-drawn, no image model**。没有新增运行PNG、没有调用图像模型或外部素材。复用原纸布UI与正式角色/场景，不声明任何未经确认的素材已批准。

代码/规范参考SHA、候选开关与QA状态登记 [provenance.json](../../prototypes/world-map-v3/provenance.json)。QA状态为 `needs-user-visual-review`；结构验证不替代审美确认。地图技能的环境自检为WARN，不是全绿；其缺失媒体依赖不参与本轮Godot原生绘制，没有自动安装依赖或走未记录图像路由。

## 10. 修改与新增文件

- 世界尺寸/身份/参数：scripts/world.gd、world_generator.gd、world_generator_base.gd。
- 世界共享探索与原子快照：scripts/world_exploration.gd、item_service.gd。
- 地图缓存/绘制/迷雾/输入：scripts/world_map.gd、map_cartography.gd、map_fog.gdshader。
- 资源适配：scripts/abandoned_camps.gd、fishing_population.gd、fishing_spots.gd。
- 创建与隔离：scripts/character_creation.gd、environment_view.gd、world_map_v3_preview.gd；scenes/world_map_v3_preview.tscn。
- 入口：Start-World-Map-V3-Preview.cmd（按已有规则仅本地）、tools/Start-World-Map-V3-Preview.ps1。
- 验证：tests/world_map_v3_fixture.gd、test_world_map_v3_logic.gd、test_world_map_v3_storage.gd、test_world_map_v3_distribution.gd、test_world_map_v3_window.gd、test_world_map_v3_markers.gd、test_world_map_v3_perf.gd、test_world_map_v3_preview.gd。
- 基线/来源：prototypes/world-map-v3/baseline_generator.gd、provenance.json；reports/world-map-v3中的报告、测量、SHA和临时截图。
- 必要规范：WORLD_MAP_V3.md、MAP_SYSTEM.md、FISHING_SYSTEM.md、ABANDONED_CAMP_SYSTEM.md、CHARACTER_CREATION_SYSTEM.md、PROJECT_STATUS.md、DEVLOG.md、.gitignore。

## 11. 尚未完成与重点人工验收

- 地图新画风尚待用户确认：请看森林图案密度、岩脊是否过于符号化、湖岸/海岸层次、迷雾边缘及常用缩放清晰度。没有把本轮代码授权写成正式美术批准。
- 没有做数小时探索、大营地FPS、全部整数Seed、像素级全岸线可达性、全世界资源穷举、低配硬件或多分辨率测试。三Seed采样/连通导航与正常窗口步行不能代替这些结论。
- 已在真实入口创建可继续游玩的独立世界并恢复；保存包含正常时间流速，不保留测试用暂停。未赠送测试物品。
- 退出诊断仍存在：完整窗口夹具144个ObjectDB实例、性能/标记夹具104、独立重启44，均出现2资源仍占用；真实预览创建/恢复分别84/52。历史项目也记录退出资源诊断，但本轮没有证明每一条均与旧问题相同，未扩展到无关生命周期重构。不能宣称全日志零错误。
- 单帧1.8ms建图是行间预算，本轮窗口观测最大约3.40ms；帧数据见对应JSON。首次冷图仍需要渐进完成。
- 共享并集仅验证数据结构与本地保存，不是真联机。未来服务器验证、冲突提交、多人物世界拆分和网络合并仍待后续独立任务。

## 附：媒体工具环境自检原始警告/缺失

来源 [doctor.json](doctor.json)。以下原样保留ID、状态和detail；这些检查无数值阈值，不属于地图玩法断言。

| ID | 状态 | 原始detail |
|---|---|---|
| python.path | WARN | other python.exe on PATH: ~/AppData/Local/Microsoft/WindowsApps/python.exe |
| deps.scipy | WARN | not installed; needed for faster labelling and keying (forge_core falls back to numpy) |
| deps.resvg-py | MISSING | not installed; needed for codeart2d SVG rendering (PixelSpec needs only numpy and Pillow) |
| encoding.stdout | WARN | stdout=gbk: non-ASCII text can be garbled in pipes |
| encoding.files | WARN | open() and read_text() without encoding= use cp936 |
| paths.cwd | WARN | the working folder has spaces or non-ASCII characters |
| ffmpeg | MISSING | ffmpeg is not on PATH; video decode and encode are unavailable (PNG-frame input still works) |
| media.api.openai | MISSING | OPENAI_API_KEY is not configured |
| media.api.gemini | MISSING | GOOGLE_API_KEY or GEMINI_API_KEY is not configured |
| media.api.xai | MISSING | XAI_API_KEY is not configured |
| media.api.byteplus | MISSING | ARK_API_KEY is not configured |
| media.api.fal | MISSING | FAL_KEY is not configured |
| cli.grok | MISSING | Grok Build CLI not found on PATH or in $GROK_HOME/bin |
