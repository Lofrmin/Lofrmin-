@echo off
setlocal
set "ND_ROOT=%~dp0web"
set "ND_TMP=%ND_ROOT%\.runtime\tmp"
if not exist "%ND_TMP%" mkdir "%ND_TMP%"
set "TMP=%ND_TMP%"
set "TEMP=%ND_TMP%"
REM Do NOT pass --user-data-dir here. The Electron userData folder must stay on the system
REM drive (%APPDATA%\neurodesk-desktop): some managed installs deny file replacement inside
REM the project folder, which breaks the single-instance lock and hides the tray icon.
REM The app picks a writable location itself (see desktop/main.cjs resolveUserData).
set "ND_ARGS=--show-panel --no-sandbox"
if exist "%ND_ROOT%\release\win-unpacked\NeuroDesk.exe" (
  start "" "%ND_ROOT%\release\win-unpacked\NeuroDesk.exe" %ND_ARGS%
  exit /b 0
)
cd /d "%ND_ROOT%"
where npm >nul 2>nul
if errorlevel 1 (
  echo Node.js and npm were not found. Install Node.js or keep the release folder.
  pause
  exit /b 1
)
call npm start -- %ND_ARGS%
if errorlevel 1 pause
