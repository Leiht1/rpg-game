# 主角一致性修订 v04：待用户预览

本轮交付完整眼型、头部摆正、呼吸/行走比例与配色对照，以及侧面小步幅候选。**仅预览，没有替换游戏。** 当前运行仍是 Godot 4.7.2 / windrest-character-template-3 / 100 px/s / 原 3 秒呼吸。

## 内容与预览

- front/back/right 各自制作完整呼吸和行走；left 由 right 整帧镜像，时间顺序不反转。四方向各 4 idle + 8 walk，预览导出共 48 张 128×128 RGBA，统一根点 (64,112)。实际独立原画为 36 帧。
- 呼吸改为每帧 450 ms、4 帧 1.8 秒，旧版为 750 ms / 3 秒。walk 保持 12 FPS / 8 帧，60 Hz 每帧 5 ticks，工具输出周期 667 ms；GIF 的 10 ms 时间粒度为 670 ms，无损 WebP 为 667 ms。
- 行走先改完整眼睛及头部朝向，再以新行走完整人物生成对应呼吸。正面眼线水平；侧面保留完整可见眼型、水平视线及自然颈部；背面维持无脸的后视图。早期 hero-a 只用于眼白、棕色虹膜/瞳孔和小高光的参考。
- 各动作按方向共用一个等比尺度，人物可见高度中位数约 92 px。实际 idle 可见高度 front=92～93、back=92、side=93 px；walk=91～93 px，不能据此宣称每处头身比例完全一致。衣服、头发和靴子直接以新 walk 的色彩为生成基准，没有代码局部改色。
- 侧面保留交替腿和双臂跟随，收小前后跨步。y=99～113 的鞋部 alpha 总包络最大跨度由 64 px 降至 50 px（约 21.9%）；该值包含鞋形及遮挡，不等于解剖脚踝摆幅。

主要文件：`idle_walk_switch.gif/.webp` 为四方向走停对照，`four_directions_idle.gif/.webp` 为 1.8 秒呼吸，`side_walk_before_after.gif/.webp` 为同速步幅对照；`scale_eyes_head_comparison.png` 包含旧新全身与游戏原尺寸，`all_frames_contact.png` 包含所有帧编号。

## 实际流程与选择

按项目 CHARACTER_SEQUENCE_WORKFLOW.md，使用 generate2dsprite / generate2dmedia 来源管理、Gorest 原图网格检测、同尺度与整帧刚性注册、skill clip 打包和网页实际预览。没有图生视频、肢体拼接、局部绘画/变形、头脚剪贴冻结或逐帧按包围盒缩放。

内置 image_gen 完成 8 次图片编辑：front/back/side walk 各 1 次，三方向 breathe 各 1 次，front/side breathe 各追加整身修订 1 次。另有用户补充头部要求前中断的 1 次调用，未收录其输出，不能算作完成生成。底层模型与实际费用未公开；adopt 的估算不代表图片生成账单。提示词、引用图、原图、job、哈希和注册变换保留，详见 provenance.json。

最终选择 walk 三套 take1；breathe front/back take1、side take2。front breathe take2 的静止区域估计残差 0.852 px，比 take1 的 0.766 px 更大，未选用；保留候选及首轮 clips_take1，不宣称该次修订改善稳定性。侧面估计残差 0.652→0.599 px，仅小幅改善。

## 验证与边界

- 48 张 PNG 的 RGBA/画布/透明边界、图集裁片回读、工具字节复制、左右镜像、8 个动画时间轴及 WebP 像素回读检查通过。60 个原运行资源、脚本、场景及配置哈希保持不变。verification.json 保留完整结果。
- skill 最终 clips_final 为 8 clips / 48 frames / warnings=0，仍是 needs-visual-review；loop_seam 最大 wrap_ratio=1.577771，完整检查 id/value/threshold/file 保存在 qc_nonpass.json。没有把数字检查当作美术验收。
- 静止头部/下肢匹配估计最大残差 front=0.766、back=0.030、left/right=0.599 px。正/侧后两帧仍有亚像素的头脚相对重绘变化；少量服装、鞋形、头发轮廓和颜色变化仍存在。未承诺零漂移、完美同色或发行级平滑；四帧呼吸阶段感及八帧侧向近远腿变化需要用户实际判断。
- Gorest 新增 8 条 v04、confirmed=false，资产总数 49→57。旧 49 条素材、顺序和其他场景/配置数据保持不变，首份素材库备份及变更报告保留。实际检查四方向网格和画布、正面与侧面呼吸暂停逐帧、侧面行走两个半周期和恢复播放；截图及 browser_review.json 留存。
- 此次只改美术候选、Gorest 预览数据和记录；没有修改网页应用代码，因此未重跑其全量构建。没有替换 Godot 运行资源或执行新素材的游戏内走停测试，没有本轮游戏性能数据。用户预览确认后再单独接入，本轮停止。
