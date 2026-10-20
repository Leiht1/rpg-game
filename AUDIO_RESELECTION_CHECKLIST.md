# 风栖原野 · 全部音效重新配置清单

2026-10-20：按用户要求，已有音效也全部重新挑选、允许替换。以下所有条目不划线，不因旧素材已接入而完成；实际本轮进度以工作台保存与导出校验为准。原游戏音效继续保留，脚步仍停用。走路/跑步复用四种地面，不另造奔跑事件。

这是当前已实现玩法的声音需求，包含尚未接入声音的玩法；导出不等于游戏已绑定。稳定 ID 与源码依据见 [events.json](tools/audio_workbench/events.json)，使用方法见 [说明](tools/audio_workbench/README.md)。


## 角色与采集

| 事件 ID | 声音需求 |
|---|---|
| `sfx_step_grass` | 草地脚步（走 / 跑） |
| `sfx_step_dirt` | 泥地脚步（走 / 跑） |
| `sfx_step_stone` | 石面 / 石路脚步（走 / 跑） |
| `sfx_step_wood` | 木地板脚步（走 / 跑） |
| `sfx_chop_hit` | 砍树命中 |
| `sfx_tree_fall` | 树木砍完、倒下 |
| `sfx_mine_hit` | 镐实际命中矿点 |
| `sfx_ore_break` | 矿点开采完成 |
| `sfx_dig_soil` | 铲子挖掘、清除作物残根 |
| `sfx_pickup` | 地上物品成功拾取 |
| `sfx_gather_plant` | 采摘野外植物 |
| `sfx_drop_land` | 掉落物落地 |
| `sfx_tool_swing` | 砍、镐、锤挥动阶段 |

## 背包与界面

| 事件 ID | 声音需求 |
|---|---|
| `sfx_ui_click` | 普通按钮点击 |
| `sfx_ui_open` | 打开背包、制作、地图等窗口 |
| `sfx_ui_close` | 关闭窗口 |
| `sfx_item_move` | 拖放物品成功、背包与箱子转移 |
| `sfx_bag_organize` | 背包一键整理成功 |
| `sfx_equip` | 装备或切换工具成功 |
| `sfx_ui_error` | 无材料、满包等操作失败 |
| `sfx_item_obtained` | 制作、料理领取等获得提示 |
| `sfx_map_mark` | 路标命名确认成功 |

## 营地建造

| 事件 ID | 声音需求 |
|---|---|
| `sfx_build_wood` | 木栅栏、木地板、木家具等成功放置 |
| `sfx_build_stone` | 石墙、石路、石制设施等成功放置 |
| `sfx_build_soft` | 草席、睡袋、地毯等放置 |
| `sfx_demolish_hit` | 锤子每次有效拆除命中 |
| `sfx_demolish_break` | 建筑最终拆除、返还材料 |
| `sfx_door_open` | 石墙门、栅栏门打开成功 |
| `sfx_door_close` | 门关闭成功 |
| `sfx_chest_open` | 木箱打开 |
| `sfx_chest_close` | 木箱关闭 |
| `sfx_fridge_open` | 冰箱打开 |
| `sfx_fridge_close` | 冰箱关闭 |

## 料理与工业

| 事件 ID | 声音需求 |
|---|---|
| `sfx_craft_complete` | 徒手、工具台、金属工具台制作成功 |
| `sfx_craft_work` | 有制作进度时的短劳动表现 |
| `sfx_fire_ignite` | 篝火、熔炉、烤箱点火成功 |
| `sfx_fire_extinguish` | 主动熄火或燃料耗尽 |
| `amb_campfire_loop` | 点燃且靠近篝火 |
| `sfx_fuel_add` | 篝火、熔炉、烤箱成功加燃料 |
| `amb_furnace_loop` | 熔炉燃烧、玩家靠近 |
| `amb_oven_loop` | 铜烤箱燃烧、玩家靠近 |
| `sfx_cook_start` | 篝火或烤箱成功提交料理 |
| `sfx_process_ready` | 料理或工业产物刚完成、可领取 |
| `sfx_product_collect` | 成功领取料理、炉内产物 |
| `sfx_lantern_on` | 提灯、银提灯或铜立灯成功开启 |
| `sfx_lantern_off` | 灯具关闭或耗尽 |

## 种植

| 事件 ID | 声音需求 |
|---|---|
| `sfx_till_soil` | 石镐开垦、耕地成功生成 |
| `sfx_seed_sow` | 种子选择后成功播种 |
| `sfx_crop_harvest` | 成熟作物成功收获 |

## 动物

| 事件 ID | 声音需求 |
|---|---|
| `sfx_chicken_idle` | 附近鸡偶尔叫 |
| `sfx_sheep_idle` | 附近羊偶尔叫 |
| `sfx_animal_feed` | 拖食物给动物并成功投喂 |
| `sfx_shear` | 剪毛有效动作 |
| `sfx_trough_add` | 饲料槽成功补料 |
| `sfx_animal_ack` | 驯养动物切换跟随／留守 |

## 食用与睡眠

| 事件 ID | 声音需求 |
|---|---|
| `sfx_eat` | 真正成功食用一份食物 |
| `sfx_sleep_enter` | 成功进入床、草席或睡袋睡眠 |
| `sfx_sleep_exit` | 按 E 醒来、退出睡眠 |

## 天气与环境

| 事件 ID | 声音需求 |
|---|---|
| `amb_rain_light_loop` | 小雨天气随雨量淡入 |
| `amb_rain_storm_loop` | 雷暴雨随雨量增强 |
| `sfx_thunder` | 雷暴闪电对应的雷声 |
| `amb_wind_soft_loop` | 晴天野外的低层环境底声 |
| `amb_forest_day_loop` | 白天森林附近 |
| `amb_night_loop` | 夜晚环境 |
| `amb_water_stream_loop` | 靠近河流 |
| `amb_water_shore_loop` | 靠近湖岸／海岸 |

## 钓鱼

| 事件 ID | 声音需求 |
|---|---|
| `sfx_fishing_cast` | 钓鱼抛竿 |
| `sfx_fishing_bite` | 鱼咬钩 |
| `sfx_fishing_success` | 钓鱼成功 |
| `sfx_fishing_failure` | 钓鱼失败 |

## 交易

| 事件 ID | 声音需求 |
|---|---|
| `sfx_merchant_trade` | 商人交易成功 |

## 种植

| 事件 ID | 声音需求 |
|---|---|
| `sfx_crop_fertilize` | 施肥成功 |

## 料理与工业

| 事件 ID | 声音需求 |
|---|---|
| `sfx_compost_add` | 堆肥投料 |
| `sfx_smoker_start` | 熏制开始 |

## 营地建造

| 事件 ID | 声音需求 |
|---|---|
| `sfx_build_repair` | 维修建筑 |
