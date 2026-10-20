# 低马尾侧视后脑补齐 V3

2026-10-20。只调整低马尾侧面发带上方后脑覆盖，其他发型/正背视图、刘海、发带与马尾保持。左右共用原镜像，当前新图仍为候选。

当前贴图：`prototypes/ponytail-side-v3/female_ponytail-side.png`；原catalog只更新 `hair.female_ponytail.side.front`。原25张V2 PNG逐一SHA核对不变；没有改角色代码、骨骼、动画、物品或玩家存档。

generate2dsprite → route_media → Codex（本地CLI）完成一次真实局部编辑；软抠后仅将生成补片按原头部alpha合成到旧发型下方，区域外原RGBA与全部原不透明发型像素逐像素保持相同。限定后脑区域可见露肤像素由62降至0。生成/注册与SHA在 [provenance](../../art/ponytail-side-v3/provenance.json)、[注册脚本](../../art/ponytail-side-v3/register.py)。模型回执codex-image_gen，精确修订与额度折算费用未知。

最终默认1280×720 Godot4.7.2窗口左右×6肤色及无建档副作用等25项0失败，[窗口结果](checks.json)；素材4项0失败，[素材结果](../../art/ponytail-side-v3/qa.json)。原始生成处理结构QA为pass。初次局部合成的区域外透明RGB有3153像素变化（非零阈值0，FAIL），已恢复原RGBA；[初始记录](../../art/ponytail-side-v3/qa-initial.json)保留，当前最终结果4项全过。

[左侧实际界面](left-corrected.png) · [右侧实际界面](right-corrected.png)。窗口测试无错误/退出警告；未重复世界/完整角色回归、多分辨率或长期试玩，不将其他美术记为已确认。

`before-composite.png` 是生成任务实际引用的来源参考，须长期保留；其他本轮窗口图保留到用户确认。未提交推送。
