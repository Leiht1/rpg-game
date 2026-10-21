# Run from an elevated PowerShell under company network policy.
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$program=[IO.Path]::GetFullPath((Join-Path $projectRoot 'dist/network-v0.1.0/Server/WindrestServer.exe'))
if(-not (Test-Path -LiteralPath $program)) {throw '请先构建服务器'}
if(-not (Get-NetFirewallRule -DisplayName 'Windrest LAN V0.1' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName 'Windrest LAN V0.1' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 24870 -RemoteAddress LocalSubnet -Program $program -Profile Any | Out-Null
}
Write-Host '已允许此服务器程序的本地子网TCP 24870入站。卸除时仅删除 Windrest LAN V0.1 这一条规则。'
