$ErrorActionPreference = 'Stop'
$taskPython = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if (-not (Test-Path -LiteralPath $taskPython)) { $taskPython = (Get-Command python -ErrorAction Stop).Source }
& $taskPython -c 'import PySide6, mutagen, soundfile'
if ($LASTEXITCODE -ne 0) { & $taskPython -m pip install -r (Join-Path $PSScriptRoot 'requirements.txt'); if ($LASTEXITCODE -ne 0) { throw '依赖安装失败' } }
& $taskPython (Join-Path $PSScriptRoot 'app.py')
