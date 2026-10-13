@echo off
setlocal
cd /d "%~dp0"

call "%~dp0build.bat"
if errorlevel 1 exit /b %errorlevel%

set "QT_ROOT=C:\Qt\6.12.0\mingw_64"
set "MINGW_ROOT=C:\Qt\Tools\mingw1310_64"
set "PATH=%MINGW_ROOT%\bin;%QT_ROOT%\bin;%PATH%"

if not exist "%~dp0build\Digi.exe" (
    echo [ERROR] build\Digi.exe was not created.
    pause
    exit /b 1
)

echo.
echo === Launching Digi ===
"%~dp0build\Digi.exe"
if errorlevel 1 (
    echo.
    echo Digi exited with an error.
    pause
    exit /b 1
)
