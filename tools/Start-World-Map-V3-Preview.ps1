param([switch]$NewWorld)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
if($NewWorld) {
    $userRoot=[IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Godot/app_userdata/风栖原野 V0.4'))
    $target=[IO.Path]::GetFullPath((Join-Path $userRoot 'world-map-v3-preview'))
    if((Split-Path -Parent $target) -ne $userRoot -or (Split-Path -Leaf $target) -ne 'world-map-v3-preview') { throw '试玩目录校验失败' }
    if(Test-Path -LiteralPath $target) {
        $backup=Join-Path $userRoot ('world-map-v3-preview-backup-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        Move-Item -LiteralPath $target -Destination $backup
        Write-Host "原试玩世界已备份：$backup"
    }
}
$candidates=@($env:GODOT_PATH,'D:/Godot/Godot_v4.7.2-stable_win64.exe')
$engine=$candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
if(-not $engine) { throw '未找到 Godot，请设置 GODOT_PATH。' }
& $engine --path $projectRoot 'res://scenes/world_map_v3_preview.tscn'
