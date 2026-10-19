# 地表 V0.3 来源与质量记录

实际生成 2 次；route `local:codex-cli`，requested model `codex-image_gen`，art_source `host_image`。底层精确图片模型及实际费用未知。回执 estimateUsd=0 表示订阅额度无逐次报价，不代表确认零成本。无第三方美术。

第一张源图 1536×1024 RGBA，3×2 地表图集；第二张实际返回 1254×1254 RGB 连续草面，缩放整理为1024×1024。提示词、参考哈希和真实回执见 generated/、grass_generated/ 及相邻 prompt 文件。

原图检查警告完整保留：
- `boundary_band`: value=120, threshold=0; file=`generated/generated.png`; solid pixels within 10 px of a cell line; a different crop or rounding can cut them
- `safe_frame`: value=6, threshold=0; file=`generated/generated.png`; owned art closer than 15% of the cell to its edge; ask for more margin next time
- `faint_specks`: value={"floor_px": 102616, "detached_components": 23}, threshold=0; file=`generated/generated.png`; alpha haze and detached specks; process removes them with --alpha-hygiene both

整理使用 generate2dsprite process / native_alpha / alpha-hygiene both / alpha-floor 8 / registered / center(256,256) / 512px。保留全部独立草叶，不使用最大连通域删除。六件保持统一等比缩放与中心注册，重新拼入同一1536×1024图集。整理器 qa_status=pass；此结果不覆盖原图 safe_frame 等警告，不代表用户美术验收。

游戏内显示宽度约115–370世界像素，实际画面检查草原/林地/山地/水岸及透明边。连续草面以世界坐标镜像寻址保证贴图边缘连续，生物群系仍采用真实生成场。局部图集按Seed和地形稳定分布，每区块一个Canvas，共享图集；地表不附加碰撞。浅水坑是可踩过的装饰积水，不是新增湖泊或采集种类。

边界：只有6种地表图案，长距离仍可能辨认复用；落叶和小碎石属于平面装饰。水岸贴片采用九点保守排除，不等同逐像素水域遮罩。用户最终视觉验收待定。