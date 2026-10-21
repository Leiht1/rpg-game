param([switch]$Initialize,[switch]$Backup)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$deployment=Join-Path $projectRoot 'dist/network-v0.1.0'
$program=Join-Path $deployment 'Server/WindrestServer.exe'
if(-not (Test-Path -LiteralPath $program)) { throw '尚未构建独立服务器，请先执行 tools/network/build.py' }
$arguments=@('--config',(Join-Path $deployment 'Config/network-server.json'))
if($Initialize) {$arguments+='--initialize'}
if($Backup) {$arguments+='--backup'}
& $program @arguments
if($LASTEXITCODE -ne 0) {throw "服务器退出码：$LASTEXITCODE"}
