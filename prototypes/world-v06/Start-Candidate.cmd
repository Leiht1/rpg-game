@echo off
set "GODOT_EXE=D:\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
 echo Godot 4.7.2 not found. Open prototypes/world-v06/world.tscn in Godot.
 pause
 exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0..\.." res://prototypes/world-v06/world.tscn -- %*
