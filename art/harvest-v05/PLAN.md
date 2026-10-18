# 石镐与铲子实施计划（2026-10-17）
现有接口已核对：WildPlayer.action_target/action_committed；WorldInteraction.allowed/execute/in_reach；ItemService.build_distribution/install_chunk/snapshot/save_state；WildStream.create_item_drop/unload_chunk；ItemInventory.use_slot；ArmR/Grip/HeldTool、ArmL/RearVisualDrive。

文件范围：
- data/harvest_resources.json：五种资源、命中次数、生态概率、尺寸/碰撞/交互距离与掉落。
- scripts/harvest_distribution.gd：复用ItemService地形/净空/连通检查及原worker，独立版本采集层，不移动旧资源。
- scripts/harvest_node.gd、harvest_burst.gd、harvest_hit.gdshader：固定锚点阶段贴图、局部命中高亮及一次性碎屑。
- scripts/item_service.gd：生成包、进度、单次掉落、原子存档和旧档兼容；保留原自然层与世界身份版本。
- assets/hero/cartoon/harvest_actions.tres、tools/build_harvest_actions.gd、player.gd、held_tool.gd：独立mine/dig原生多部件关键帧与命中时序、目标锁定和中断。
- data/items.json、item_inventory.gd、item_ui.gd：三个缺失物品、补给包固定内容的容量预检、资源名/进度提示。
- assets/harvest/v05、art/harvest-v05：新生成画稿、原始源、提示词、回执、透明处理与QA；石头/燧石/胡萝卜掉落复用已批准图。
- tests/test_harvest_v05.gd、reports/harvest-v05、HARVEST_SYSTEM.md、DEVLOG.md：专项实际运行与交付证据。

执行顺序：受控美术生成 → 数据和原生动作 → 正式区块/进度/掉落闭环 → 原生专项与实际尺寸视觉检查 → 记录。新矿点独立于六类只碰撞普通景观石。角色和既有PNG、移动速度、大陆/地表/树石坐标与存档路径保持。新增采集层使用harvest-resources-1.0.0独立生成版本，旧档缺失字段按空进度兼容；未知采集版本保护源档。用户本次明确要求完成素材并实际接入，作为本批开发接入授权，视觉质量不冒称用户已验收。
