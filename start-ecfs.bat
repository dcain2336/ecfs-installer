@echo off
setlocal

:: =============================================
::  ECFS Lite - Start Server
::  Double-click this to start ECFS Lite
:: =============================================

set "INSTALL_DIR=%USERPROFILE%\ecfs-lite"
set "LITE_PORT=7703"

echo.
echo  Starting ECFS Lite...
echo  Open browser to: http://localhost:%LITE_PORT%
echo  Press Ctrl+C to stop.
echo.

:: Check if installed
if not exist "%INSTALL_DIR%\ecfs\ecfs-lite.py" (
    echo  ERROR: ECFS Lite not found at %INSTALL_DIR%
    echo  Run install.bat first!
    echo.
    pause
    exit /b 1
)

:: Check Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  ERROR: Python not found! Install from python.org
    echo.
    pause
    exit /b 1
)

:: Start server — keep terminal open
cd /d "%INSTALL_DIR%\ecfs"
python ecfs-lite.py

echo.
echo  Server stopped.
echo  Press any key to exit...
pause >nul
endlocal
