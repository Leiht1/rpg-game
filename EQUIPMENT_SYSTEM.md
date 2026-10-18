# 装备与世界交互 V0.4

## 2026-10-18 · 正面工具层级、双手与肩部连接（当前）

所有登记到data/held_tools.json的主手工具统一调用scripts/held_tool.gd。原动画取样后，正面持握右臂在衣身前、工具在原手掌后；不使用全局正/负Z压过世界景物。正面劳动时，双肩按当前Torso内部接点定位，右臂保留原动作旋转与Grip相对握点；空闲臂只在正面劳动时以原部件显示副本置于衣身前、手持臂后，并约束为自然外垂，不交叉盖住持工具手。原ArmLBehind同时隐藏，保证只有一条可见空闲臂。

release_pose在下一次动画取样/转向/卸下/拾取前恢复原肩部位置、空闲臂旋转及可见状态；背面工具仍在双腿后，侧面原世界Y接触层保持。具体接点/角度以held_tool.gd为唯一实现来源。此正面劳动例外覆盖下方历史“左臂始终最后层”，其他状态仍沿原规则；原PNG、动画资源、命中时序、掉落、耐久、存档不变。

未来工具不得另写按item_id的层级补丁，应只登记获批纹理/握点等数据并复用此组件。接入须定向核对自然姿势的双掌实际可见、双肩与衣身实心交叠、工具在手掌后、转向/结束恢复；不能只看z_index或单个工具截图。现有四工具及临时新ID/新动作验证入口tests/test_front_tool_layer_v12.gd，证据见[本轮报告](reports/front-tool-layer-v12/REPORT.md)。


## 2026-10-18 · 快捷栏装备引用菜单
已装备的快捷栏实例引用右键显示“卸下”，调用原unequip返回原快捷格；未装备物品显示“装备”。弹出时保存装备槽快照，期间装备变化则取消陈旧菜单操作；满包和实例唯一性保护不变，无存档格式变化。见reports/camp-refine-v5/REPORT.md。

## 2026-10-17 · 篝火交互文字

篝火从基础open改为基础cook，提示“E 烹饪”并直接打开食谱册，不需要工具。cook与原open在相同基础优先级、距离、遮挡和对象perform_interaction入口执行；其余pickup/open/talk/inspect及工具能力不变。本轮无装备实例或外观变更。


2026-10-17篝火追加：E沿统一open交互打开烹饪面板，不要求工具。投料时有main_hand实例则使用原生左手投掷动画，右手工具继续持握；装备变动在未提交投掷前取消，引用和已有动作不改。详见CAMPFIRE_SYSTEM.md。

## 2026-10-17 · 三工具可正式制作
三工具可经C制作取得，进度满后生成原生独立实例，拖到快捷栏/装备及主手能力规则保持。铲子材料为木材2、石块2、燧石1、植物纤维3，首把铲子无需先挖骨片。制作出的斧/镐/铲已通过原生E砍树、完整开矿、完整挖掘和基础拾取实用检查；不新增动作或改变采集次数。见[CRAFTING_SYSTEM.md](CRAFTING_SYSTEM.md)。

## 2026-10-17 · 采集固定主体、接地、长按与快捷装备
用户最新要求采集阶段不得跳位、资源像树石一样适配地形、镐/铲长按E连续采集、快捷栏装备后仍显示并能数字键切换；另明确侧面镐头不能被矿石盖住。当前矿点固定完整主体+内部裂纹叠加，埋藏物固定完整主体+显露遮挡，贴图/轮廓/脚底不切换。底部原画土边通过原纯地表拷贝逐像素适配真实地面。mine/dig长按复用完整动作且只对锁定目标逐次结算，松开完成当前动作后停。快捷装备使用hotbar_equipment实例引用（非复制物品），1–8切换，旧装备回原快捷格；旧档缺映射合法。侧面工具和右手保持原变换，按当前目标前方局部世界Y绘制，原重复显示隐藏，手掌压柄和左右镜像保持，结束恢复。新规则覆盖早期“快捷键不装备/装备后格消失”和阶段换图说明。无新增PNG/地图规则/玩法。143项相关断言通过，窗口旧拖拽输入不稳定失败留档、最终无头原生界面51项通过；实景/日志reports/harvest-fix-v051。本轮完成停止。

## 2026-10-17 · 石镐开采与铲子挖掘正式实现
本轮用户明确要求完整可玩接入，授权新增两类正式矿点、三类埋藏物、独立原生四向采集动作和必要新美术；覆盖历史仅F6矿点/通用拾取动画/不做挖掘的本轮限制。普通景观石仍只碰撞。采集层harvest-resources-1.0.0通过原ItemService/区块worker确定性生成，石矿3击、燧石4击、根茎2次、骨片/补给包3次，resource_hits与consumed/loose同一原子存档。旧自然层/大陆及存档路径不变。新20图在assets/harvest/v05，受控来源art/harvest-v05，已按本次任务授权正式引用，用户主观视觉验收仍待试玩；原24物品图和6工具图不改。采矿1.12s/命中.55，挖掘1.25s/插土.43/翻铲提交.68，复用原部件和独立AnimationLibrary，原18动作/PNG不变。背包预览仍只播放front_breathe。详见[HARVEST_SYSTEM.md](HARVEST_SYSTEM.md)和reports/harvest-v05；本轮完成停止。

## 2026-10-17 · 背包装备预览固定正面
用户最新要求：背包人物仅显示正面，不跟随场景朝向、左右镜像、行走或交互动作切换。预览独立播放原生front_breathe，复用相同装备数据与持握/外观渲染组件，装备和卸下实时更新；世界角色仍使用原四方向动作。此前跟随世界姿势/视角的预览规则仅为历史。

2026-10-17预览层级修正：背包人物每帧同步正式角色的draw-behind-parent、相对Z及过滤状态，修复侧面持握手臂在预览中仍被衣服遮住的问题。3工具×4方向×站立/行走24种姿势与原生角色同尺寸渲染逐像素对照，最大差异0。只改预览同步，不改场景人物/握点/图片/玩法。专项reports/portrait-layer-fix-v04/index.html。

2026-10-17正式工具接入：用户批准本批工具和candidate-03持握方向，正式ItemDatabase引用assets/tools/v04的3图标/3地面形态，visual_id=tool:*由data/held_tools.json解析。held_tool.gd在原右手支点绘制工具，原手掌覆盖实心柄部，空手/卸下不显示，pickup暂收起且结束恢复；旧Grip/Axe隐藏。背包预览与世界同工具/握点/绘制顺序，存档恢复后立即可见。原功能、数据实例、能力、地图及存档格式均保持。Start-Tools-Preview仍仅为自动给三工具的临时试用，现在与正式共用已批准图片；不导入预览物品。早期未接入/文字占位及pending说明仅为历史。最新报告reports/tools-formal-v04/index.html。

2026-10-17最新布局：角色装备标题位于人物预览上方水平居中；头饰/武器/服装名称放到各格下方，头饰格与背包第一格顶边对齐，整个装备区域用沿用暖色样式的独立圆角框隔开。逻辑槽与存档未变。人物预览使用已修正左手身体最底层的正式场景，保留原动画和动作支点。最新报告reports/equipment-panel-v04/index.html。

2026-10-17 · Godot 4.7.2 Stable / GDScript / Windows PC。

## 操作
B打开同一个背包：左侧32格物品，右侧人物预览及其左侧竖排头饰、武器、服装槽，底部8格快捷栏独立保留。左键拖动装备，右键在物品菜单选择装备，装备槽右键卸下。占用槽合法交换，返回物品原来源格；错误类型不动。卸下仅进入背包空格，满包不卸下。装备槽不直接销毁、拆分或拖地，先卸到背包再用原有操作。装备状态列表、HUD及人物头顶的装备名称已移除，具体内容仅悬停卡显示；逻辑main_hand继续保留，只把显示名改为武器。工具可以放入快捷栏，但1–8仍是原使用语义，不会暗中装备。

F6为开发图鉴：添加石斧/石镐/简易铲子；点击脚边放置测试矿点创建独立“临·燧石矿点（调试）”。关闭图鉴后装备镐、靠近按E，矿点淡出，燧石×3落到地面，再E拾取。矿点不自然生成，没有更改普通石头或任何地形规则。

## 定义、实例与槽位
静态物品来自data/items.json，ItemDatabase查询深拷贝。原12项定义保留，新装备字段不改变其食用/叠加规则。装备equippable=true、max_stack=1，实例保留item_id/count/instance_id/state/durability；实例ID使用ResourceUID生成后按字符串存档，避免JSON大整数精度损失。stats是静态未来属性，durability仅预留，不消耗。

data/equipment_slots.json驱动槽位ID、显示名及允许equipment_type：main_hand接受tool/weapon，head接受headwear，outfit接受outfit。ItemInventory的equipment字典独立于原40格slots；统一get_slot/move_slot使UI可以沿用旧格子。40及之后的显示索引只作UI适配，不序列化为背包格。新增槽只扩展配置，背包仍32格。

## 能力与统一接口
scripts/world_interaction.gd提供action_for、in_reach、allowed、target、caption、execute。树沿用trees组和原距离/遮挡检查，掉落沿用drops及状态检查；扩展对象进入world_interactables并提供interaction_action、interaction_range和perform_interaction(action,player)。当前mine由ItemService处理，未来open/talk/inspect可走对象方法；本版没有创建箱子/NPC或挖掘玩法。

pickup/open/talk/inspect无装备门槛；工具动作仅由主手定义capabilities决定，不按名称、分类或“任何工具”放行。石斧chop、石镐mine、铲子dig、未来武器attack互不相通。动作启动、命中再次校验，装备变更立即取消已失去能力的待提交动作。工具失败不消耗物品、不删除资源。普通拾取复用原满包/部分拾取语义。

候选必须在范围内、未采集、未落地飞行且无遮挡。鼠标命中世界对象范围优先，然后朝向锥、距离和基础交互偏好，最后稳定ID破平局；缺工具的树不会抢占无明确指向时的回退拾取。提示与E使用相同选择器，目标脚边显示名称及E动作/缺少工具。鼠标指向普通景观石不会把石头变成矿点。

## 兼容表现与当前美术边界
复用assets/hero/cartoon/character.tscn，未改比例、身体图片、行走/呼吸或原动画关键帧。背包中的SubViewport同步正式角色子节点当前变换、纹理、可见性和登记附件。正式入口暂保留原生“斧/镐/铲”占位字，不显示装备状态/内容文字。新工具候选图仅在Start-Tools-Preview.cmd显示，见prototypes/tools-v04/provenance.json。石斧使用原已确认chop动作和现有斧图；采矿使用现有通用交互反馈，不显示斧头或携带素材，不称为完成采矿动作。

头饰/服装槽功能可用，但本轮未创建新可穿戴头饰/服装物品及美术。data/equipment_visuals.json当前为空。获批素材未来按visual_id -> front/back/side -> [{parent,texture,position:[x,y],scale}]登记，只允许res://assets/中的已审阅引用，依照当前支点挂载。脚本equipment_appearance.gd同步到场景角色，预览跟随；装备与卸下同时更新。外观测试只临时引用现有已确认角色图片，未将测试物品/附件加入正式定义。复杂四方向工具动作及新服装画稿仍须独立制作确认。

## 存档
ItemService继续使用原路径和原子临时文件替换，snapshot增加equipment、equipment_quarantine、ore_nodes，原version=1、RESOURCE_VERSION及世界身份均保持。旧档没有新字段时按空装备/空矿点读入；不重置原背包/快捷栏/消耗记录/树状态，环境存档独立保持。

先在临时ItemInventory中校验背包、装备与实例身份，校验通过后才提交；未知槽、未知物品、错误类型/数量的装备原值隔离保留且不提供能力。背包、装备、松散工具之间出现重复instance_id则拒绝加载，writable=false保护源文件。工具丢弃记录完整实例，拾回还原同一个ID与state，不重新生成。矿点按坐标随原区块加载，采后由consumed记录抑制，掉落进入现有loose存档。

## 验收与范围
最新装备区与美术候选报告reports/tools-v04/index.html；UI专项55项、素材/原24图保护48项，原图safe_frame WARN value=6 threshold=0原样保留。上一轮功能报告reports/equipment-v04/index.html，原生输入专项75项、独立进程写入/读回7项、原物品交互48项。只测本轮与必要背包/地图依赖；未做无关全量回归或新性能压力测试。本轮没有新增战斗、怪物/NPC、耐久损耗、配方、建造、衣服拆件、强化或随机属性。

## 工具美术候选与预览
工具候选3图标+3独立地面形态经generate2dsprite/route_media生成，art_source=host_image，route=local:codex-cli，底层图片模型和实际费用未知。原图及提示词在art/tools-v04，soft matte、1px despill、等比统一尺度；最终PNG仅裁去透明留白并加8源像素安全边，未裁可见像素。原图六格未满足15%留白（safe_frame WARN 6，阈值0），没有跨格或边缘裁断；整理检查不能代替画风确认。

Start-Tools-Preview.cmd读取当前世界Seed但显式persistent_world=false，ItemService不导入正式背包；仅在该模式下为三工具查询候选图，临时背包初始提供三工具。原data/items.json的正式工具图路径仍空，旧24图字节保持。预览关闭后不保存试用数量/资源状态，也不创建新正式世界身份。新画稿pending_user；人物动作及手上工具图仍沿用此前获批内容。
