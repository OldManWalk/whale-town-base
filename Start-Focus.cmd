@echo off
setlocal
if not defined GODOT_EXE set "GODOT_EXE=%~dp0Godot.exe"
if not exist "%GODOT_EXE%" (
  echo Place Godot 4.4 or later beside this launcher as Godot.exe.
  echo You can also set GODOT_EXE to the full path of the Godot executable.
  pause
  exit /b 2
)

"%GODOT_EXE%" --headless --audio-driver Dummy --path "%~dp0." --import
if errorlevel 1 (
  echo Godot could not import the project. Check the messages above.
  pause
  exit /b 1
)
"%GODOT_EXE%" --path "%~dp0." %*
exit /b %ERRORLEVEL%
