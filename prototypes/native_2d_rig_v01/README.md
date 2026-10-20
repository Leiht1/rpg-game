# 《风栖原野》原生 2D 骨骼独立原型 v01

这是待验收的技术与美术实验。**动作、换装复用已验证；视觉仍未达到已确认 v11，不建议直接替换正式主角。** 详细判断见 [REPORT.md](REPORT.md)。

## 运行和预览

- 双击 `RunPreview.bat`，运行 Godot 原生对比场景；本机已配置 Godot 4.7.2 路径。
- 双击 `OpenEditor.bat`，或用 Godot 4.7.2 导入本目录的 `project.godot`，再运行 `preview.tscn`。
- 双击 `preview.html` 可离线查看对比，无需安装依赖。网页使用真实 Godot 渲染的 64 个相位采样；它是方便验收的播放器。可编辑骨骼、网格和关键帧保存在 Godot 工程。
- `evidence/walk_comparison.webp`、`breathe_comparison.webp`、`wave_comparison.webp` 是原版、原上衣骨骼、换上衣骨骼三列动图；`walk_contact.png` 可逐姿势检查。

换到其他电脑时，用 Godot 4.7.2 打开本目录工程即可。启动脚本也支持环境变量 `GODOT_BIN`、本目录内的 Godot 程序或 PATH 中的 `godot`。交付不包含引擎安装包。

## 观察操作

| 操作 | 控件或快捷键 |
| --- | --- |
| 行走 / 呼吸 / 挥手 | 动作选择框，或 `1 / 2 / 3` |
| 切换两件上衣 | 上衣选择框，或 `C` |
| 显示 / 隐藏真实骨骼 | 复选框，或 `B` |
| 左侧镜像 | 镜像复选框 |
| 正常 / 慢速 / 半速 | 速度选择框，`1× / 0.25× / 0.5×` |
| 暂停 / 继续 | 按钮，或空格 |
| 按相位前后步进 | 按钮，或 `← / →`，每次 `1/64` 周期 |
| 任意相位 | 拖动底部滑条；自动暂停 |
| 调整行走周期 | 行走周期数值，`0.35～1.2` 秒；默认 `8/13.8 ≈ 0.579710` 秒 |

两侧共享相位和脚底参考 `(64,112)`，源画布均为 `128×128`。提供放大和 `1:1` 显示。v11 没有挥手素材，挥手模式左侧明确保持原版待机第 0 帧。

网页按 128 像素原生 GPU 输出播放，Godot 放大视图则直接渲染高分辨率网格贴图；放大后的清晰度会有差别，应结合两个 `1:1` 视图判断。网页在修改 Godot 资源后不会自动更新，需要重新运行捕获和包装工具。

## 编辑骨架与动作

打开 `hero_rig.tscn`：

1. `Skeleton2D` 下有 18 个 `Bone2D`：骨盆、脊柱、胸、颈、头、围巾，以及近远侧双臂和双腿。近侧是画面前方的右臂/右腿。
2. `Meshes` 下有 16 个 `Polygon2D`。选中网格后，可在 Godot 的 UV / Polygon 编辑器中修改顶点、三角形和骨骼权重。手臂和腿的关节由连续网格的多骨权重过渡，袖子也绑定同一手臂链。
3. 选中 `AnimationPlayer`，编辑 `walk`、`breathe`、`wave`；`RESET` 保存中性姿势。动画只包含骨骼的变换轨道，没有逐帧贴图切换。可直接播放原生动画时间轴。
4. 根节点 `Outfit` 属性切换上衣；只是切换衣服网格可见性，不换动画资源。`Show Bones` 显示实际骨骼。
5. 新增动作可复制现有动画、调整骨骼关键帧。保留完整的初始化轨道，避免动作切换残留上一姿势。动作超出现有手型或视角时仍可能需要补图。

本轮起步动作由离线工具烘焙为原生关键帧，行走/挥手每周期 64 个采样间隔、呼吸 32 个；可编辑，但关键帧较密。它不是已经整理好的低关键帧动画师模板。不要在手动编辑后直接重跑 `source/build_rig.py`，该工具会覆盖角色场景与部件输出。

## 隔离与文件

此目录是独立 Godot 工程，无正式游戏资源路径依赖。`reference/` 是正式侧向八帧行走和四帧呼吸的字节一致副本。父目录 `prototypes/.gdignore` 防止主游戏导入实验资源。

| 文件 | 用途 |
| --- | --- |
| `hero_rig.tscn` | 可编辑骨架、权重网格、三种原生动画及 RESET |
| `rig.gd` / `bone_overlay.gd` | 上衣显隐及真实骨骼叠加 |
| `preview.tscn` / `preview.gd` | 原版与骨骼同步对比 |
| `art/` | 新绘完整中性部件及参考小人；参考小人未拆解使用 |
| `source/generated/generated.png` | 本轮唯一一次生成的原始中性部件图 |
| `source/art_prompt.txt` / `PROVENANCE.md` | 完整提示词、来源与费用边界 |
| `source/plan.json` / `master.json` | 实验计划、参考与生成路线记录 |
| `source/build_rig.py` | 离线部件整理、绑定与关键帧起步工具 |
| `capture.gd` / `source/package_preview.py` | 从真实 Godot 渲染制作网页与动图 |
| `verify.gd` / `evidence/` | 本轮专项验证、实际渲染和检查报告 |

运行只需 Godot。离线重建工具使用本机已有 Python、Pillow、NumPy、SciPy；未安装新依赖。原始工程保留全部逐相位 PNG；压缩交付包省略这些可重建中间帧和引擎缓存。已用无缓存的独立副本完成首次导入与主预览启动检查。

## 复核命令

在本目录运行；`<Godot>` 替换为 Godot 4.7.2 可执行程序：

```text
<Godot> --headless --path . --script res://verify.gd
<Godot> --path . --script res://capture.gd --rendering-method gl_compatibility --disable-vsync --resolution 1200x800
python source/package_preview.py
```

第一条只测原型。第二条需要实际图形设备。第三条以第二条产生的原生 RGBA 渲染为输入。运行原型无需执行这些工具。

本轮已停止，不接入正式游戏，等待用户验收。
