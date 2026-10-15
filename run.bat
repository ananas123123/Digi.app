@echo off
setlocal
cd /d "%~dp0"

call "%~dp0build.bat"
if errorlevel 1 exit /b %errorlevel%

set "QT_ROOT=C:\Qt\6.12.0\mingw_64"
set "MINGW_ROOT=C:\Qt\Tools\mingw1310_64"
set "PATH=%MINGW_ROOT%\bin;%QT_ROOT%\bin;%PATH%"
set "QT_QUICK_CONTROLS_STYLE=Basic"

if not exist "%~dp0build\Lubis.exe" (
    echo [ERROR] build\Lubis.exe was not created.
    pause
    exit /b 1
)

if exist "%~dp0build\lubis-runtime.log" del "%~dp0build\lubis-runtime.log"

echo.
echo === Launching Lubis ===
"%~dp0build\Lubis.exe"
set "LUBIS_EXIT_CODE=%errorlevel%"
if not "%LUBIS_EXIT_CODE%"=="0" (
    echo.
    echo Lubis exited with an error. Exit code: %LUBIS_EXIT_CODE%
    echo.
    echo === Runtime error details ===
    if exist "%~dp0build\lubis-runtime.log" (
        type "%~dp0build\lubis-runtime.log"
    ) else (
        echo No runtime log was created. The process may have failed before Qt logging initialized.
    )
    echo.
    pause
    exit /b %LUBIS_EXIT_CODE%
)
