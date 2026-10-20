# 烤鱼图标正式接入 · 2026-10-20

用户批准原话：“确认，可以替换”。将prototypes/roasted-fish-icon-v1/final/roasted_fish.png逐字节复制到assets/cooking/fish-v1，SHA256 e3ff79edf6cab95231edb588c8f6119e44ac48c5d98cee6be17cdb7c2b153700。正式provenance保留生成来源、候选、结构QA、授权范围，候选来源状态同步为approved_and_integrated。未重新生成或修改获准图片。

仅修改data/items.json中roasted_fish的icon与world_visual两条路径。原ID、配方、食用/腐坏规则及存档格式保持；普通入口无需预览开关，已有库存自动按原ID显示新图。腐坏烤鱼专属图和鱼汤专属图不在本次确认范围，仍保留原复用表现。

Godot4.7.2资源导入成功。默认1280×720原生窗口tests/test_roasted_fish_formal_v1.gd共5项0失败：正式两路径、批准SHA、背包/世界/掉落纹理加载、无预览模式、烤鱼食谱卡图标。checks.json留档。测试使用persistent_world=false隔离世界，无玩家存档读写、无测试物品投放。未重复料理逻辑或全量回归；未做长期人工试玩。没有新增候选图，原size-review.png是来源保留基准，不属于待清理临时截图。本次未产生临时截图。未提交或推送。
