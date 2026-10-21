# 人物创建与换装 V1（候选美术）

2026-10-21：程序已接入主入口的单机新角色与联机首次角色流程。旧独立试玩入口及原存档保持；新单机路径和服务器权威边界见 [联机规范](MULTIPLAYER_V01.md)。以下“不会自动接入普通世界”为接入前历史范围；原旧世界继续原角色，不回写候选，新美术仍pending_user，不因流程接入而批准。

2026-10-20。本轮仅独立试玩；所有新外观 `pending_user`，不会覆盖正式角色 PNG，也不会自动接入普通世界。验收证据见 [报告](reports/character-creation-v1/REPORT.md)。

## 入口与持久化

- 双击本地 `Start-Character-Creation-Preview.cmd`；可同步的启动脚本为 `tools/Start-Character-Creation-Preview.ps1`。直接运行 Godot 场景 `scenes/character_creation_preview.tscn` 亦可。
- 首次只创建 UI，不初始化世界、不写世界身份。确认「进入世界」后才构造原 `world.gd` 的完整 1536 格大陆；已存在的1024格试玩继续按原尺寸恢复，不重排；使用新 Seed、原自然资源/营地生成与安全出生逻辑，再复验实际落点。
- 原大陆、碰撞、区块线程、天气、昼夜、物品及劳动均复用正式系统。角色创建不发调试工具，背包仅新增一套时髦服装，不自动穿上。
- 候选只写 `user://character-preview-v1/state.json`，既有正式身份、物品和环境文件不读取、不改写。试玩环境不另写独立环境文件，复用原 items 快照的 `body_environment` 原子恢复。
- 生成或安全点失败回到选择界面；首次写入/替换失败保留选择供重试。损坏/未知存档保护源文件并阻止进入。初次确认前及失败阶段不提交角色创建状态。
- 下次打开直接恢复同一角色、Seed、最后位置、外观和装备。保留原 15 秒脏快照与关闭保存；关闭保存失败时留在世界提示重试。
- 重置用本地 `Reset-Character-Creation-Preview.cmd` 或上述 PowerShell 脚本 `-Reset`。只将精确的试玩目录改名为带时间戳备份，然后重新打开创建界面；不递归删除任何玩家数据。N 在本试玩禁用，不能绕过角色归属修改世界 Seed。

## 存档结构与边界

原 items 根版本仍为 1，库存、装备、快捷栏别名、位置、身体、环境、建筑、资源移除/进度、动物、商人、鱼群等字段仍由 ItemService 生成、校验和恢复，不另造库存。

试玩在同一次原子快照附加：

```json
{
  "player_state_owner": "角色ID",
  "character_session": {
    "version": 1,
    "world_id": "测试世界ID",
    "seed": 123,
    "map_cells": 1536,
    "active_character_id": "角色ID",
    "characters": {
      "角色ID": {
        "world_id": "测试世界ID",
        "appearance": {"gender":"female","hair_id":"female_bob","skin_id":"skin_2"},
        "outfit_id": "modern_outfit",
        "test_outfit_granted": true
      }
    }
  }
}
```

根库存/装备/最后位置的所有者由 `player_state_owner` 显式指出，当前只支持一个活动角色；外观按角色 ID 单独登记，绝非世界共用单一外观。`outfit_id` 是原装备实例的校验投影，真正的唯一实例仍在原 `equipment`/`slots` 内，不另存第二份物品。世界地形由原生成器版本、尺寸和 Seed 重建，实际建设/资源等变化仍在原快照。

只在创建成功这笔快照中将一次赠送标记设为 true。重新进入从不按缺衣服补发，因此存放、丢弃、消耗/销毁都不会重新出现。保存失败不能提交赠送完成状态。候选装备/拖动装备复用 ItemInventory 原算法，加保存回调；装备或卸下保存失败时回滚格、唯一实例、装备及快捷栏别名。

本轮没有网络、管理员/房主标记或权限。未来多角色库存分区与服务器验证仍需后续协议，当前字段不能当作服务器授权证据。正式旧档没有新字段仍按原入口工作；候选入口不导入或迁移正式旧档。

## 角色外观与部件模板

唯一数据入口：`prototypes/character-creation-v1/catalog.json`。包含男女各四种发型三视图、六种自然肤色及服装部件映射。新增服装登记 `outfits[物品ID]` 的 `parts` 和 `skin_regions`，不改原动画。

检查确认：正式角色实际是 Node2D 关节层级与 AnimationPlayer 关键帧，当前场景没有 Skeleton2D/Bone2D。保留这套实际结构，不人为重造另一套骨骼。保留 128×128 逻辑画布、脚底 (64,112)、原 .25 部件尺度、四向/左右镜像、手臂 RemoteTransform2D、工具握点及所有动作资源。

- 原头图含头发；当前运行使用24张完整黑发三视图、3张去发底头（侧头V2）及9服装部件，共36张贴图。V1拆层原图保留追溯，运行不再使用其水平切开的前后片。美式前刺沿用旧male_parted ID以兼容已有试玩人物，只改变名称与造型。
- 完整头发附在原 Head/Sprite 子树，利用图中真实脸部开口显示底头，随原头部动画及头宽变化；不按水平线硬切前后层。旧后层节点隐藏且清空贴图，避免残影。侧头移除耳下连到下颌的错误分割线；睡眠闭眼位置按catalog中的底头UV配置，不硬编码旧位置。
- 服装替换原 Torso、ArmLBehind、ArmR/Sprite、LegL/Sprite、LegR/Sprite 的纹理。三方向各躯干/单臂/单腿，左右必要复用镜像，仍是套装槽。
- `character_look.gd` 在原动画 seek 后、工具副本同步前应用。世界、创建预览、背包正面预览与睡眠头部共用，卸下后由原动画轨道恢复默认纹理。原工具前/背/侧遮挡机制不改。
- 六种肤色用统一 Shader 保留原明暗，按原暖肤色像素及可配置部位范围识别；不染头发/眼睛/衣服。夹克颈口与袖口手部的皮肤范围由服装配置指定，裤装/鞋不染。睡眠复制当前侧头材质再闭眼，不丢失肤色和头发。
- 体型继续调用原 body_shape，只改原指定宽度，不改四肢长度、Grip 或碰撞。

候选时髦服装仅在该世界的独立 ItemDatabase 实例中启用装备字段；`data/merchant_items.json` 和正式交易价格/库存未改。当前图标沿用既有获批蓝色夹克图，候选身体部件是青绿/橙条夹克与深蓝裤装，色彩身份需人工审核，未擅改正式图标。

## 创建界面显示

创建预览单独关闭物理插值，手动seek完整姿态后重置插值历史，防止切换视角时插值经过上一方向的变换；世界角色仍沿原物理插值。性别、发型下拉的PopupMenu自身使用统一纸布主题，不能仅给外壳按钮换皮。

## 美术来源与审核

完整提示词、原图、受控路由回执、所有权边界、缩放/支点坐标、SHA和QA均在 `art/character-creation-v1`。实际流程 generate2dsprite → generate2dmedia/route_media → Codex（本地 CLI），5次成功生成，1次服装调用失败后用3参考图重试成功。模型回执 `codex-image_gen`，精确修订与订阅额度折算费用未知。

先生成/审核结构再做原生窗口候选，不将本轮任务授权或结构QA记为美术确认。所有候选仅供本轮试玩，未来正式接入需本批具体确认。

2026-10-20 黑发与裁切修订：当前新增25PNG在 `prototypes/character-hair-v2`，四次真实Codex(local CLI)生成、提示词/参考/处理/注册/SHA在 `art/character-hair-v2`。窗口专项189项0失败、资源注册72项0失败，见[修订报告](reports/character-hair-v2/REPORT.md)。新美式前刺和黑发仍待本批视觉确认，旧V1通过记录不替代本次视觉审核。

2026-10-20 低马尾侧视V3：当前仅female_ponytail.side.front改用 `prototypes/ponytail-side-v3/female_ponytail-side.png`，补齐发带上方后脑漏肤，正背图、其他发型及旧PNG均保持。生成补片位于原发型下方，刘海/发带/马尾等原不透明像素不变；左右共用原镜像。来源/坐标见art/ponytail-side-v3，定向结果见[单项报告](reports/ponytail-side-v3/REPORT.md)，仍待本批视觉确认。

2026-10-20 世界地图V3：只修改新建默认尺寸和兼容尺寸校验，世界身份/探索保存规则见 [世界地图V3](WORLD_MAP_V3.md)。旧1024和新1536的JSON数字兼容及独立重启已检查，本批人物美术仍待确认。
