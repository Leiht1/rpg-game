param(
    [ValidateSet('setup','server','client','check','backup')][string]$Action='client',
    [string]$PythonPath,
    [string]$GodotPath
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$localRoot=Join-Path $env:LOCALAPPDATA 'Windrest/IndependentTest-v1'
$manifest=Join-Path $localRoot 'machine.json'
if(-not $PythonPath -and (Test-Path -LiteralPath $manifest)) {
    $PythonPath=(Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).python
}
if(-not $PythonPath) {
    $bundled=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
    if(Test-Path -LiteralPath $bundled) {$PythonPath=$bundled}
    else {throw 'Please supply -PythonPath with a Python runtime containing cryptography and Pillow.'}
}
$arguments=@((Join-Path $projectRoot 'tools/network/independent_test.py'),$Action)
if($GodotPath) {$arguments+=@('--godot',$GodotPath)}
& $PythonPath @arguments
if($LASTEXITCODE -ne 0) {throw "Independent test action failed: $Action ($LASTEXITCODE)"}
