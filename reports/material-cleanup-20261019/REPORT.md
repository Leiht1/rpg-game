# 素材整理与工程同步

2026-10-19，用户授权“更新开发日志，整理一下素材，明确弃用的直接删掉，然后将项目推送到远端”。

## 分类与删除

- assets/为正式运行资源；art/为生成提示词、回执、参考与来源；prototypes/为独立候选/历史预览；reports/保留已运行测试证据。来源或候选曾用于正式获批图时不因运行路径已迁移而当作废图删除。
- UI_ART.md“失败诊断”明确否定第一版厚木框和第二版无材质框，本次删除assets/ui/v1的panel/button/slot及assets/ui/v2的panel/button/slot/hotbar，共7张PNG及7个配套.import。逐文件SHA、大小、理由见deleted-assets.json。删除前逐一验证scripts/scenes/data/tests/prototypes无这些资源路径引用。
- 保留仍由data/items.json引用的assets/ui/v1/field_lantern.png及其导入、来源记录；当前rework_v1/refine_v1/hints_v1/body资源保持。其余未确认废弃的历史样稿、获批源图与报告不擅删。
- 原UI打包工具只作历史生产记录，运行入口不调用；它们仍记录旧目标路径，不重新运行来复活已弃用框图。

## 同步范围与验证

同步自上次远端提交以来当前工程的正式玩法、资源、规范、开发日志、工具及测试报告。缓存.godot、.forge、临时文件与Python缓存沿用.gitignore排除，不纳入提交。不改变功能、玩家存档或原素材布局。

本轮删除路径引用检查通过；Godot4.7.2项目导入成功；默认1280×720原生窗口tests/test_chest_ui_v2.gd实际20项0失败。提交前未跟踪/已跟踪文本与常见凭据文件名检查无命中；最大待提交单文件未超过40MiB。未重复无关玩法全量回归。提交/推送状态以本轮交付的远端校验为准。
