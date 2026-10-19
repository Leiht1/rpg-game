@echo off
set "GODOT_EXE=D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" set "GODOT_EXE=D:\Godot\Godot_v4.7.2-stable_win64.exe"
start "" "%GODOT_EXE%" --path "%~dp0." --script res://tests/preview_industry_v1.gd
