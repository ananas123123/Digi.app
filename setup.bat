@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Digi Search Engine - Development Setup

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

if not exist "%~dp0.venv\Scripts\python.exe" (
    echo Creating Digi development virtual environment...
    %PYTHON% -m venv "%~dp0.venv"
    if errorlevel 1 (
        echo Failed to create the virtual environment.
        pause
        exit /b 1
    )
)

echo Installing or updating Digi development dependencies...
"%~dp0.venv\Scripts\python.exe" -m pip install --upgrade pip
if errorlevel 1 (
    echo Failed to update pip.
    pause
    exit /b 1
)
"%~dp0.venv\Scripts\python.exe" -m pip install -r "%~dp0requirements.txt"
if errorlevel 1 (
    echo Dependency installation failed.
    pause
    exit /b 1
)

echo.
echo Setup complete. Use run.bat for normal launches.
pause
exit /b 0
