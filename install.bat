@echo off
setlocal EnableDelayedExpansion

:: =============================================
::  ECFS Lite Windows Installer
::  Downloads ECFS Lite and installs dependencies
:: =============================================

echo.
echo  ========================================
echo       ECFS Lite - Windows Installer
echo  ========================================
echo.

set "INSTALL_DIR=%USERPROFILE%\ecfs-lite"
set "REPO_URL=https://github.com/dcain2336/ecfs-installer/archive/refs/heads/main.zip"
set "ZIP_FILE=%USERPROFILE%\ecfs-lite-download.zip"
set "ADMIN_KEY=ecfs-admin-change-me"
set "LITE_PORT=7703"

:: ── Step 1: Check Python ──
echo [1/5] Checking Python...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  ERROR: Python is not installed or not in PATH.
    echo  Download from https://www.python.org/downloads/
    echo  IMPORTANT: Check "Add Python to PATH" during install!
    echo.
    goto :fail
)
python -c "import sys; v=sys.version_info; print(f'  Found Python {v.major}.{v.minor}.{v.micro}')" 2>nul || (
    echo  ERROR: Could not run Python.
    goto :fail
)
echo.

:: ── Step 2: Download from GitHub ──
echo [2/5] Downloading ECFS Lite from GitHub...
if exist "%ZIP_FILE%" del "%ZIP_FILE%" >nul 2>&1

:: Try curl.exe first (built into Windows 10 1803+)
where curl.exe >nul 2>&1
if %errorlevel% equ 0 (
    echo  Using curl.exe to download...
    curl.exe -L -o "%ZIP_FILE%" "%REPO_URL%" -# 2>nul
    if %errorlevel% neq 0 (
        echo  curl.exe download failed, trying PowerShell...
        goto :try_ps
    )
    goto :download_ok
)

:try_ps
:: Fallback to PowerShell
echo  Using PowerShell to download...
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%REPO_URL%' -OutFile '%ZIP_FILE%' -UseBasicParsing" 2>nul
if %errorlevel% neq 0 (
    echo  ERROR: Download failed!
    echo  Check your internet connection and try again.
    echo  You can also manually download from:
    echo  https://github.com/dcain2336/ecfs-installer
    goto :fail
)

:download_ok
if not exist "%ZIP_FILE%" (
    echo  ERROR: Download file not found after download.
    goto :fail
)
echo  Download complete!
echo.

:: ── Step 3: Extract ──
echo [3/5] Extracting files...
if exist "%INSTALL_DIR%" rmdir /s /q "%INSTALL_DIR%" >nul 2>&1
mkdir "%INSTALL_DIR%" >nul 2>&1

:: Try tar first (built into Windows 10+)
tar -xf "%ZIP_FILE%" -C "%INSTALL_DIR%" >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%ZIP_FILE%' -DestinationPath '%INSTALL_DIR%' -Force" >nul 2>&1
)

:: Move files from subfolder to root
for /d %%i in ("%INSTALL_DIR%\ecfs-installer-*") do (
    xcopy "%%i\*" "%INSTALL_DIR%\" /E /Y /Q >nul 2>&1
    rmdir /s /q "%%i" >nul 2>&1
)

if not exist "%INSTALL_DIR%\ecfs\ecfs-lite.py" (
    echo  ERROR: ecfs-lite.py not found after extraction.
    echo  Extracted files:
    dir "%INSTALL_DIR%" /b 2>nul
    goto :fail
)

echo  Extracted to %INSTALL_DIR%
echo.

:: ── Step 4: Install Dependencies ──
echo [4/5] Installing Python packages...
cd /d "%INSTALL_DIR%"
python -m pip install --quiet --upgrade pip >nul 2>&1
python -m pip install --quiet fastapi uvicorn httpx python-dotenv >nul 2>&1
if %errorlevel% neq 0 (
    echo  WARNING: Some packages may not have installed correctly.
    echo  Try running: pip install fastapi uvicorn httpx python-dotenv
)
echo  Done!
echo.

:: ── Step 5: Create Config ──
echo [5/5] Setting up config...
if not exist "%INSTALL_DIR%\.env.ecfs-lite" (
    (
        echo ECFS_RELAY_URL=https://ecfs.arc-omega.me
        echo ECFS_LITE_PORT=%LITE_PORT%
        echo ECFS_LITE_KEYS=ecfs-lite-keys.json
        echo ECFS_LITE_STATE=lite-state
        echo ECFS_LITE_ADMIN_KEY=%ADMIN_KEY%
    ) > "%INSTALL_DIR%\.env.ecfs-lite"
    echo  Created config file (.env.ecfs-lite)
) else (
    echo  Config file already exists, skipping.
)

:: ── Done ──
echo.
echo  ========================================
echo       Installation Complete!
echo  ========================================
echo.
echo  Starting ECFS Lite on port %LITE_PORT%...
echo  Open your browser to: http://localhost:%LITE_PORT%
echo  Press Ctrl+C to stop the server.
echo.

:: Start the server and KEEP TERMINAL OPEN
cd /d "%INSTALL_DIR%\ecfs"
python ecfs-lite.py

:: If server exits, show message
echo.
echo  Server stopped.
echo.

goto :end

:fail
echo.
echo  Install failed. Please check the errors above.
echo.

:end
echo  Press any key to exit...
pause >nul
endlocal
