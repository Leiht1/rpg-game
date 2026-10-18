@echo off
set "GODOT_EXE=D:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
 echo Godot 4.7.2 not found.
 pause
 exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0." -- --items-preview
