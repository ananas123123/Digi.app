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

"%PYTHON%" -u "%~dp0digi_search_engine.py" > "%LOG_FILE%" 2>&1
set "APP_EXIT=%ERRORLEVEL%"

echo.
if not "%APP_EXIT%"=="0" (
    echo ==========================================
    echo DIGI SEARCH ENGINE FAILED OR EXITED WITH AN ERROR
    echo ==========================================
    echo Exit code: %APP_EXIT%
) else (
    echo Digi process exited with code 0.
    echo If the window never appeared, this was an unexpected early exit.
)
echo.
echo -------- Launcher log --------
if exist "%LOG_FILE%" (
    type "%LOG_FILE%"
) else (
    echo No launcher log was created.
)
echo.
echo Full output, if available:
echo %LOG_FILE%
echo.
echo This window will stay open so the exit status and log remain visible.
pause
exit /b %APP_EXIT%
