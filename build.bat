@echo off
setlocal
cd /d "%~dp0"

REM ============================================================
REM Digi Search Engine - Build 1.0.0.0
REM Final user-facing layout:
REM   Digi SE 1.0.0.0\
REM     Digi Search Engine.exe
REM     Search Repository\
REM     Incoming\
REM     Cache\
REM
REM The EXE is built directly into the final folder.
REM If the EXE is later moved elsewhere and launched, the application
REM recreates this version-folder structure and relocates itself once.

REM ============================================================

set "FACTORY_DIR=%~dp0"
set "OUTPUT_DIR=%~dp0.."
set "VERSION_FILE=%FACTORY_DIR%version.txt"
set "VERSION_INFO_FILE=%FACTORY_DIR%version_info.txt"

if not exist "%VERSION_FILE%" (
    echo.
    echo FATAL ERROR: Digi version file was not found:
    echo   %VERSION_FILE%
    pause
    exit /b 1
)

set /p APP_VERSION=<"%VERSION_FILE%"
py -c "import re,sys; v=open(r'%VERSION_FILE%',encoding='utf-8').read().strip(); sys.exit(0 if re.fullmatch(r'\d+\.\d+\.\d+\.\d+',v) else 1)" >nul 2>&1
if errorlevel 1 (
    echo.
    echo FATAL ERROR: Digi version file must contain exactly MAJOR.MINOR.PATCH.BUILD.
    echo   %VERSION_FILE%
    pause
    exit /b 1
)

if not exist "%VERSION_INFO_FILE%" (
    echo.
    echo FATAL ERROR: Digi Windows version resource was not found:
    echo   %VERSION_INFO_FILE%
    pause
    exit /b 1
)

set "FINAL_DIR=%OUTPUT_DIR%\Digi SE %APP_VERSION%"
set "BUILD_CACHE=%FACTORY_DIR%Cache\build"
set "DIST_CACHE=%FACTORY_DIR%Cache\dist"
set "SPEC_CACHE=%FACTORY_DIR%Cache\spec"
set "EXE_PATH=%FINAL_DIR%\Digi Search Engine.exe"

echo.
echo ==========================================
echo       DIGI SEARCH ENGINE 1.0.0.0 BUILD
echo ==========================================
echo.

echo Final application folder:
echo   %FINAL_DIR%
echo.

set "PIP_DISABLE_PIP_VERSION_CHECK=1"
set "PIP_NO_INPUT=1"

echo Checking required Python packages...
py -c "import PySide6, fitz, rapidfuzz, docx, win32com" >nul 2>&1
if errorlevel 1 (
    echo Some required packages are missing. Installing them now...
    echo.
    py -m pip install --prefer-binary --disable-pip-version-check --retries 3 --timeout 120 -r "%FACTORY_DIR%requirements.txt"
    if errorlevel 1 (
        echo.
        echo ==========================================
        echo PACKAGE INSTALLATION FAILED OR WAS CANCELLED
        echo ==========================================
        echo.
        echo No build was attempted. Run build.bat again after the installation
        echo has completed successfully.
        echo.
        pause
        exit /b 1
    )
) else (
    echo All required packages are already installed.
)

echo.
echo Preparing final application folder...
if not exist "%FINAL_DIR%" mkdir "%FINAL_DIR%"
if not exist "%FINAL_DIR%\Search Repository" mkdir "%FINAL_DIR%\Search Repository"
if not exist "%FINAL_DIR%\Incoming" mkdir "%FINAL_DIR%\Incoming"
if not exist "%FINAL_DIR%\Cache" mkdir "%FINAL_DIR%\Cache"

echo.
echo Cleaning previous build cache...
if exist "%BUILD_CACHE%" rmdir /s /q "%BUILD_CACHE%"
if exist "%DIST_CACHE%" rmdir /s /q "%DIST_CACHE%"
if exist "%SPEC_CACHE%" rmdir /s /q "%SPEC_CACHE%"
mkdir "%BUILD_CACHE%"
mkdir "%DIST_CACHE%"
mkdir "%SPEC_CACHE%"

echo.
echo Building single-file Digi Search Engine.exe...
py -m PyInstaller --noconfirm --clean --windowed --onefile --name "Digi Search Engine" --version-file "%VERSION_INFO_FILE%" --icon "%FACTORY_DIR%mbappe.ico" --add-data "%FACTORY_DIR%nose_placeholder.png;." --add-data "%FACTORY_DIR%mbappe.ico;." --add-data "%FACTORY_DIR%digi_splash.png;." --hidden-import "win32com.client" --hidden-import "pythoncom" --workpath "%BUILD_CACHE%" --distpath "%DIST_CACHE%" --specpath "%SPEC_CACHE%" "%FACTORY_DIR%digi_search_engine.py"

if errorlevel 1 (
    echo.
    echo ==========================================
    echo BUILD FAILED
    echo ==========================================
    echo.
    echo Build files were kept in:
    echo   %FACTORY_DIR%Cache
    echo.
    pause
    exit /b 1
)

echo.
echo Installing the finished EXE directly into the final folder...
copy /y "%DIST_CACHE%\Digi Search Engine.exe" "%EXE_PATH%" >nul
if errorlevel 1 (
    echo.
    echo ERROR: Could not copy the EXE to:
    echo %EXE_PATH%
    pause
    exit /b 1
)

echo.
echo Copying authoritative version file into final application folder...
copy /y "%VERSION_FILE%" "%FINAL_DIR%\version.txt" >nul
if errorlevel 1 (
    echo.
    echo FATAL ERROR: Could not copy the Digi version file into the final application folder.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo BUILD COMPLETE
echo ==========================================
echo.
echo Final user-facing setup:
echo.
echo   %FINAL_DIR%
echo   ^|-- Digi Search Engine.exe
echo   ^|-- Search Repository
echo   ^|-- Incoming
echo   `-- Cache
echo The Cache folder stores the SQLite index and saved settings.
echo The Digi Factory folder is only needed if you want to rebuild.
echo.
echo The 3-second branded splash is intentionally retained.
echo.
echo You can now launch:
echo   "%EXE_PATH%"
echo.
pause
