# 睡眠被沿与滚轮缩放 V8

缩短横木床、横草席与竖草席的被子靠头一端，自然浅弧被沿衔接下巴。橙床被、米白草席被继续各自材质；用户认可的竖木床V6及睡袋V5保持，头锚点保持。新三候选由generate2dsprite→route_media→Codex(local CLI)实际生成，完整原图/提示词/回执在art/sleep-occupied-v8；透明PNG、等比注册及SHA在prototypes/sleep-occupied-v8/provenance.json。原图三件不均分行，使用明确所有权边界0/480/800/1536重排保留完整轮廓，没有截成矩形被面。软抠结构QA pass，仍pending_user，未推广正式资源。

睡眠滚轮失效来自ItemUI睡眠拦截及Player动作门禁。现在睡眠期间直接调用与普通游玩共用的zoom_from_wheel，只调整相机；原每档1.1、范围0.65–1.65不变。仍仅E手动醒来，移动/Shift保持锁定，头/被面静止，仅zzz漂浮。

Godot4.7.2实际窗口76项0失败，window.log无脚本错误。五设施/方向均验证真实滚轮放大/缩小、上下限、不醒来及不解锁动作，兼顾E醒来/睡袋移除、静态画面/zzz运动；截图均在项目默认1280×720，不切换分辨率。未重复全量功能/存档回归或长期人工测试，原玩家存档未写入。

入口Start-Sleep-Facilities-Preview.cmd，预览窗口已打开的旧进程需要重新打开该入口才会读取最新脚本与候选。
