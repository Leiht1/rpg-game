# 精力图标候选QA与环境边界

图标处理QA：prototypes/energy-icon-v1/processed/pipeline-meta.json；raw spill：art/energy-icon-v1/raw-qc/sheet-qc.json，均无WARN/FAIL。

额外尺寸警告：source_size_mismatch value=1254x1254 requested=1024x1024，文件art/energy-icon-v1/candidate-01/generated.png。

forge_doctor环境诊断（非美术通过声明），原文如下；该诊断无数值threshold字段。

- WARN python.path: other python.exe on PATH: ~/AppData/Local/Microsoft/WindowsApps/python.exe
- WARN deps.scipy: not installed; needed for faster labelling and keying (forge_core falls back to numpy)
- MISSING deps.resvg-py: not installed; needed for codeart2d SVG rendering (PixelSpec needs only numpy and Pillow)
- WARN encoding.stdout: stdout=gbk: non-ASCII text can be garbled in pipes
- WARN encoding.files: open() and read_text() without encoding= use cp936
- WARN paths.cwd: the working folder has spaces or non-ASCII characters
- MISSING ffmpeg: ffmpeg is not on PATH; video decode and encode are unavailable (PNG-frame input still works)
- MISSING media.api.openai: OPENAI_API_KEY is not configured
- MISSING media.api.gemini: GOOGLE_API_KEY or GEMINI_API_KEY is not configured
- MISSING media.api.xai: XAI_API_KEY is not configured
- MISSING media.api.byteplus: ARK_API_KEY is not configured
- MISSING media.api.fal: FAL_KEY is not configured
- MISSING cli.grok: Grok Build CLI not found on PATH or in $GROK_HOME/bin
