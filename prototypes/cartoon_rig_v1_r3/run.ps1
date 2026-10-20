param([switch]$Editor)
$ErrorActionPreference = 'Stop'
$candidates = @(
    $env:GODOT_BIN,
    'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe',
    (Join-Path $PSScriptRoot 'Godot_v4.7.2-stable_win64.exe')
)
$engine = $null
foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        $engine = $candidate
        break
    }
}
if (-not $engine) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { $engine = $command.Source }
}
if (-not $engine) {
    throw 'Godot was not found. Open this independent project.godot with Godot 4.7.2, or set GODOT_BIN.'
}
if ($Editor) { & $engine --editor --path $PSScriptRoot } else { & $engine --path $PSScriptRoot }
