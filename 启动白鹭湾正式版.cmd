@echo off
setlocal
set "ROOT=%~dp0"
set "DATA=%ROOT%web\.runtime"
if not exist "%DATA%" mkdir "%DATA%"
set "TMP=%DATA%\tmp"
set "TEMP=%DATA%\tmp"
if not exist "%TMP%" mkdir "%TMP%"

where python >nul 2>nul
if errorlevel 1 (
  echo Python was not found. Install Python 3.10+ first.
  pause
  exit /b 1
)
python -c "import fastapi, uvicorn, pydantic, httpx" >nul 2>nul
if errorlevel 1 (
  echo Installing FastAPI, Uvicorn, Pydantic and HTTPX...
  python -m pip install fastapi uvicorn pydantic httpx -i https://mirror.nju.edu.cn/pypi/web/simple
  if errorlevel 1 (
    echo Dependency installation failed.
    pause
    exit /b 1
  )
)

echo ===================================================
echo   Starting Bailu enterprise coffee gateway...
echo ===================================================
if exist "%ROOT%server\setup_demo_config.py" (
  python "%ROOT%server\setup_demo_config.py" --show
)
python "%ROOT%server\start_bailu_demo.py"
if errorlevel 1 (
  echo Failed to start Bailu demo. See web\.runtime\bailu-gateway.out.log
  pause
)
