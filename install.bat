@echo off
title ECFS Lite Installer
color 0B

echo.
echo  ╔══════════════════════════════════════════╗
echo  ║     ECFS Lite — Windows Installer        ║
echo  ║     Agent Gateway v4.1.0                  ║
echo  ╚══════════════════════════════════════════╝
echo.

set "INSTALL_DIR=%USERPROFILE%\ecfs-lite"
set "REPO_URL=https://github.com/dcain2336/ecfs.git"
set "BRANCH=main"
set "RELAY_URL=https://ecfs.arc-omega.me"
set "LITE_PORT=7703"

:: ── Check Git ────────────────────────────────────
echo  [1/5] Checking for Git...
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [X] Git not found. Install: https://git-scm.com/download/win
    start https://git-scm.com/download/win
    pause & exit /b 1
)
echo  [OK]
echo.

:: ── Check Python ─────────────────────────────────
echo  [2/5] Checking for Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    py --version >nul 2>&1
    if %errorlevel% neq 0 (
        echo  [X] Python not found. Install: https://www.python.org/downloads/
        echo  [!] CHECK "Add Python to PATH" during install!
        start https://www.python.org/downloads/
        pause & exit /b 1
    )
    set "PYTHON=py"
) else (
    set "PYTHON=python"
)
echo  [OK]
echo.

:: ── Clone ────────────────────────────────────────
echo  [3/5] Downloading ECFS...
if exist "%INSTALL_DIR%\ecfs\ecfs-lite.py" (
    cd /d "%INSTALL_DIR%\ecfs" && git pull >nul 2>&1
) else (
    git clone --depth 1 -b %BRANCH% %REPO_URL% "%INSTALL_DIR%" >nul 2>&1
)
if not exist "%INSTALL_DIR%\ecfs\ecfs-lite.py" (
    echo  [X] Download failed.
    pause & exit /b 1
)
echo  [OK]
echo.

:: ── Install deps ─────────────────────────────────
echo  [4/5] Installing dependencies...
cd /d "%INSTALL_DIR%\ecfs"
%PYTHON% -m pip install fastapi uvicorn httpx --quiet 2>nul
echo  [OK]
echo.

:: ── Config ───────────────────────────────────────
echo  [5/5] Setting up config...
if not exist "%INSTALL_DIR%\ecfs\.env.ecfs-lite" (
    > "%INSTALL_DIR%\ecfs\.env.ecfs-lite" (
        echo # ECFS Lite Config
        echo ECFS_RELAY_URL=%RELAY_URL%
        echo ECFS_LITE_PORT=%LITE_PORT%
        echo ECFS_LITE_KEYS=ecfs-lite-keys.json
        echo ECFS_LITE_STATE=lite-state
    )
)
echo  [OK]
echo.

:: ── Create start script ──────────────────────────
> "%INSTALL_DIR%\start-ecfs.bat" (
    echo @echo off
    echo cd /d "%INSTALL_DIR%\ecfs"
    echo %PYTHON% ecfs-lite.py --port %LITE_PORT%
    echo pause
)

:: ── Done ─────────────────────────────────────────
echo  ╔══════════════════════════════════════════╗
echo  ║          Install Complete!                ║
echo  ╚══════════════════════════════════════════╝
echo.
echo  Starting ECFS Lite in 3 seconds...
echo  Open http://localhost:%LITE_PORT% in your browser
echo  Press Ctrl+C to stop
echo.
timeout /t 3 /nobreak >nul

:: ── Start server (log errors to file) ────────────
cd /d "%INSTALL_DIR%\ecfs"
%PYTHON% ecfs-lite.py --port %LITE_PORT% 2> "%INSTALL_DIR%\error.log"

:: If we get here, server crashed — show the error
echo.
echo  ╔══════════════════════════════════════════╗
echo  ║  Server stopped unexpectedly!             ║
echo  ╚══════════════════════════════════════════╝
echo.
echo  Error log:
echo  ──────────────────────────────────────────
type "%INSTALL_DIR%\error.log"
echo  ──────────────────────────────────────────
echo.
echo  Copy the error above and send it to me.
echo.
pause
