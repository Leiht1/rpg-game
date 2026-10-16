# 当前角色部件、动画与资源契约
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
