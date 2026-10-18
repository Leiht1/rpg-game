@echo off
set "GODOT_EXE=D:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" exit /b 1
start "" "%GODOT_EXE%" --path "%~dp0." "res://prototypes/chest-open-v1/preview.tscn"
