@echo off
set "GODOT_EXE=D:\Godot\Godot_v4.7.2-stable_win64.exe"
start "" "%GODOT_EXE%" --path "%~dp0." --script res://tests/planting_preview.gd
