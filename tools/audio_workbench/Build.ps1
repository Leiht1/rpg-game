$ErrorActionPreference = 'Stop'
$taskPython = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if (-not (Test-Path -LiteralPath $taskPython)) { $taskPython = (Get-Command python -ErrorAction Stop).Source }
Push-Location $PSScriptRoot
try {
    & $taskPython -m pip install -r requirements.txt
    if ($LASTEXITCODE -ne 0) { throw '依赖安装失败' }
    & $taskPython -m PyInstaller --noconfirm --clean --windowed --onedir --name WindrestAudioWorkbench --add-data 'events.json;.' --collect-submodules mutagen --exclude-module PySide6.QtWebEngineCore --exclude-module PySide6.QtWebEngineWidgets app.py
    if ($LASTEXITCODE -ne 0) { throw '打包失败' }
    Copy-Item -LiteralPath events.json -Destination dist/WindrestAudioWorkbench/events.json
    # Qt 6.12 imports Windows' unversioned ICU API. The shared Python runtime
    # can cause PyInstaller to collect its incompatible, versioned ICU 78 DLL.
    # Let the Windows loader resolve the operating system's ICU instead.
    $taskIcu = Join-Path $PSScriptRoot 'dist/WindrestAudioWorkbench/_internal/icuuc.dll'
    if (Test-Path -LiteralPath $taskIcu) { Remove-Item -LiteralPath $taskIcu }
} finally { Pop-Location }
