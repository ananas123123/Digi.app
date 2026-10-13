@echo off
setlocal
cd /d "%~dp0"

set "QT_ROOT=C:\Qt\6.12.0\mingw_64"
set "MINGW_ROOT=C:\Qt\Tools\mingw1310_64"
set "BUILD_DIR=%~dp0build"

if not exist "%QT_ROOT%\lib\cmake\Qt6\Qt6Config.cmake" (
    echo [ERROR] Qt 6 CMake package was not found under "%QT_ROOT%".
    pause
    exit /b 1
)

if not exist "%MINGW_ROOT%\bin\g++.exe" (
    echo [ERROR] MinGW compiler was not found at "%MINGW_ROOT%\bin\g++.exe".
    pause
    exit /b 1
)

if not exist "%MINGW_ROOT%\bin\mingw32-make.exe" (
    echo [ERROR] MinGW Make was not found at "%MINGW_ROOT%\bin\mingw32-make.exe".
    pause
    exit /b 1
)

set "PATH=%MINGW_ROOT%\bin;%QT_ROOT%\bin;%PATH%"

echo.
echo === Configuring Digi ===
cmake -S "%~dp0." -B "%BUILD_DIR%" -G "MinGW Makefiles" -DCMAKE_PREFIX_PATH="%QT_ROOT%" -DCMAKE_CXX_COMPILER="%MINGW_ROOT%\bin\g++.exe" -DCMAKE_MAKE_PROGRAM="%MINGW_ROOT%\bin\mingw32-make.exe"
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
