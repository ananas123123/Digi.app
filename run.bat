@echo off
setlocal
cd /d "%~dp0"

call "%~dp0build.bat"
if errorlevel 1 exit /b %errorlevel%

set "QT_ROOT=C:\Qt\6.12.0\mingw_64"
set "MINGW_ROOT=C:\Qt\Tools\mingw1310_64"
set "PATH=%MINGW_ROOT%\bin;%QT_ROOT%\bin;%PATH%"
set "QT_QUICK_CONTROLS_STYLE=Basic"

if not exist "%~dp0build\Argon.exe" (
    echo [ERROR] build\Argon.exe was not created.
    pause
    exit /b 1
)

if exist "%~dp0build\argon-runtime.log" del "%~dp0build\argon-runtime.log"

echo.
echo === Launching Argon ===
"%~dp0build\Argon.exe"
set "ARGON_EXIT_CODE=%errorlevel%"
if not "%ARGON_EXIT_CODE%"=="0" (
    echo.
    echo Argon exited with an error. Exit code: %ARGON_EXIT_CODE%
    echo.
    echo === Runtime error details ===
    if exist "%~dp0build\argon-runtime.log" (
        type "%~dp0build\argon-runtime.log"
    ) else (
        echo No runtime log was created. The process may have failed before Qt logging initialized.
    )
    echo.
    pause
    exit /b %ARGON_EXIT_CODE%
)
