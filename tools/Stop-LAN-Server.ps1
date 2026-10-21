$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$program=[IO.Path]::GetFullPath((Join-Path $projectRoot 'dist/network-v0.1.0/Server/WindrestServer.exe'))
$configuration=[IO.Path]::GetFullPath((Join-Path $projectRoot 'dist/network-v0.1.0/Config/network-server.json'))
$targets=Get-CimInstance Win32_Process -Filter "Name = 'WindrestServer.exe'" | Where-Object {
    $_.ExecutablePath -eq $program -and $_.CommandLine.IndexOf($configuration,[StringComparison]::OrdinalIgnoreCase) -ge 0
}
foreach($target in $targets) { Stop-Process -Id $target.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host '已停止本项目部署目录的服务器。其他服务器进程未处理。'
