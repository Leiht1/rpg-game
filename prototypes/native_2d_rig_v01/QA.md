# 检查结果与保留问题

## 本轮原型

原生专项为 pass / 0 failures；GPU 渲染已完成，脚部像素、画布边界、原版副本、正式文件保护检查为 pass。详见 `evidence/native_tests.json`、`delivery_checks.json` 及 `REPORT.md`。这些检查不批准美术品质，最终状态是 **needs-user-visual-review / v11 quality not reached**。

可移植副本的无缓存首次导入和主预览启动通过，无资源/脚本错误；见 `evidence/release_import.log`、`release_run.log` 及 `release_checks.json`。压缩包 CRC 校验通过，逐相位中间帧仍保留在原始目录。

已知视觉问题：身份与轮廓不完全一致、躯干偏窄、膝部纸片感、裤腿体积不足、步态偏规则、挥手没有专门的手形变化。全部保留实际输出，不用数值通过掩盖这些问题。

## 生成工具环境诊断

`source/doctor.json` 的 `overall` 是 `WARN`。下表逐字保留全部 WARN 及 MISSING 的 id / status / detail；该报告没有数值 threshold，故 threshold 均为“不适用”。没有 FAIL 项。它是生成工具环境诊断，不是 Godot 原型动作检查。

| id | status | detail（原文） | threshold | 文件 |
| --- | --- | --- | --- | --- |
| python.path | WARN | other python.exe on PATH: ~/AppData/Local/Microsoft/WindowsApps/python.exe | 不适用 | source/doctor.json |
| paths.cwd | WARN | the working folder has spaces or non-ASCII characters | 不适用 | source/doctor.json |
| deps.resvg-py | MISSING | not installed; needed for codeart2d SVG rendering (PixelSpec needs only numpy and Pillow) | 不适用 | source/doctor.json |
| media.api.openai | MISSING | OPENAI_API_KEY is not configured | 不适用 | source/doctor.json |
| media.api.gemini | MISSING | GOOGLE_API_KEY or GEMINI_API_KEY is not configured | 不适用 | source/doctor.json |
| media.api.xai | MISSING | XAI_API_KEY is not configured | 不适用 | source/doctor.json |
| media.api.byteplus | MISSING | ARK_API_KEY is not configured | 不适用 | source/doctor.json |
| media.api.fal | MISSING | FAL_KEY is not configured | 不适用 | source/doctor.json |
| cli.grok | MISSING | Grok Build CLI not found on PATH or in $GROK_HOME/bin | 不适用 | source/doctor.json |

处理方式：始终使用已验证的 Python 3.12 绝对路径并正确引用中文路径；生成使用已可用的宿主 image_gen。未使用 SVG 渲染、外部 API 或 Grok CLI，不安装无关依赖。诊断中视频路线不可用与本任务无关，本轮所有动作均由原生骨骼完成，未请求视频生成。
