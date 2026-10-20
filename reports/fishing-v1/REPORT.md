# 钓鱼 V1 独立候选预览交付

2026-10-20。状态 pending_user；本轮只完成候选试玩实现，不是正式验收或美术批准。远端已快进同步至 365111e，未提交/推送本轮修改。

## 试玩后修订

按用户反馈：安全区从 26% 收窄至 21%，首次及每次判定后均随机换位置，限定中心范围并避免与上一轮太近；不同预览启动随机化，不再按固定世界种子重复两个位置。鱼群选点检查完整 120×48 水面包络并搜索局部深度/切向偏移，最大交互距离仍保留；运行时波纹分段检查真实水面，不跨越凹岸/浅水拒绝区。鱼影单层透明度由 .032 加深至 .080，保持模糊与低速游动。

独立战利品随机源：普通鱼98.5%、金币1%、密码锁宝箱0.5%。每次开始抽定，成功才发一件，失败/取消/满包不给；彩蛋替代本次鱼，不额外发鱼。出水表现、库存图标与原获得提示使用实际钓获图。金币描述“闪闪发光，看起来很值钱。”，宝箱描述“带着密码锁的宝箱。”，没有兑换/解锁/打开/密码用途或正式物品配置。新两图仅在候选目录，来源增补 art/fishing-v2/provenance.json。

新增候选 PNG/RES：coin、locked_chest；新增来源目录 art/fishing-v2（生成原图、提示词、回执、拆分、处理、QC、发布脚本）。其余直接修改 preview_world.gd、fishing_preview.gd、timing_bar.gd、export_textures.gd、定向测试与必要文档。入口显式指定 --scene，预览延迟初始化并限定60fps，避免独立加载阶段无上限竞争；正式项目窗口与入口配置不变。

## 三阶段实现

- A：隔离世界真实湖泊西岸布置三个可步行抵达的鱼群资源点；局部低对比椭圆涟漪、暗淡模糊鱼影、错峰偶发小鱼跳跃及小水花。沿用当前地形/水面，无地图新图或全湖噪声。
- B：现有鱼竿开局装备，只有近岸、距离/可达/装备检查通过才接受 E。自动左右侧视，原角色 native side_breathe 部件插值完成后仰、前送、持竿与提竿；没有生成其他视角或替换正式人物。抛完直接在水面目标放浮漂，简洁运行时线连接已登记杆头；浮漂轻微起伏与落点水花。
- C：等待后浮漂消失、明显感叹号，随后纸布横条小游戏。Space 判定，2 命中成功/3 失误或超时失败，命中后安全区轻移、防连击。成功提竿、鱼出水、水花，然后向原库存加入一条候选湖鱼并发原获得提示 FIFO。失败/取消不给鱼，满包放回。Esc、失焦、装备丢失均安全释放状态。

## 入口与试玩

双击 `Start-Fishing-Preview.cmd`；或 Godot 4.7.2 打开 `scenes/fishing_preview.tscn` 按 F6。默认 1280×720，首次等待地图加载。WASD 移动，靠近鱼群 E，小游戏 Space，Esc 取消，空闲 R 回首处湖岸。开局有竿，不必制作；正式可制作鱼竿本身未改。

用户中途明确要求造型与现有鱼竿一致，随后明确必须保持原尺寸。当前候选沿用弯木竿、线轮、绑带，仅去除贴图中的固定线；原尺寸配置 0.24、256×256 画布，撤销早期两倍放大 0.48。正式 `assets/industry/v1/fishing_rod.png` 原字节保持，握点/杆头坐标用于候选图运行时连接。

## 文件清单

- 新入口 `Start-Fishing-Preview.cmd`、`scenes/fishing_preview.tscn`。
- 新 `prototypes/fishing-v1/preview_world.gd`（临时世界/内存物品覆盖/鱼群布点）、`fishing_preview.gd`（流程/输入/侧视动作/表现）、`timing_bar.gd`、`side_poses.json`、`README.md`。
- 新 `prototypes/fishing-v1/art/`：rod/float/fish/coin/locked_chest 五个候选 PNG、对应 `.res`、registration.json。`.res` 是同图原生压缩纹理，不是第二批美术。
- 新 `art/fishing-v1/`：原图、提示词、生成回执、参考哈希、所有权拆分、处理结果、QC、发布/纹理导出脚本、provenance.json；原第一版直竿只作被替代来源保留，运行不引用。
- 新 `tests/test_fishing_preview_v1.gd` 及 UID；本报告、结构化测试结果与临时截图。更新 PROJECT_STATUS.md 和 DEVLOG.md。
- 没有修改普通入口、project.godot、正式 scripts、data 或 assets。原先其他未跟踪原型保持不动。

## 隔离与验证

Godot 4.7.2 / Compatibility / NVIDIA GeForce RTX 3060 / 默认 1280×720。试玩修订定向无头96项、窗口96项，均0失败；结果见 `headless-results.json` 与 `window-results.json`。包括原尺寸断言、新三处完整水面包络与24相位波纹检查、实际岸线裁切、200次随机安全区范围/变化/宽度、10000等分抽样验证概率阈值、两种彩蛋隔离定义/贴图/无用途、分别成功仅发一件与失败不给、获得FIFO及金币描述。稀有成功用受控抽定值验证，并非声称人工随机钓了数百次；普通流程锁定普通鱼，避免随机让定向断言偶发失败。

覆盖：真实岸边三点与可达、近/远/未装备/UI 打开交互；左右侧视和镜像、固定脚底、四抛竿相位下持握注册；抛竿进入等待、杆头/浮漂端点及水面位置；咬钩/小游戏进入与圆点移动；Space 命中两次、安全区变化、防连按；三失误、三超时、取消和失焦、装备丢失；成功仅奖励一次、原获得卡、失败无鱼、满包无提示；移动/菜单/快捷键输入锁和结束恢复；独立场景初始化与所有纹理加载。

左右镜像使用同一正式侧视角色，左侧自动转向分支以本地镜像目标定向验证，不冒充第二片真实左岸场景。窗口截图来自自动控制器实际渲染，未声称人工长期手玩。早期贴图被 prototypes/.gdignore 隔离导致加载失败已改为原生 `.res`；早期窗口检查受失焦取消干扰，新增尺寸断言也曾因 Vector2i/Vector2 类型不一致中断，均未计为通过。已修正断言类型；控制器仅在正常推进时处理失焦，自动测试暂停推进时免受外部焦点干扰，失焦专项则恢复推进并主动验证。最终重跑通过。

临时世界使用已有隔离 fixture：persistent_world=false，世界身份读写覆盖、环境保存路径为空，ItemService 原保存请求成为 no-op。测试前后比较玩家 user:// 下 13 份 JSON/tmp 文件的名称和 SHA256（包含显式保存、关闭通知及节点释放），无变化。另比较正式入口/配置/角色/鱼竿/生产脚本 11 个文件 SHA256，无变化。文件清单哈希见结构化结果。未改变存档格式，也不向玩家档投放物品。

启动脚本检查另见 `launcher-smoke.json`：实际从 cmd 启动预览场景，核对进程和窗口就绪。F6 所用正是同一个场景，非另造演示。没有改普通 Start-Playtest 或默认主场景。

## 美术来源与质量记录

generate2dsprite → route_media → local:codex-cli，模型 codex-image_gen，精确模型版本未披露；回执 estimateUsd=0（本地订阅路由）。参考正式侧视头和现有正式鱼竿，来源/提示词/回执/参考与成品哈希见 `art/fishing-v1/provenance.json`。无人物新画稿，水花/鱼影/涟漪/运行时鱼线/UI 使用本轮明确允许的程序表现。

保留源图 WARN：`art/fishing-v1/qc-rod-matched/sheet-qc.json` 的 `faint_specks`，value={floor_px:4595,detached_components:0}，threshold=0。通过 native_alpha + alpha-hygiene both 清理 alpha≤4 的 4595 像素，最终处理结构 QA 通过；源图警告仍留档，不称全流程无警告。结构通过不代表审美获批。

彩蛋图同样由 Codex (local CLI) / codex-image_gen 生成，estimateUsd=0，原图1774×887、左右归属拆分，软抠品红底/去溢色/Lanczos至256画布，处理结构QA通过。原图 `art/fishing-v2/qc-source/sheet-qc.json` 保留 WARN：id=`safe_frame`，value=1，threshold=0，cells=[[0,1]]，note=`owned art closer than 15% of the cell to its edge; ask for more margin next time`。宝箱未跨格、未触边裁断，完整保留后归一到有留边的画布；不把原图留白警告写成无警告。新增图来源和PNG/RES哈希见 art/fishing-v2/provenance.json。

## 待审核与明确边界

请重点看：原尺寸弯木竿是否与现有装备统一、抛/提竿与双手姿势自然度、鱼群克制度/浮漂可读性、小游戏难度和鱼跃/水花的成就感。所有新增图与姿态仍为候选。

未做正式接入、正式新物品/配方、候选迁入 assets、耐久消耗或鱼类平衡、真实鱼群 AI、水下路径、鱼钩飞行、鱼线物理/张力/复杂收线、多鱼品种、料理或其他扩展。未做全量回归、多分辨率、长期人工平衡、大营地 FPS 或发行导出包；本轮仅本地 Godot debug/preview。确认前保留本轮临时截图，文字/来源记录长期保留。完成本轮后停止等待验收。
