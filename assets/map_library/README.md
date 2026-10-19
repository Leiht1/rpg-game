# 地图素材库 V0.1

本库按区域组织，PNG仍引用已确认的 stylized_v3，避免复制后漂移。`catalog.json`为素材槽位登记；shared_approved表示复用已确认美术，planned表示尚未制作。缩小现有树不能算新增小树，缩小石头不能算独立小石轮廓。

```
assets/map_library/
  catalog.json
  spawn_meadow/ forest/ highland/ shore/ open_field/
    ground/       base variation sparse edge
    plants/       tree_large tree_small shrub undergrowth accent
    rocks/        large medium small silhouette_variant
    props/        branch stump log pebbles leaf_pile flowers
    transitions/  meadow_forest meadow_highland meadow_shore forest_clearing scree
```

每个区域都建有以上五类目录。命名：`区域__类别__用途__v版本`，如 `forest__plants__shrub__v01`；后续独立画稿增加 `_a/_b` 轮廓编号。地面/边缘采用世界坐标与软遮罩；物件底部中心锚定，保持源图比例。每个新素材须登记来源、生成提示词、引用图哈希、route、整理参数和用户验收状态后才可推广。

当前可用：自然绿主地表、两树、两石、三件花叶点缀。其余类别是生产清单，尤其灌木、倒木、木桩、枯枝、岸生植物、专用碎石和过渡地表尚缺独立画稿。本轮 art_source=existing，无图片生成；原生成路线与整理警告保留在 art/scene_v07，不把规划槽位当成完成品。
