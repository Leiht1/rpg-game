# 风栖原野音效配置工作台

双击项目根目录 `Start-Audio-Workbench.cmd`，或 `dist/WindrestAudioWorkbench/WindrestAudioWorkbench.exe`。可执行版本无需安装 Python；移动时必须保留整个 WindrestAudioWorkbench 文件夹。源码入口 `Start.ps1`，打包入口 `Build.ps1`。

1. 左侧选动作，右侧选择任意素材文件夹（递归扫描，可取消）。
2. 点击 ▶ 试听，空格播放/暂停，上下键选择行；进度条拖动定位，右侧调试听音量。
3. 勾选音效，可随时切换素材包；“已选 / 扫描列表”查看跨文件夹候选并取消勾选。
4. 选择输出目录，点击“确认应用”。只有成功导出才计入本轮完成进度。

所有事件重新选择，已有素材不算本轮完成。走/跑共用已实现的四类地面声音；不新增游泳、战斗等未实现功能。现有素材保留作状态参考，不自动加入候选。脚步不会被工作台重新启用。

状态：○ 未导出，✓ 已确认且文件校验正常，◐ 候选已修改待重新确认，⚠ 输出丢失或校验变化。“检查导出”重新核对 SHA256。原素材丢失不影响已导出状态；重新导出仍要求原素材存在。输出异常不会自动覆盖被外部修改的同名文件，需换输出目录或先由用户处理冲突文件。

支持 WAV、MP3、OGG、FLAC 试听。前三者原样复制，FLAC 使用 libsndfile 流式转换为 PCM16 WAV；不伪改扩展名。文件名为 `事件ID_稳定编号_来源哈希前10位.扩展名`，便于防冲突；输出在 `输出目录/selected/类别/事件ID/`。编号一经导出复用，删除变体后不挪动其他编号。重配置只清理当前事件、当前目录、校验仍匹配的旧导出；其他事件和手动修改的文件保留。

输出目录中的 `audio-workbench-manifest.json` 包含来源、输出、格式、变体及源/输出 SHA256；`binding_status=exported_only` 明确表示尚未接入游戏。程序不修改 `data/audio.json`、游戏逻辑、正式素材或玩家存档。

工作进度在 `%LOCALAPPDATA%/WindrestAudioWorkbench/state.json`，扫描错误同目录 `scan-errors.json`。保存候选、上次动作、素材目录历史、输出路径、搜索/时长条件、音量。迁移电脑可复制此目录；源路径变化需重新选择文件，原导出不受影响。

“同步事件”读取 `events.json` 和当前 `data/audio.json`、相关声音调用；保留现有选择。新玩法尚无声音调用时在 `events.json` 新增稳定 ID、中文名、类别、output_group、evidence，即可同步显示，无需改界面。已存在的纯声音调用可自动补列，未命名事件归“待命名”。工具无法从任意新玩法代码自动判断它是否应当有声音。`build_catalog.py` 是首次重建辅助脚本，依据历史收集表及当前已核对实现生成清单；维护过 events.json 后不要用它覆盖人工补充。

源码测试：`python test_workbench.py`；Godot 隔离导入测试：`python verify_godot.py`（默认 D:/Godot/Godot_v4.7.2-stable_win64.exe）；打包后测试：`WindrestAudioWorkbench.exe --self-test`。测试输出目录为临时目录，不写玩家存档。

试听使用 Qt 自带 FFmpeg 后端，发布目录含所需 DLL，不依赖系统 ffmpeg.exe；打包脚本排除共享 Python 环境误收集的 ICU78 副本，使用现代 Windows 系统 ICU。扫描仅读取头信息，不将全部音频解码到内存；试听由播放器按需解码。导出和手动完整校验是同步操作，超大单文件可能短暂等待；取消扫描在当前文件头读取完成后生效。导出采用原子清单提交和失败回滚，不提供跨断电事务恢复；导出时不要强制结束进程。
