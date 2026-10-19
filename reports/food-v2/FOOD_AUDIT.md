# 正式食物与获取途径审计

2026-10-19。以本轮修改后的正式数据库为准；实际库存食用路径逐项验证。未点名的现有收益保持数据库值。

| 物品ID | 名称 | 饥饿 | 正常来源 |
|---|---|---:|---|
| wild_berry | 野生浆果 | 2 | 野外浆果采集 |
| brown_mushroom | 野生蘑菇 | 2 | 森林/水岸自然散落，E拾取；复用原ID及画稿 |
| wild_carrot | 野胡萝卜 | 2 | 野外植株采集或耕地收获 |
| wild_apple | 野苹果 | 3 | 既有落果来源树附近地面拾取 |
| wildflower | 野花 | 1 | 野外花丛采集 |
| roasted_carrot | 烤胡萝卜 | 6 | 篝火 roast_carrot：wild_carrot×1 |
| roasted_mushroom | 烤蘑菇 | 7 | 篝火 roast_mushroom：brown_mushroom×1 |
| herb_roasted_mushroom | 香草蘑菇 | 10 | 篝火 herb_mushroom：broad_leaf×2、brown_mushroom×1 |
| roasted_fruit_platter | 野果混合烤盘 | 36 | 篝火 fruit_platter：wild_berry×2、wild_apple×1、wildflower×1 |
| field_harvest_platter | 原野丰收烤盘 | 40 | 篝火 harvest_platter：wild_carrot×1、brown_mushroom×1、wild_berry×1、wildflower×1 |
| potato | 土豆 | 5 | 野外留种后种植收获 |
| cabbage | 卷心菜 | 6 | 野外留种后种植收获 |
| roasted_potato | 烤土豆 | 12 | 篝火 roast_potato：potato×1 |
| roasted_cabbage | 烤卷心菜 | 16 | 篝火 roast_cabbage：cabbage×1 |
| vegetable_soup | 蔬菜汤 | 24 | 篝火 vegetable_soup：wild_carrot×1、cabbage×1 |
| stewed_vegetables | 炖杂蔬 | 36 | 篝火 stew_vegetables：wild_carrot×1、potato×1、cabbage×1 |

全部16种食物仅恢复饥饿；生蘑菇另启动致幻，无即时扣血。原野果/丰收拼盘36/40、土豆5、卷心菜6保留现值。宽叶broad_leaf是既有森林采集物，沿用正式素材及库存ID。原单蘑菇配方曾仅允许完成旧已付料任务，本轮恢复新制作，解决烤蘑菇获取缺口。

野外种子仍由wild_carrot/wildflower/plant_fiber成功采集的稳定ID派生，不重复奖励；土豆/卷心菜不虚构额外自然产物。苹果仍依赖原落果来源树，不新增树种。
