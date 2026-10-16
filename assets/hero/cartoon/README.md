# 当前正式卡通玩家
2026-10-16：已确认V4短腿、白衣身与背面，九张角色部件图片原样复用。当前15条原生AnimationPlayer动画：front/back/side 的 breathe/walk/run/chop/pickup，左向镜像。128画布、脚下(64,112)、六支点，袖和裤管随肢体运动。
新斧来自 assets/environment/cartoon_v2/axe.png，不使用实验道具。世界树与木材独立于角色；Grip 是工具挂点，运行时 CarryWood 随手部显示拾取反馈。人物动作保留实验中已确认轨迹，原素材及来源仍在 prototypes/cartoon_rig_v1_r4 和 art/cartoon_rig_simple_v3。
实际位移推进走跑共享相位，walk200px/s，run310px/s，128px/周期；chop1.65s、pickup2.2s，命中/接触仅执行一次。脚下圆半径10，景物使用独立六点凸碰撞。没有换装或背包系统。
规范见根目录ART_STYLE.md、CHARACTER_SEQUENCE_WORKFLOW.md、CHARACTER_MODULAR_RULES.md。当前测试见tests/test_scene_cartoon.gd，旧六动画测试为历史接口。
