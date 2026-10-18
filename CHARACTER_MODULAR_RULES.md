# 当前角色部件、动画与资源契约

## 2026-10-18 · 正面劳动的双手显示与肩部例外

正面持工具劳动的右臂/工具/手掌顺序、空闲臂唯一前景显示与肩部连接，统一遵循[EQUIPMENT_SYSTEM.md当前规则](EQUIPMENT_SYSTEM.md)。该局部例外覆盖下方“左手始终最后层”的历史绝对表述；非正面劳动及背/侧向仍恢复原规则。保持已确认部件PNG与关节路径，不生成新手臂画稿、不更换原动画资源。新工具须复用共用持握组件并验证双掌可见/肩部相连，不独立覆盖全局Z。


## 2026-10-18 · 背视工具在双腿之后
原ArmR/Grip继续驱动全部工具的持握变换，背视唯一工具显示在Visual下HeldToolBehindLegs，兄弟顺序在双腿之前、show_behind_parent=true、z_index=0。原工具隐藏，正侧面恢复原节点显示；拾取/卸下无残影。保持原部件、握点、动画与世界Y排序，不用全局负Z。四工具133项窗口验证及原交互79项窗口/79项无头通过，见reports/back-layer-floor-v6/REPORT.md。

## 2026-10-18 · 三种劳动背视复用
按用户明确要求，采矿/砍树/挖土背视采用石锤现有harvest/back_mine原生部件动作，按装备引用替换工具。砍树方向恢复四向选取；背视砍/挖播放时间映射到原各自命中点和结束时间，不改实际结算。其他方向沿用原动作，PNG/支点/动作资源不变，不描述为新制作的序列帧。验证见reports/camp-refine-v5/REPORT.md。

## 2026-10-17 · 采集固定主体、接地、长按与快捷装备
用户最新要求采集阶段不得跳位、资源像树石一样适配地形、镐/铲长按E连续采集、快捷栏装备后仍显示并能数字键切换；另明确侧面镐头不能被矿石盖住。当前矿点固定完整主体+内部裂纹叠加，埋藏物固定完整主体+显露遮挡，贴图/轮廓/脚底不切换。底部原画土边通过原纯地表拷贝逐像素适配真实地面。mine/dig长按复用完整动作且只对锁定目标逐次结算，松开完成当前动作后停。快捷装备使用hotbar_equipment实例引用（非复制物品），1–8切换，旧装备回原快捷格；旧档缺映射合法。侧面工具和右手保持原变换，按当前目标前方局部世界Y绘制，原重复显示隐藏，手掌压柄和左右镜像保持，结束恢复。新规则覆盖早期“快捷键不装备/装备后格消失”和阶段换图说明。无新增PNG/地图规则/玩法。143项相关断言通过，窗口旧拖拽输入不稳定失败留档、最终无头原生界面51项通过；实景/日志reports/harvest-fix-v051。本轮完成停止。

## 2026-10-17 · 石镐开采与铲子挖掘正式实现
本轮用户明确要求完整可玩接入，授权新增两类正式矿点、三类埋藏物、独立原生四向采集动作和必要新美术；覆盖历史仅F6矿点/通用拾取动画/不做挖掘的本轮限制。普通景观石仍只碰撞。采集层harvest-resources-1.0.0通过原ItemService/区块worker确定性生成，石矿3击、燧石4击、根茎2次、骨片/补给包3次，resource_hits与consumed/loose同一原子存档。旧自然层/大陆及存档路径不变。新20图在assets/harvest/v05，受控来源art/harvest-v05，已按本次任务授权正式引用，用户主观视觉验收仍待试玩；原24物品图和6工具图不改。采矿1.12s/命中.55，挖掘1.25s/插土.43/翻铲提交.68，复用原部件和独立AnimationLibrary，原18动作/PNG不变。背包预览仍只播放front_breathe。详见[HARVEST_SYSTEM.md](HARVEST_SYSTEM.md)和reports/harvest-v05；本轮完成停止。

## 2026-10-17 · 背包装备预览固定正面
用户最新要求：背包人物仅显示正面，不跟随场景朝向、左右镜像、行走或交互动作切换。预览独立播放原生front_breathe，复用相同装备数据与持握/外观渲染组件，装备和卸下实时更新；世界角色仍使用原四方向动作。此前跟随世界姿势/视角的预览规则仅为历史。

## 2026-10-17 · 背包预览层级必须跟随正式角色
预览每帧同步CanvasItem.show_behind_parent、z_index、z_as_relative及采样/自身调制属性，不能只同步变换/贴图。ArmR的show_behind_parent由原动画按方向改变，漏同步会让预览侧面的持握手臂错误藏到衣服后。人物预览保留独立原点；复制层级状态及现有兄弟顺序，不改变世界角色、身体PNG、动画或装备握点。

## 2026-10-17 · 获批工具原生持握
当前主手显示节点为Visual/Pelvis/ArmR/HeldTool，作为ArmR首子节点画在原Sprite手掌后；握点来自data/held_tools.json，定位于原Grip.position+(0,-2.75)，与手掌中心一致。材质直接复用获批工具图标，不裁人物部件、不将生成完整立绘替换角色。原Grip/Axe保留历史但正式玩家统一隐藏，避免重复或错误显示金属斧。持握轻抬肩在每次原动画seek前撤回上次偏移，再应用数据角度并反向校正工具角度，保证不累积漂移；四方向继续front/back/side+左向镜像，世界Y排序不变。砍树沿用旧ArmR和Grip关键帧，拾取时收起HeldTool，结束恢复。左手ArmLBehind始终保留身体最底层。背包预览复制Sprite centered/offset/flip/transform和兄弟绘制顺序。

## 2026-10-17 · 左手固定为身体最后层
ArmL仍为Visual/Pelvis/ArmL，原有位置/旋转/摆动曲线保留。可见左臂Sprite改为Visual/ArmLBehind，位于Visual/LegL和LegR之前，三者均show_behind_parent=true、z_index=0。Visual/Pelvis/ArmL/RearVisualDrive为原生RemoteTransform2D，在原Sprite相同的局部(0,9.5)、scale(.25,.25)驱动../../../ArmLBehind；原贴图/flip_h轨道只改目标路径，不改关键帧值。保持Pelvis、肩关节、镜像与脚底支点；不通过全局负Z修身体层，以免破坏世界Y排序。旧Visual/Pelvis/ArmL/Sprite不再存在。右手ArmR/Grip与既有工具动作不变。背包预览同步Sprite纹理、翻转、变换及显示属性，使用同一个正式角色场景。

## 2026-10-17 · V0.4 装备外观兼容补充
本轮允许装备槽及主手状态展示，覆盖旧文“未开发装备”的范围描述；原部件/比例/支点与动作素材不修改。背包预览复制正式角色当前原生姿态、纹理和登记附件；data/equipment_visuals.json以visual_id与front/back/side登记已获批的支点兼容贴图，头饰/服装整体槽共用该入口，左向继续原生镜像。当前没有新头饰/服装素材，注册表为空；功能验证只在测试内临时引用现有角色贴图，测试数据不进入正式数据库。主手以原生名称标识，不新贴镐/铲到手上；石斧沿用已确认砍伐动作和斧图，石镐沿用通用交互反馈，不能表述为已完成新采矿或四向工具动画。

版本 windrest-cartoon-rig-2 · 2026-10-16。替代模板5完整帧/换装规则，旧资产只作历史追溯。

## 基体与命名
逻辑画布128×128，脚底(64,112)，纹理四倍密度；头部、衣身、带袖手臂、带裤管短腿来自已确认 V4，不能从完整立绘临时切碎。角色部件使用 front_head、back_head、side_head、front_torso、side_torso、front_arm、side_arm、front_leg、side_leg.png；body/服装改变需保持支点和遮挡补足，未开发换装。
动画 {front|back|side}_{breathe|walk|run|chop|pickup}；左向镜像 Visual 并保留步态相位。当前回用已确认原生关键帧，run 是已有短腿快速步态，chop/pickup 是一次动作，事件由游戏逻辑唯一触发。

## 层级
World / StreamedTerrain；World / YSortedNatureAndActor 下为 Wanderer、EnvTree、EnvRock、Decoration、DropWood。所有世界对象以脚下原点 Y 排序。
Wanderer(CharacterBody2D) / CollisionShape2D、Camera2D、Character；Character / AnimationPlayer、Visual；Visual / LegL、LegR、Pelvis；Pelvis / Head、Torso、ArmL、ArmR；ArmR / ToolGrip / Axe。
保留实验关键帧兼容路径 Grip 作为 ToolGrip 的实际节点名，语义一致；禁止将实验 Tree/Fruit 节点随角色带入地图。
世界景物 / StaticBody2D / CollisionPolygon2D；树只碰树干，石只碰底部；掉落物无阻挡，用有限距离且视线可达的主动拾取，避免妨碍移动。

## 环境命名与原点
新增正式图片位于 assets/environment/cartoon_v2，tree_0/1、rock_0/1、tuft_0/1/2、wood、axe、meadow.png；各类未来版本用独立目录，不覆盖历史源图。
树/石/草 PNG 裁除透明边后以底部中心注册，实际渲染底边为根点+8px。碰撞坐标随显示尺度而非源图片像素统一变换。
可交互对象按坐标ID命名/登记，EnvTree_{id} 和 DropWood_{id}；砍倒状态在当前运行的区块重载后保留，掉落为独立世界节点。当前无存档、背包或成长系统。

## 接入边界
实验动作可复用；明确禁止正式使用的实验斧/树/果实不得迁入。本轮重新生成正式斧与木材。历史 assets/hero/modular_plan/CHARACTER_MODULAR_RULES.md 为旧完整帧模板，仅约束归档资源。

## 2026-10-17 · 连续体型V1
实际角色继续原生AnimationPlayer，不是Spine。动画/装备更新后，body_shape将Visual/Pelvis/Torso与Visual/Pelvis/Head/Sprite宽度按build[-1,1]设为原宽90–112%/95–106%，高度与正常基准.25保持。衣身同图同步、头发五官同头图同步；Pelvis/Head公共支点、四肢/Arm/Grip和碰撞均不缩放。目标值绝对计算不累乘，四向与背包正面呼吸统一。没有新胖瘦PNG或原动画关键帧修改。实际窗口多相位播放和三工具走跑Grip保持验证见reports/body-v1/REPORT.md，未来服装未穷举。
