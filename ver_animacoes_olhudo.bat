@echo off
cd /d "%~dp0"
start "Olhudo" "F:\GODOT\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." --rendering-method gl_compatibility --resolution 1280x720 res://scenes/olhudo_showcase.tscn
