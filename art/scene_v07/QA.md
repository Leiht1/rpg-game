# V0.7 素材与视觉检查

生成：generate2dsprite → route_media.py → local:codex-cli / codex-image_gen；art_source=host_image。实际底层模型版本及费用未知，estimateUsd=0仅订阅调用估计。原图、逐字提示词、真实参考sha256和回执分别保存在ground、props、ground-clean/job.json。

原图警告（不作全部QC通过声明）：
- raw_sheet: requested equal grid not respected; manual ownership rectangles required
- raw_sheet: colored translucent glow; alpha<210 discarded during cleanup

处理：原图为真实RGBA，但带低透明度彩色雾边。按物件所有权手工矩形裁切，保留花叶和小石独立部分，alpha<210清理；预乘透明LANCZOS等比缩放到原画布，底部居中。未强行使用网格裁切，未用最大连通域丢弃装饰。

首版地面草形标记偏多，因此拒绝作为最终地面；定向编辑删除草形并减弱连续笔触，源图仍保留。

Godot真实出生点渲染1280×720，Seed271828；同镜头before/after。检查树石位置/画布/ID、角色出生点保持及静态预览关闭角色物理更新。主游戏文件哈希对照见review.json。未做无关全量回归、性能测量或世界纹理平铺承诺。新图具体视觉结果pending_user。
