@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

set "PYTHON_EXE=python"
if exist ".venv\Scripts\python.exe" set "PYTHON_EXE=.venv\Scripts\python.exe"

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0zapusk_bota.ps1" -PythonExe "%PYTHON_EXE%"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo [ERROR] Zapusk zavershilsya s kodom %EXIT_CODE%.
)

exit /b %EXIT_CODE%
