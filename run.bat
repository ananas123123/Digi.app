@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Digi Search Engine - Launcher

echo ==========================================
echo        DIGI SEARCH ENGINE 1.0.0.0
echo ==========================================
echo.

where py >nul 2>&1
if not errorlevel 1 (
    set "PYTHON=py"
) else (
    where python >nul 2>&1
    if not errorlevel 1 (
        set "PYTHON=python"
    ) else (
        echo ERROR: Python was not found.
        echo Install Python 3 and make sure it is available as "py" or "python".
        echo.
        pause
        exit /b 1
    )
)

echo Checking required packages...
%PYTHON% -m pip install -r "%~dp0requirements.txt"
if errorlevel 1 (
    echo.
    echo ==========================================
    echo PACKAGE INSTALLATION FAILED
    echo ==========================================
    echo The application was not started.
    echo.
    pause
    exit /b 1
)

if not exist "%~dp0Cache" mkdir "%~dp0Cache"

echo.
echo Starting Digi Search Engine...
echo If it closes immediately, the error will be saved below.
echo.

%PYTHON% "%~dp0digi_search_engine.py" > "%~dp0Cache\launcher_output.txt" 2>&1
set "APP_EXIT=%ERRORLEVEL%"

if not "%APP_EXIT%"=="0" (
    echo.
    echo ==========================================
    echo DIGI SEARCH ENGINE FAILED TO START
    echo ==========================================
    echo Exit code: %APP_EXIT%
    echo.
    echo Full error output:
    type "%~dp0Cache\launcher_output.txt"
    echo.
    echo The same output was saved to:
    echo %~dp0Cache\launcher_output.txt
    echo.
    pause
    exit /b %APP_EXIT%
)

echo.
echo Digi Search Engine closed normally.
echo.
pause
exit /b 0
