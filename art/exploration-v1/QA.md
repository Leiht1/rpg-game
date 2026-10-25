# 本轮静态素材检查

生成路线：generate2dsprite → host_image/image_gen。具体底层模型、费用未公开；无 API key 或视频生成。原图 `source.png` 为1774×887，并未遵循提示词的等分单元。

原图按1×2网格检查失败，不能直接按887列等分裁切。`raw-qc/sheet-qc.json` 的全部非通过项如下，保留原始报告，不改写为通过：

| ID | 状态 | value | threshold | 文件 |
|---|---|---|---|---|
| cross_cell_components | fail | 1 | 0 | raw-qc/sheet-qc.json |
| cross_cell_visible | fail | 1 | 0 | raw-qc/sheet-qc.json |
| boundary_band | warn | 4371 | 0 | raw-qc/sheet-qc.json |
| safe_frame | warn | 2 | 0 | raw-qc/sheet-qc.json |
| faint_specks | warn | floor_px=25619, detached_components=18 | 0 | raw-qc/sheet-qc.json |

处理采用x=1000的物体所有权边界，保留遗骸完整四肢和瓶子，不采用最大连通块删除散落骨/石。随后分别通过 generate2dsprite single/native_alpha/both：清理低透明度雾点和脱离主体的弱透明残留，完整部件等比整理到512×512。原始所有权裁片保留在各 `*-clean/raw.png`，最终运行使用 `*-clean/clean.png` 的原字节副本。

两个最终处理报告均为 `qa.status=pass`，空帧、裁切夹断、输出触边、来源实体触边均为空数组；单张静态图的动作尺度/锚点方差指标明确 skipped。这里的结构通过不替代画风、解剖或主观美术确认。

本轮实际1280×720游戏窗口核对了88单位宽遗骸与原角色、背包/纸片/湖岸木牌，以及原库存/收获动画中的瓶子。最终效果截图暂存 `reports/exploration-v1`，用户尚未确认，暂不清理。尚未做其他生态、多分辨率或其他Seed的主观美术验收。

环境检查见doctor.json：Python PATH指向系统占位入口、缺少可选scipy/resvg及其他媒体路线的提醒留档；本轮明确使用内置Python、Pillow/numpy与host_image，不宣称全部工具环境无警告。
