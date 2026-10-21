param([Parameter(Mandatory=$true)][string]$Address,[int]$Port=24870)
$ErrorActionPreference='Stop'
if($Address -notmatch '^[A-Za-z0-9.-]+$' -or $Port -lt 1 -or $Port -gt 65535) { throw '内网地址或端口格式错误' }
$projectRoot=Split-Path -Parent $PSScriptRoot
$deployment=Join-Path $projectRoot 'dist/network-v0.1.0'
$client=Join-Path $deployment 'Client'
$certificate=Join-Path $deployment 'Data/server-public.crt'
if(-not (Test-Path -LiteralPath $certificate)) { throw '请先运行 Initialize-Server.cmd 生成服务器公开证书' }
$configPath=Join-Path $client 'Config/network-client.json'
$config=Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$config.server_url="https://${Address}:$Port"
$config | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding utf8
Copy-Item -LiteralPath $certificate -Destination (Join-Path $client 'Config/server-public.crt') -Force
Copy-Item -LiteralPath $certificate -Destination (Join-Path $projectRoot 'config/server-public.crt') -Force
$archive=Join-Path $projectRoot 'dist/Windrest-Client-v0.1.0.zip'
Compress-Archive -Path (Join-Path $client '*') -DestinationPath $archive -Force
Write-Host "客户端已准备：$archive"
Write-Host "服务器地址：https://${Address}:$Port"
