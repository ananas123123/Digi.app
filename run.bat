@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Digi Search Engine - Development Launcher

set "PYTHON=%~dp0.venv\Scripts\python.exe"
set "CACHE_DIR=%~dp0Digi Dependencies\Cache"
set "LOG_FILE=%CACHE_DIR%\launcher_output.txt"

if not exist "%PYTHON%" (
    echo Digi's development environment is not set up.
    echo Run setup.bat once, then run run.bat again.
    echo.
    pause
    exit /b 1
)

if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%"

echo Starting Digi Search Engine...
echo Logs, if needed, will be saved to:
echo %LOG_FILE%
echo.

"%PYTHON%" "%~dp0digi_search_engine.py" > "%LOG_FILE%" 2>&1
set "APP_EXIT=%ERRORLEVEL%"

if not "%APP_EXIT%"=="0" (
    echo.
    echo ==========================================
    echo DIGI SEARCH ENGINE FAILED TO START
    echo ==========================================
    echo Exit code: %APP_EXIT%
    echo.
    type "%LOG_FILE%"
    echo.
    echo Full output saved to:
    echo %LOG_FILE%
    echo.
    pause
    exit /b %APP_EXIT%
)

exit /b 0
