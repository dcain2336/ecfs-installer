@echo off
setlocal EnableDelayedExpansion
title ECFS Lite Installer for Windows
color 0B

echo.
echo  ╔══════════════════════════════════════════╗
echo  ║     ECFS Lite — Windows Installer        ║
echo  ║     Agent Gateway v4.1.0                  ║
echo  ╚══════════════════════════════════════════╝
echo.

:: ── Config ──────────────────────────────────────
set "INSTALL_DIR=%USERPROFILE%\ecfs-lite"
set "REPO_URL=https://github.com/dcain2336/ecfs.git"
set "BRANCH=main"
set "RELAY_URL=https://ecfs.arc-omega.me"
set "LITE_PORT=7703"

:: ── Step 1: Check for Git ────────────────────────
echo  [1/6] Checking for Git...
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] Git not found. Downloading...
    echo  [!] Please install Git from: https://git-scm.com/download/win
    echo  [!] Run the installer, then re-run this script.
    echo.
    start https://git-scm.com/download/win
    pause
    exit /b 1
)
echo  [OK] Git found.
echo.

:: ── Step 2: Check for Python ─────────────────────
echo  [2/6] Checking for Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    py --version >nul 2>&1
    if %errorlevel% neq 0 (
        echo  [!] Python not found. Downloading...
        echo  [!] Please install Python from: https://www.python.org/downloads/
        echo  [!] IMPORTANT: Check "Add Python to PATH" during install!
        echo.
        start https://www.python.org/downloads/
        pause
        exit /b 1
    )
    set "PYTHON=py"
) else (
    set "PYTHON=python"
)
%PYTHON% --version
echo  [OK] Python found.
echo.

:: ── Step 3: Clone ECFS ───────────────────────────
echo  [3/6] Downloading ECFS Lite...
if exist "%INSTALL_DIR%" (
    echo  [!] %INSTALL_DIR% already exists. Updating...
    cd /d "%INSTALL_DIR%"
    git pull
) else (
    git clone --depth 1 -b %BRANCH% %REPO_URL% "%INSTALL_DIR%"
    cd /d "%INSTALL_DIR%"
)
if %errorlevel% neq 0 (
    echo  [X] Failed to clone repo.
    pause
    exit /b 1
)
echo  [OK] ECFS downloaded to %INSTALL_DIR%
echo.

:: ── Step 4: Install dependencies ─────────────────
echo  [4/6] Installing Python dependencies...
%PYTHON% -m pip install --upgrade pip >nul 2>&1
%PYTHON% -m pip install fastapi uvicorn httpx
if %errorlevel% neq 0 (
    echo  [X] Failed to install dependencies.
    pause
    exit /b 1
)
echo  [OK] Dependencies installed.
echo.

:: ── Step 5: Create config ────────────────────────
echo  [5/6] Creating config...
if not exist "%INSTALL_DIR%\.env.ecfs-lite" (
    (
        echo # ECFS Lite Config
        echo ECFS_RELAY_URL=%RELAY_URL%
        echo ECFS_LITE_PORT=%LITE_PORT%
        echo ECFS_LITE_KEYS=ecfs-lite-keys.json
        echo ECFS_LITE_STATE=lite-state
    ) > "%INSTALL_DIR%\.env.ecfs-lite"
    echo  [OK] Config created.
) else (
    echo  [OK] Config already exists, skipping.
)
echo.

:: ── Step 6: Create start script ──────────────────
echo  [6/6] Creating start script...
(
    echo @echo off
    echo title ECFS Lite — Port %LITE_PORT%
    echo cd /d "%INSTALL_DIR%"
    echo echo.
    echo echo  Starting ECFS Lite on port %LITE_PORT%...
    echo echo  Open http://localhost:%LITE_PORT% in your browser
    echo echo  Press Ctrl+C to stop
    echo echo.
    echo %PYTHON% ecfs-lite.py --port %LITE_PORT%
    echo echo.
    echo echo  Server stopped.
    echo pause
) > "%INSTALL_DIR%\start-ecfs.bat"
echo  [OK] Created start-ecfs.bat
echo.

:: ── Done ─────────────────────────────────────────
echo  ╔══════════════════════════════════════════╗
echo  ║            Install Complete!              ║
echo  ╚══════════════════════════════════════════╝
echo.
echo  To start ECFS Lite:
echo    1. Go to: %INSTALL_DIR%
echo    2. Double-click: start-ecfs.bat
echo    3. Open browser: http://localhost:%LITE_PORT%
echo.
echo  Or run this command from anywhere:
echo    %PYTHON% "%INSTALL_DIR%\ecfs-lite.py" --port %LITE_PORT%
echo.

:: Ask if they want to start now
set /p "STARTNOW=Start ECFS Lite now? (Y/N): "
if /i "%STARTNOW%"=="Y" (
    echo.
    echo  Starting ECFS Lite...
    echo  Press Ctrl+C to stop.
    echo.
    cd /d "%INSTALL_DIR%"
    %PYTHON% ecfs-lite.py --port %LITE_PORT%
    echo.
    echo  Server stopped.
    pause
) else (
    echo.
    echo  Run start-ecfs.bat when you're ready!
    echo.
    pause
)
