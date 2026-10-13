@echo off
setlocal
cd /d "%~dp0"

call "%~dp0build.bat"
if errorlevel 1 exit /b %errorlevel%

set "QT_ROOT=C:\Qt\6.12.0\mingw_64"
set "MINGW_ROOT=C:\Qt\Tools\mingw1310_64"
set "PATH=%MINGW_ROOT%\bin;%QT_ROOT%\bin;%PATH%"
set "QT_QUICK_CONTROLS_STYLE=Basic"

if not exist "%~dp0build\Digi.exe" (
    echo [ERROR] build\Digi.exe was not created.
    pause
    exit /b 1
)

if exist "%~dp0build\digi-runtime.log" del "%~dp0build\digi-runtime.log"

echo.
echo === Launching Digi ===
"%~dp0build\Digi.exe"
set "DIGI_EXIT_CODE=%errorlevel%"
if not "%DIGI_EXIT_CODE%"=="0" (
    echo.
    echo Digi exited with an error. Exit code: %DIGI_EXIT_CODE%
    echo.
    echo === Runtime error details ===
    if exist "%~dp0build\digi-runtime.log" (
        type "%~dp0build\digi-runtime.log"
    ) else (
        echo No runtime log was created. The process may have failed before Qt logging initialized.
    )
    echo.
    pause
    exit /b %DIGI_EXIT_CODE%
)
