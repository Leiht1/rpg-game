param([switch]$Reset)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
if($Reset) {
    $userRoot=[IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Godot/app_userdata/风栖原野 V0.4'))
    $target=[IO.Path]::GetFullPath((Join-Path $userRoot 'character-preview-v1'))
    if((Split-Path -Parent $target) -ne $userRoot -or (Split-Path -Leaf $target) -ne 'character-preview-v1') { throw '试玩目录校验失败' }
    if(Test-Path -LiteralPath $target) {
        $backup=Join-Path $userRoot ('character-preview-v1-backup-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        Move-Item -LiteralPath $target -Destination $backup
        Write-Host "旧试玩档已备份：$backup"
    }
}
$candidates=@($env:GODOT_PATH,'D:/Godot/Godot_v4.7.2-stable_win64.exe',(Join-Path $projectRoot '../Godot/Godot_v4.7.2-stable_win64.exe'))
$engine=$candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
if(-not $engine) { $command=Get-Command godot -ErrorAction SilentlyContinue; if($command) { $engine=$command.Source } }
if(-not $engine) { throw '未找到 Godot 4.7.2，请设置 GODOT_PATH 环境变量。' }
& $engine --path $projectRoot 'res://scenes/character_creation_preview.tscn'
