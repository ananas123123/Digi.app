@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Digi Search Engine - Development Launcher

set "PYTHON=%~dp0.venv\Scripts\python.exe"

if not exist "%PYTHON%" (
    echo Digi's development environment is not set up.
    echo Run setup.bat once, then run run.bat again.
    echo.
    pause
    exit /b 1
)

echo Starting Digi Search Engine...
echo Application output and errors will appear below.
echo.

"%PYTHON%" -u "%~dp0digi_search_engine.py" 2>&1
set "APP_EXIT=%ERRORLEVEL%"

echo.
if not "%APP_EXIT%"=="0" (
    echo ==========================================
    echo DIGI SEARCH ENGINE FAILED TO START OR EXITED WITH AN ERROR
    echo ==========================================
    echo Exit code: %APP_EXIT%
    echo.
    echo Copy the error text above when reporting this problem.
    echo This window will remain open so the error can be read.
    pause
) else (
    echo Digi exited normally with code 0.
)

exit /b %APP_EXIT%
