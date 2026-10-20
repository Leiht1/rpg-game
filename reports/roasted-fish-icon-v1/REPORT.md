# 烤鱼图标候选 V1 · 2026-10-20

用户指出烤鱼仍显示烤蘑菇。本轮仅补一张专属烤鱼候选，不扩展其他料理或逻辑。

来源：generate2dsprite → generate2dmedia route_media → Codex (local CLI)，实际模型标识 codex-image_gen，底层图片模型与实际费用未披露。原图、提示词、合同与回执：art/roasted-fish-icon-v1；候选与SHA：prototypes/roasted-fish-icon-v1/provenance.json。

最终候选 final/roasted_fish.png：256×256 RGBA，内容框(16,61)-(240,195)，四边有安全留白。软抠洋红底、Lanczos保持比例、保留全部连通组件。processed-256/pipeline-meta.json结构QA通过：无空帧、无输出裁切、无源图触边、无不透明键色残留、边缘键色比例0。首次处理工具默认128格，随后明确cell-size256重新处理；128版仅保留过程追溯。人工查看原图、透明成图及18/32/48像素暖纸底对照，轮廓可辨，金黄烤纹鱼形清楚。小尺寸仍有较细的高光笔触，主观审美等待用户确认，结构QA不等于美术批准。

状态pending_user。未覆盖正式素材，未修改data/items.json、物品逻辑或玩家存档。未做游戏原生场景验收或料理回归（本轮无运行代码变更）。确认后按原SHA迁入正式目录，再核对背包、食谱和地面显示。

size-review.png是来源记录引用的候选验收图，确认后仍按来源基准保留。
