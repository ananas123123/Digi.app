@echo off
setlocal
cd /d "%~dp0"

set "QT_ROOT=C:\Qt\6.12.0\mingw_64"
set "MINGW_ROOT=C:\Qt\Tools\mingw1310_64"
set "BUILD_DIR=build"

if not exist "%QT_ROOT%\bin\qt-cmake.bat" (
    echo [ERROR] Qt was not found at "%QT_ROOT%".
    echo Check the Qt installation path in build.bat.
    pause
    exit /b 1
)

if not exist "%MINGW_ROOT%\bin\g++.exe" (
    echo [ERROR] Qt MinGW compiler was not found at "%MINGW_ROOT%".
    echo Check the MinGW path in build.bat.
    pause
    exit /b 1
)

set "PATH=%MINGW_ROOT%\bin;%QT_ROOT%\bin;%PATH%"

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

echo.
echo === Configuring Digi ===
call "%QT_ROOT%\bin\qt-cmake.bat" -S "%~dp0" -B "%~dp0%BUILD_DIR%" -G "MinGW Makefiles" -DCMAKE_CXX_COMPILER="%MINGW_ROOT%\bin\g++.exe"
if errorlevel 1 (
    echo [ERROR] CMake configuration failed.
    pause
    exit /b 1
)

echo.
echo === Building Digi ===
cmake --build "%BUILD_DIR%" --parallel
if errorlevel 1 (
    echo [ERROR] Build failed.
    pause
    exit /b 1
)

echo.
echo Build completed.
exit /b 0
