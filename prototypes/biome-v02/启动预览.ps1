$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Start-Process -FilePath 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe' -ArgumentList @('--path', ('"'+$projectRoot+'"'), 'res://prototypes/biome-v02/preview.tscn') -WindowStyle Hidden
