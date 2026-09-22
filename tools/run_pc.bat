@echo off
setlocal
for %%I in ("%~dp0..") do set "GAME_ROOT=%%~fI"
set "GODOT_EXE=%~dp0..\..\GodotRuntime\Godot_v4.6.2-stable_win64.exe"
if not "%~1"=="" set "GODOT_EXE=%~1"
if not exist "%GODOT_EXE%" (
  echo Godot not found. Pass its executable path as the first argument.
  exit /b 1
)
set "APPDATA=%GAME_ROOT%\.godot_local\Roaming"
set "LOCALAPPDATA=%GAME_ROOT%\.godot_local\Local"
start "AIGodot PC" "%GODOT_EXE%" --path "%GAME_ROOT%" --log-file "%GAME_ROOT%\.godot_local\pc-play.log"
