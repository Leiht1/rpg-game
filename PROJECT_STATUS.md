# 《风栖原野》当前项目状态

更新：2026-10-20。此页仅为当前状态与按需导航；通用执行规则见 [AGENTS.md](AGENTS.md)，参数与细则以对应配置/系统规范为准。各项验证范围以所链接报告为准。

## 当前进度

- 下一轮人物创建与换装 V1 需求已原样保存至[下一步开发任务](下一步开发任务.md)，本轮仅归档任务并同步项目，尚未开始实现。测试/预览 CMD 启动器仅本地保留，不再纳入 Git 同步。

- 异次元商人本批已获用户授权正式接入，普通Start-Playtest直接生效；八张PNG按原SHA入assets/merchant/v1，采用回退后的柔和魔法阵，含已修复交易/手电/界面。无候选开关或素材依赖；独立试玩仍备齐材料，正式背包不赠送。默认窗口正式专项124项0失败，旧档缺merchant兼容及8/8哈希通过，玩家档未被测试写入。退出资源警告和未测范围见[报告](reports/merchant-v1/REPORT.md)、[规范](MERCHANT_SYSTEM.md)。

- 营地交互修订已完成：供给箱分开展示总量并使用二级材料/数量窗口，投入不能取回；熏制房去描述并收紧面板；饲料槽增加小图标；E施肥直接弯腰伸手、成功扣料提示与作物发光；饲料槽/堆肥桶移到种植类别；堆肥长按钮限定在原框内滚动。默认窗口80项0失败，隔离测试不写玩家档，未做全量回归。见[专项报告](reports/camp-interaction-polish-v3/REPORT.md)。

- 木箱开盖白块已修复：体量绘制复用原纹理缓存，避免局部资源在渲染前释放；原开盖美术和缩小尺寸保持。默认窗口20项0失败，含四次开关GPU逐像素对比与实际存取；测试世界不写玩家档，未做全量回归。见[专项报告](reports/chest-volume-render-v2/REPORT.md)。

- 营地扩展V2已获用户“接入吧”确认并正式使用：四种设施从开始显示在V列表、九种既有设施体量调整、正视建筑/冰箱及三种完整鱼形腐坏图。10张PNG按原SHA迁入assets/camp_expansion/v2；紧凑堆肥/熏制面板、腐烂名称后缀、仅烤鱼熏制和30日储存保持。普通Start-Playtest直接生效，独立全建筑排列入口仍保留。新增背包拖拽影像层级修复，物品可跟随鼠标并显示在背包上方。默认窗口正式/拖拽66项、设施事务210项、新进程读取7项均0失败，玩家档哈希不变。设施测试退出资源警告及未测范围见[正式报告](reports/camp-formal-drag-v2/REPORT.md)，成本见[规范](CAMP_EXPANSION_V2.md)。本轮停止，不进入NPC。

- 烤鱼专属图标已获“确认，可以替换”并按原SHA正式接入，背包/食谱/地面统一使用新图；腐坏烤鱼已改用获批完整鱼形图，鱼汤仍复用现有图。见[正式报告](reports/roasted-fish-formal-v1/REPORT.md)。

- 已修复所有建筑因鱼/熟食自然腐坏而反复误报“背包已变化”：保留真实库存变化拦截及保存失败回滚。定向验证见[报告](reports/build-freshness-v1/REPORT.md)。

- 废弃营地V1＋鱼料理V1已实现并接普通入口：新世界最多3组、三模板、锤毁返材及箱内物资同次保存；旧档不追加营地。湖鱼不可生吃、沿原腐坏与冰箱，新增烤鱼和蔬菜鱼汤。烤鱼已采用专属正式图，鱼汤仍复用既有图，三种腐坏鱼已采用营地V2正式整鱼图。验收与隔离试玩入口见[报告](reports/abandoned-fish-v1/REPORT.md)、[营地规范](ABANDONED_CAMP_SYSTEM.md)、[料理规范](CAMPFIRE_SYSTEM.md)。

- 钓鱼 V1 正式使用；鱼群新增每群6条、全图最多20群、每湖0–3群与稀疏大陆海岸分布，耗尽后2–3游戏日换随机岸位补充。原items保存鱼数、等待和随机状态，旧档兼容，获得与扣鱼原子提交；保留原尺寸侧视竿/随机窄安全区/深色鱼影/金币宝箱。无头和默认窗口新增专项各66项0失败、三Seed布点通过，测试未写玩家档。见[钓鱼规范](FISHING_SYSTEM.md)、[本轮报告](reports/fishing-population-v2/REPORT.md)。

- 用户提供音效已接入，最新按要求暂时关闭全部脚步声，音频与历史配置保留；其他音效照常。点击/关闭等素材替换保持，小雨/独立雷声仍缺。[音效规范](AUDIO_SYSTEM.md)、[收集清单](AUDIO_COLLECTION.md)、[停用记录](reports/audio-v5/REPORT.md)。

- 全局界面框已接入短淡入淡出，打开0.12秒、关闭0.09秒，含二级窗口与提示框；默认窗口专项34项0失败，见[报告](reports/ui-fade-v1/REPORT.md)。主观效果待反馈。

- 工业表现V3已完成亮度、制作/燃料条颜色、独立金属配方与生活/科技分类修订；上一轮默认窗口55项0失败，见[记录](reports/industry-polish-v3/REPORT.md)。

- 工业交互专项已完成：手动燃烧、独立产物/队列、一键领取与二级纸布燃料窗；开关在燃料条下方，烤箱黄色荧光玻璃，熔炉炉口火焰/完成烟，金属台复用制作页，建造消耗提示、地毯脚部层级及铜立灯范围已调整。默认窗口115项、独立重启8项通过，见[规范](INDUSTRY_SYSTEM.md)和[报告](reports/industry-refine-v2/REPORT.md)。效果待试玩反馈。

- 木地板/石路可直接铺在已有家具、床席、工业设施及篝火下方；墙体和已有地面占用仍阻挡。原建筑/箱内物品保持，窗口166项及独立重启5项通过，见[专项报告](reports/floor-under-buildings-v1/REPORT.md)。

- 已同步远端f09bde1并继续工业待办：正视工具/剪刀在手掌前、铜工具待机外倾、银提灯直接使用且不手持；燃料HUD按当前灯容量显示。最新专项与剩余边界见[报告](reports/front-tool-layer-v13/REPORT.md)。本批美术已正式采用；界面逐面板验收等尚未完成。

- 工业与营地生活 V1 已获“确认，直接接入游戏吧”批准，35张PNG按原哈希迁入assets/industry/v1，八设施配方默认开放，普通Start-Playtest无需预览开关。正式窗口271项、握持491项、独立重启7项0失败，见[规范](INDUSTRY_SYSTEM.md)与[正式报告](reports/industry-formal-v1/REPORT.md)。

- 剪毛时刀刃随人物四向朝前，路标命名窗/输入框绿色底已移除，地图隐藏出生地。默认窗口专项32项通过，见[报告](reports/shear-sign-map-v1/REPORT.md)。

- 剪刀已更名并放大图标/持握，校准手柄与外露刀刃；持剪刀靠近羊显示E剪毛，不持时无动物靠近提示，投喂教学/具体等待分钟已移除。普通重启沿原世界Seed恢复退出位置，旧档可继续读取。专项结果见[报告](reports/scissors-exploration-v1/REPORT.md)。

- 动物投喂已改为从背包/快捷栏直接拖到动物身上，每次1个并播放伸手递食与动物点头；不合适食物按鸡/羊提示，E保留跟随/留守及剪毛。原生窗口37项、剪毛相关33项、地面/篝火数量19项通过，见[报告](reports/animal-drag-feed-v1/REPORT.md)。

- 鸡羊统一画风V2已获用户确认并正式接入：白毛/白羽、无脖子大羊头与细腿、鸡双脚右移；普通游戏和旧档动物共用新表现，养殖玩法与刷新参数保持。见[正式报告](reports/animals-art-formal-v2/REPORT.md)与[动物美术规范](ANIMAL_ART_STYLE.md)。

- 新地图人物出生点已独立按Seed从实际安全陆地随机选取，避免旧地貌判断误选岩石区；原大陆/资源/营地布局保持。12Seed与原生窗口专项见[报告](reports/random-entry-v1/REPORT.md)。

- F6调试管理已加「附近生成动物 +1」，每次1只、鸡羊交替，见[专项报告](reports/animal-debug-button-v1/REPORT.md)。

- 动物密度已改为全地图初始最多6只、每7游戏日新增1只；探索/区块加载不补刷，旧档仅收减多余未驯养野生动物，保留驯养动物和幼崽。见[刷新修订报告](reports/animal-global-spawn-v1/REPORT.md)。

- 鸡、羊动物生态与养殖 V1 已接入：侧视骨骼拆件、投喂/跟随留守、真实围栏碰撞、产蛋剪毛、自动繁殖和三阶段成长；鸡羊新造型已获确认并正式采用。见[动物规范](ANIMAL_SYSTEM.md)与[专项报告](reports/animals-v1/REPORT.md)，独立试玩入口 Start-Animals-Preview.cmd。

- 矿石脚边土圈已适配岩石地表，实际抽样矿点增加约22%，五矿均增加；采集记录/进度保留。见[报告](reports/ore-ground-density-v1/REPORT.md)。

- 试玩修订已完成：岩石区改为独立第四区域并在地图显示；路标文字无底色、命名框复用纸布UI，旧布局采集进度迁移通过，见[修订报告](reports/ecology-signpost-v1/REVISION.md)。

- 世界资源生态V1与正式路标V1已接入：连续平坦岩石区、按地貌优化资源、保留旧采集身份/进度；路标命名后固定、锤毁同步移除M地图标记。定向验证与视觉待试玩边界见[报告](reports/ecology-signpost-v1/REPORT.md)。

- 致幻世界画面已增强缓慢变色、波纹与重影；蘑菇保持稀疏生态并小幅增加。专项及兼容迁移通过，见[画面报告](reports/hallucination-visual-v3/REPORT.md)、[分布报告](reports/mushroom-density-v2/REPORT.md)。

- 食物与烹饪扩展V2已实现，种植周期、四道新料理、蘑菇拾取及独立致幻接入原系统；四张图标已获“还不错，接入游戏吧”确认并原样接入assets/cooking/v2，正式窗口17项通过，见[图标接入报告](reports/food-formal-v2/REPORT.md)。定向结果与边界见[报告](reports/food-v2/REPORT.md)。

- 当前工程素材已分类核对，明确弃用且无引用的7张旧UI框图及导入文件已删除，原提灯与正式来源/报告保留；本轮工程同步见[整理报告](reports/material-cleanup-20261019/REPORT.md)。

- 木箱标题下移至空白处，格/图标缩小、框156×184；开关图统一缩小采样。左右背包在木箱上层且鼠标顺序一致，背包打开可E交互，整理按横向显示。最新窗口与重启验证见[专项报告](reports/chest-ui-v2/REPORT.md)。

- 背包已改为左右固定分框，木箱为独立世界锚定九宫格；建筑血条命中后2秒隐藏、支持长按E连续砸，床席床头/上沿接地碰撞已修订。专项窗口66项、重启3项及播种依赖20项通过，见[报告](reports/inventory-chest-v1/REPORT.md)。新开盖画稿已获“接入吧”确认并正式采用，无预览开关依赖；新增窗口9项及重启3项通过，见[正式报告](reports/chest-open-formal-v1/REPORT.md)。

- 播种已改为空耕地E打开种子小窗、点击即种，背包无种子显示“没有种子”；锤毁生长中耕地不返种、不发产物且重启仍移除。木地板缩小采样已启用mipmap以减轻运动细纹伪影；最新定向窗口、GPU及重启结果见 [修订报告](reports/planting-ui-floor-v2/REPORT.md)。

- 种植 V1 已获用户“可以 直接接入游戏吧”确认并正式开放。14 张作物/种子/收获物 PNG 按验收哈希原样迁入 `assets/planting/v3`，普通 `Start-Playtest.cmd` 无需种植预览开关；原 92×60 暗色耕地、96×64 格及残根共用底层保持。规则见 [种植规范](PLANTING_SYSTEM.md)，正式路径验证见 [报告](reports/planting-formal-v1/REPORT.md)。

- 正面工具的衣身遮挡、空闲手显示与肩部连接已按四工具共用规则修复；新增工具同样复用，当前约定见 [装备规范](EQUIPMENT_SYSTEM.md)，证据见 [专项报告](reports/front-tool-layer-v12/REPORT.md)。

- 正式 Godot 4.7.2 Windows 工程已有探索、资源采集、库存/装备、制作/料理、营地建造与身体系统。已获批的方形铺面、月牙精力图标和背包一键整理已接入；各系统当前细则见下表，不在此复写参数。
- 火把火苗飘动、建筑中心返料动画与篝火照明/燃料条局部调整已完成；当前规则见营地/篝火规范，默认窗口专项证据见 [本轮报告](reports/camp-effects-v11/REPORT.md)。
- 睡眠设施V9已获用户授权正式接入；V10保持原头部大小并适配设施；最新V11修复放大后碰撞偏移及中心交互距离问题。当前规则见 [睡眠规范](SLEEP_SYSTEM.md)，定向验证见 [V11报告](reports/sleep-collision-v11/REPORT.md)。

## 已知问题与待办

- 2026-10-19 已清理本地测试媒体、重复压缩包、旧发布检查副本、发布包和导入缓存，按清单释放约 2.14 GiB；项目现约 3.49 GiB，Git 数据约占 71.2%。来源记录引用的五张参考图、文字报告、指标、正式资源及原有修改保留。剩余清单内约 428.3 MiB 只读 Git 临时文件的强制删除被自动安全审核拦截，暂留；忽略规则与“用户确认后清理本轮截图”已生效，本轮不提交、不推送。详情见 DEVLOG.md。

- 本批种植素材已确认并正式接入，不扩大到未来素材。长期人工种植平衡和大量耕地性能仍未验证。

- 当前睡眠画稿已正式采用；本轮未新增画稿，未扩大授权到未来素材。
- 未来头部扩展需兼容侧视及闭眼位置配置；尚未开发换装系统。长期人工平衡、大营地性能与完整未来换装兼容性仍无完整验证结论。
- 旧文档和日志包含已被替代的阶段描述（例如睡眠快进/旧睡姿、候选未采用、三尺寸清单）；按最新有效要求与对应规范判断，不直接照搬旧标题或参数。发现影响本任务的具体冲突时再核查实现。

## 下一步（不自动开展）

营地扩展V2本轮完成，等待本批候选美术、现有设施尺寸及四设施试玩验收；入口与范围见[CAMP_EXPANSION_V2.md](CAMP_EXPANSION_V2.md)。确认前不推广正式素材，不进入野外NPC。界面逐面板验收、长期人工平衡及规模性能等原有待办不自动开展。

## 按任务选择入口（不是必读列表）

| 本次任务涉及 | 优先定位的规范 |
|---|---|
| 营地扩展V2候选、维修/供燃料/堆肥/熏鱼、设施体量 | [CAMP_EXPANSION_V2.md](CAMP_EXPANSION_V2.md) |
| 工业加工、烤箱、银提灯、冰箱、饲料槽与熟食腐烂 | [INDUSTRY_SYSTEM.md](INDUSTRY_SYSTEM.md) |
| 动物生态、投喂、围栏养殖、繁殖成长、鸡蛋羊毛与羊毛剪 | [ANIMAL_SYSTEM.md](ANIMAL_SYSTEM.md) |
| 种植、耕地、留种、生长与残根 | [PLANTING_SYSTEM.md](PLANTING_SYSTEM.md) |
| 睡眠设施、占用造型与唤醒 | [SLEEP_SYSTEM.md](SLEEP_SYSTEM.md) |
| 身体属性、食物效果 | [BODY_SYSTEM.md](BODY_SYSTEM.md)；涉及食用/库存再查 [ITEM_SYSTEM.md](ITEM_SYSTEM.md) |
| 背包、快捷栏、装备 | [ITEM_SYSTEM.md](ITEM_SYSTEM.md)、[EQUIPMENT_SYSTEM.md](EQUIPMENT_SYSTEM.md) 中相关章节 |
| 制作、料理、营地 | [CRAFTING_SYSTEM.md](CRAFTING_SYSTEM.md)、[CAMPFIRE_SYSTEM.md](CAMPFIRE_SYSTEM.md)、[CAMP_BUILD_SYSTEM.md](CAMP_BUILD_SYSTEM.md) 中对应系统 |
| 采集、矿点、自然资源 | [HARVEST_SYSTEM.md](HARVEST_SYSTEM.md)、[ORE_SYSTEM.md](ORE_SYSTEM.md)、[NATURAL_RESOURCE_ECOLOGY.md](NATURAL_RESOURCE_ECOLOGY.md) 中对应系统 |
| 地图或世界时间/天气 | [MAP_SYSTEM.md](MAP_SYSTEM.md) 或 [WORLD_ENVIRONMENT.md](WORLD_ENVIRONMENT.md) |
| UI或新美术 | [UI_ART.md](UI_ART.md) 或 [ART_STYLE.md](ART_STYLE.md)；再按资源类型及适用约定定位必需工作流 |

定位规范后，用具体符号/配置路径查实现与专项测试；只有发现明确依赖或冲突才扩展读取。历史决策仅按问题搜索 [DEVLOG.md](DEVLOG.md) 或对应报告。






