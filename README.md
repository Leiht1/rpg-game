## 2026-10-25 · 连续探索 V1-A 最终篇章

普通入口沿矿洞路线图的原等待期限继续到海蚀遗迹台地、两阶段远古领主、独立内核及最终宝箱；海域图文记录和船坞制作图接原背包，蓝图解锁真实船坞建造，不含航行。初版地面硬边、柱体比例已返工并检查实际人物正常/放大及前后遮挡。可运行 `Start-Final-Chapter-Preview.cmd` 打开每次重置的隔离试玩；正式玩家档不导入试玩进度。规则/实际验证见[最终报告](reports/final-chapter-v1/REPORT.md)，修正实景见[场景报告](reports/final-chapter-v2/REPORT.md)。

## 2026-10-25 · 连续探索 V1-A 等待与垂钓老者

普通入口已接入持久化阶段等待、前辈遗迹、大陆外缘岸边垂钓老者与原钓鱼特殊收获；地图/残页/瓶内信使用独立纸页表现，完成到废弃矿洞线索。规则与试玩触发条件见 [探索规范](EXPLORATION_SYSTEM.md)，实际验收及边界见 [报告](reports/exploration-waits-v2/REPORT.md)。

> 2026-10-17 · 篝火与烹饪V1：C制作简易篝火（木4/石6/燧1），使用后左键放置；把快捷栏/背包可燃物拖到火堆上，角色投掷续燃，持主手工具时改左手。燃时条常驻火堆下方，厚度为前版1/3；燃尽自动熄灭。靠近E烹饪烤胡萝卜/烤蘑菇，完成领取再右键食用，进度/燃料/待领保存在原快照。[玩法规则](CAMPFIRE_SYSTEM.md) · [实景与交付](reports/campfire-v1/index.html)。

> 2026-10-17 · 制作V1：C或快捷栏“C 制作”打开六配方面板（含篝火，小型补给包仅可拾取），每笔1.5秒，按钮上方进度满后整体扣料/入包；关闭取消未完成制作，材料不动。UI保持已确认纸布风格与固定尺寸。[配方规则](CRAFTING_SYSTEM.md) · [进度实景与验收](reports/crafting-progress-v1/index.html)。

> 2026-10-17：工具美术与原生持握已按“接入游戏吧”授权正式接入。双击 **Start-Playtest.cmd**，F6添加工具，B右键装备或拖入武器格即可在人物和预览中看到。斧头砍树、镐子采矿、拾取时暂收工具，卸下清除。**Start-Tools-Preview.cmd**仍是自动提供三工具的临时试用，不导入正式存档。[正式实景与验收](reports/tools-formal-v04/index.html)。

> 2026-10-17 最新修正：左手置于身体部件最下层，保持原动作；装备区独立边框，标题在人像上方居中，槽名移至格下，头饰与背包首格顶边对齐。[新布局与持握候选](reports/equipment-panel-v04/index.html)。工具持握图仅供姿势/比例审阅，尚未接入正式人物动作。

> 2026-10-17 最新：装备槽在人物预览左侧竖排“头饰、武器、服装”，移除装备内容/未装备文字，保留悬停卡片。工具美术候选请双击 **Start-Tools-Preview.cmd**，B打开即可看到三工具；这是同Seed临时试用，不写正式存档。新图仍待视觉确认，正式入口未推广。[候选与新布局](reports/tools-v04/index.html)。

> 2026-10-17 · V0.4：B打开左道具/右装备与实时人物预览，支持拖动交换、右键装备/卸下。F6添加石斧/石镐/简易铲子，并可显式放置测试燧石矿点；关闭图鉴，把工具装备到主手，靠近目标按E。空手/镐不能砍树，斧不能采矿，任何主手都可拾取。普通景观石不变。新服装/头饰画稿、工具图标和复杂工具动作尚未制作，当前原生文字标识及兼容外观接口不等于美术验收。详见 [装备规则](EQUIPMENT_SYSTEM.md) 与 [验收报告](reports/equipment-v04/index.html)。

> 2026-10-17 最新补充：背包打开时可WASD移动；地图在最上层，完整覆盖快捷栏/时间HUD，M/Esc关闭；湖泊和河流也能出现雨滴扩散弧线。[本轮实景](reports/bag-map-water-rain/index.html)。

> 2026-10-17 最新：24张物品画稿已确认并接入正式游戏。双击 **Start-Playtest.cmd** 试玩；拖动背包/快捷栏物品到地面丢弃整组并播放脚边掉落效果，右键菜单“使用 / 销毁”，Ctrl+左键输入数量拆分，背包标题栏可拖动。详见 [本轮实景与验收](reports/item-actions-v031/index.html)、[ITEM_SYSTEM.md](ITEM_SYSTEM.md)。自然层版本、正式背包和采集记录保持；不导入预览存档。

> 当前大陆：V0.6 不规则大陆（用户于2026-10-16确认接入）。双击 **Start-Playtest.cmd** 游玩，正式入口仍为 scenes/world.tscn。生成器 `windrest-continent-0.6.0`；M查看完整大陆，N创建新Seed。沿用旧Seed/尺寸生成新大陆，旧布局不会保持；旧身份文件原样保留，新身份保存到 `user://world-continent-v06.json`，首次显示升级提示。角色、美术、移动、砍树与拾取保持。接入验证见 `reports/world-v06/integration.json`，大陆对照见 `reports/world-v06/index.html`。下文V0.5及更早说明均为历史。

> 已接入统一斜俯视树石与湖岸 V0.2，搭配多区域节点世界 V0.5；双击 Start-Playtest.cmd 体验。当前已验收的角色、树石与湖岸资源随正式项目提交。

> 当前正式版：多区域节点世界 V0.5。双击 **Start-Playtest.cmd** 游玩；**N** 新世界，正常重启沿用保存的 Seed；WASD / Shift / E / M 保持。当前生成器 `windrest-biome-0.5.0`，详见 MAP_SYSTEM.md。当前验收数据见 reports/world-v05/generation.json 和 runtime.json；截图比较页保留在本地。以下旧版本记录保留追溯。

> 当前场景美术（2026-10-16）：已确认的自然绿轻手绘 V0.7 正式接入。双击 **Start-Playtest.cmd** 游玩；WASD移动、Shift奔跑、E砍树/拾取、M地图。树石、地表和低密度花叶使用 `assets/environment/stylized_v3`，无踏草反馈。主角及玩法保持。专项结果见 `reports/scene-v3-integration-tests.json`，实际出生点画面见 `reports/scene-v3-after.png`。历史预览与下文旧版本记录仅供追溯。

# 风栖原野 · 简化卡通场景体验版
2026-10-16 · Godot 4.7.2 Stable · Windows PC。

## 启动
双击项目根目录 Start-Playtest.cmd，使用本机已有 Godot 4.7.2 启动当前游戏；或在 Godot 导入 project.godot 后 F5。无需 Python、图片服务或 API key。启动入口不是独立打包 EXE，依赖本机已有引擎。

- WASD / 方向键：正常移动 200 px/s。
- 按住 Shift：奔跑 310 px/s；松开恢复行走，无体力系统。
- E：靠近树干左右侧，看到提示后砍树；两次完整挥砍掉落一份木材。靠近木材按 E 拾取。动作期间暂时停步，结束恢复移动。
- 滚轮缩放；F3 查看当前运行指标。

出生点附近布置五棵树、三块石头、稀疏草花和一份测试木材，中央留空用于走跑；外围仍是原有 Seed 大地图与区块加载，不是孤立截图。只做基础砍树掉落/拾取反馈，没有背包、存档或新成长系统。重启场景恢复树和掉落。

## 当前正式方向
已确认的大头短腿白T短裤主角，六个原生部件支点、九张方向图片、15条 AnimationPlayer 动画：正/背/侧 breathe、walk、run、chop、pickup；左侧镜像。行走奔跑共享碰撞后位移相位，每128px一个周期，常速约.64秒，跑速约.413秒；不因按键重置步态。砍树/拾取回用已确认关键帧，不新增人物序列帧。
环境已切换 assets/environment/cartoon_v2：两款圆冠树、两款圆石、小草/草花、木材、新斧头；草地配色和低对比地表笔刷同步更新。旧环境与完整帧资源保留归档，当前加载不再使用它们。实验中禁止正式使用的斧/树/果实未迁入。
树干和石底为六点凸多边形碰撞，树冠不挡路，遮住主角时淡化。木材无物理阻挡，42px内且路径无遮挡才可主动拾取；砍树目标62px内且位于侧向，避免纵深动作对位错误。树砍倒后移除碰撞，当前运行中区块重载也不会复活。

## 地图复现
默认 Seed 271828，1024×1024格，48px/格、24×24格/区块。相同引擎、Seed、尺寸和生成器 windrest-0.1.1-cartoon 复现相同布局。该版升级反映出生点体验区、装饰密度及地表配色调整；河湖生成与基本区块机制保留。
命令行可使用 -- --seed=42 --size=1024。

## 验证与已知边界
本轮实际 Godot 窗口 / Compatibility / RTX3060：tests/test_scene_cartoon.gd 56项检查、0失败，见 reports/scene-cartoon-tests.json。范围包括走跑/Shift、步态、树干与树冠、石底碰撞、砍树命中只执行一次、掉落拾取、倒树后通行、边界和出生区同Seed复现；实际截图见 reports/scene-cartoon-v2.png、scene-cartoon-chop.png、scene-cartoon-pickup.png。
最初无窗口测试在第一段手动步进有2项距离时钟误差，实际60FPS窗口检查通过；未把它当作新性能数据。测试未覆盖所有Seed、长时间跨区块压力或所有岸线形状，原有五点脚下地形检测保留。本轮无新性能基准，不沿用旧版帧率承诺。
单段四肢、左右镜像光照、简化挥砍和拾取仍是当前已确认路线的表现边界。两次砍击后树摇动淡出，不包含物理倒树或树桩玩法。视觉统一与主观手感待用户验收。
图片实际路线 local:codex-cli / codex-image_gen，一次生成，无视频；精确底层图片模型与实际费用未公开。原图格线越界及透明雾点已按物件完整轮廓整理，不按格线硬切；整理后仍有 safe_frame 警告，见 art/scene_cartoon_v2/QA.md，不声明全部美术QC通过。

## 规范与追溯
ART_STYLE.md、CHARACTER_SEQUENCE_WORKFLOW.md、CHARACTER_MODULAR_RULES.md 为当前规范；AGENTS.md 已同步。旧 Gorest、完整帧模板和 prototypes 保留历史记录，不是正式生产默认路线。
art/scene_cartoon_v2 包含提示词、生成回执、来源、完整源图、裁片坐标与哈希、QA、原生动作整理源；assets/hero/cartoon 为当前玩家，assets/environment/cartoon_v2 为当前景物。DEVLOG.md 记录本轮范围。

相关检查：
```
Godot --path . --max-fps 60 --script tests/test_scene_cartoon.gd
Godot --path . --max-fps 60 --script tests/capture_scene_cartoon.gd
```
旧 tests/test_cartoon_player.gd 断言旧六条动画，仅作上次接入历史验证；tests/test_player.gd 等 SpriteFrames 检查也不是当前接口。本轮使用上面的新检查，不默认全量回归。完成后停止等待验收。

## V0.3 当前运行

双击 Start-Playtest.cmd；依赖本机已有 Godot 4.7.2，不是独立免安装EXE。WASD移动、Shift奔跑、E砍树/拾取、M地图、Esc关闭地图；地图可滚轮缩放及左键拖动。当前地表/地图/动作说明见 MAP_SYSTEM.md。专项检查：tests/test_v03.gd；保留原移动/碰撞依赖检查报告 reports/v03-regression.json。

实景：reports/v03-after.png、v03-forest.png、v03-mountain.png、v03-shore.png；前版同位置：v03-before.png。连续砍树与拾取预览：v03-continuous-chop.gif、v03-pickup.gif。美术来源与原图警告：art/ground_v03/QA.md。


当前地面候选预览：双击 Start-Ground-Preview.cmd，1旧版/2A/3B，0出生点、4森林/5山地/6水岸。WASD、Shift、E、M沿用；Start-Playtest.cmd仍为旧地面正式体验。候选生产门槛见 SCENE_ART_WORKFLOW.md，未选定不全图推广。


> 2026-10-16 接地美术更新：用户授权第二版接入试用，正式运行scene-grounding-0.1.0。树石底缘实时采样脚边地表色，保持V0.6地图/角色/碰撞和资源交互。验证与三类生态实景见reports/grounding-integration；上方“美术保持”指接地更新前的历史接入说明。

## 2026-10-16 · 当前景物已接入
正常双击 Start-Playtest.cmd，正式游戏使用 scene-contact-1.0.0（三树六石，各草地/林下/连续泥土边）。泥地是用户选回的dirt-02，草地与林下保留多组草叶落叶。树只晃动、砍完渐隐，无闪光；普通石头只碰撞。大陆生成器仍 windrest-continent-0.6.0，已有Seed身份保持。实际画面和相关验证见 reports/environment-game-v01/index.html；当前专项 tests/test_scenery_integration.gd及tests/test_grounding_interactions.gd，旧grounding共享材质/旧图接口检查属于历史版本。

## 世界环境 V0.2（2026-10-16）
双击Start-Playtest.cmd直接试玩，沿用V0.6大陆与scene-contact-1.0.0景物。新增60分钟一天、柔和昼夜、晴阴雨渐变和雨声；左上圆盘显示昼夜/天气/天数。F4打开环境调试（仅开发构建），可设时、暂停、倍速、快速预览及切换天气。环境每15秒和正常退出保存，重启恢复；地图和交互原有保存范围不变。说明见WORLD_ENVIRONMENT.md，截图与专项报告见reports/world-environment。

2026-10-16 最新天气修订：已取消阴天，F4仅晴/雨，两者25秒渐变。雨丝减量、随机间隔，添加少量白色落地扩散断弧；雨声为稀疏立体声水滴短音、极弱底噪。原存档兼容迁移，日期与时间保持。最新实景及可试听雨声见 reports/rain-v02/index.html，旧三天气报告仅作历史。

2026-10-16 雨效修订3：雨丝调亮并略拉长，保持原稀疏随机密度；合成雨声已移除，暂时无雨声，不用电子音替代。当前记录reports/rain-v03；旧试听文件仅属被否定的历史版本，不再由游戏加载。

2026-10-17 最新天气：晴朗 / 小雨 / 雷暴雨。原雨改为小雨；落地白色断弧提亮。雷暴雨雨量约5倍、环境更暗、圆盘图标增加闪电，每45–90现实秒短暂双闪一次（总长不超过0.28秒，UI不闪）。F4可强制三天气及预览一次闪电，仍暂不加雨声/雷声。旧存档兼容迁移，最新实景与专项reports/storm-v01/index.html；Start-Playtest.cmd启动方式保持。


## 2026-10-17 · 物品系统 V0.3 与新版 UI
B或快捷栏右侧的小背包按钮开关背包。32格背包、8格快捷栏；快捷栏初始留空，玩家拖动放入物品。拾取优先补快捷栏已有同类堆叠，再补背包堆叠及空格，不自动填空快捷格。1–8直接使用对应物品，食物消耗一份；右键也可使用。格内仅图标/数量，0.15秒悬停后出现有统一边框的信息卡；所有状态固定格子尺寸。F6为debug图鉴。
新物品美术与自然资源尚待确认，双击Start-Items-Preview.cmd试玩完整候选（独立预览存档），普通Start-Playtest.cmd只用已确认木材美术。详见ITEM_SYSTEM.md与reports/items-v03/index.html。
# V0.3.1 自然资源试玩（2026-10-17）

- 正式入口：[Start-Playtest.cmd](Start-Playtest.cmd)，现在可发现并按E采集/拾取自然资源；未获美术确认的资源使用“临·名称”开发标记，木材沿用已确认图。
- 美术预览：[Start-Items-Preview.cmd](Start-Items-Preview.cmd)，同一生成规则、独立预览存档，24张候选画稿仍待用户确认。
- B背包，1–8快捷使用；Ctrl+右键格子放下1个；F7资源分布、拒绝原因、ID、采集状态和临时Seed，F3/F4/F6保持。
- 五类实景、对照图及专项报告：[reports/resources-v031/index.html](reports/resources-v031/index.html)。规则：[NATURAL_RESOURCE_ECOLOGY.md](NATURAL_RESOURCE_ECOLOGY.md)、[ITEM_SYSTEM.md](ITEM_SYSTEM.md)。本轮不开发配方、工具、种植、生长或季节。

