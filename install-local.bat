@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "VERSION_FILE=%~dp0version.txt"
if not exist "%VERSION_FILE%" (
    echo FATAL: version.txt is missing.
    exit /b 1
)
set /p APP_VERSION=<"%VERSION_FILE%"
if not defined APP_VERSION (
    echo FATAL: version.txt is empty.
    exit /b 1
)

set "SOURCE_DIR=%~dp0..\Digi SE %APP_VERSION%"
set "SOURCE_APP=%SOURCE_DIR%\Digi Search Engine.exe"
set "SOURCE_HELPER=%SOURCE_DIR%\DigiUpdater.exe"
set "INSTALL_DIR=%LOCALAPPDATA%\Programs\Digi"
set "TARGET_APP=%INSTALL_DIR%\Digi Search Engine.exe"
set "TARGET_HELPER=%INSTALL_DIR%\DigiUpdater.exe"

if not exist "%SOURCE_APP%" (
    echo FATAL: Build output not found: "%SOURCE_APP%"
    echo Run build.bat first.
    exit /b 1
)
if not exist "%SOURCE_HELPER%" (
    echo FATAL: DigiUpdater.exe is missing from the build output.
    echo Run the updated build.bat first.
    exit /b 1
)
if exist "%TARGET_APP%" (
    echo FATAL: Digi is already installed at "%INSTALL_DIR%".
    echo This script is for first-time installation only and will not overwrite an installation.
    exit /b 1
)
if exist "%TARGET_HELPER%" (
    echo FATAL: An existing DigiUpdater.exe was found at "%INSTALL_DIR%".
    echo Inspect the existing installation before proceeding.
    exit /b 1
)

if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
if errorlevel 1 (
    echo FATAL: Could not create the installation directory.
    exit /b 1
)

set "STAGING_DIR=%INSTALL_DIR%\.install-staging-%RANDOM%-%RANDOM%"
mkdir "%STAGING_DIR%"
if errorlevel 1 (
    echo FATAL: Could not create a staging directory.
    exit /b 1
)

copy /b "%SOURCE_APP%" "%STAGING_DIR%\Digi Search Engine.exe" >nul
if errorlevel 1 (
    echo FATAL: Could not stage Digi Search Engine.exe.
    rmdir /s /q "%STAGING_DIR%"
    exit /b 1
)
copy /b "%SOURCE_HELPER%" "%STAGING_DIR%\DigiUpdater.exe" >nul
if errorlevel 1 (
    echo FATAL: Could not stage DigiUpdater.exe.
    rmdir /s /q "%STAGING_DIR%"
    exit /b 1
)

move /y "%STAGING_DIR%\Digi Search Engine.exe" "%TARGET_APP%" >nul
if errorlevel 1 (
    echo FATAL: Could not install Digi Search Engine.exe.
    rmdir /s /q "%STAGING_DIR%"
    exit /b 1
)
move /y "%STAGING_DIR%\DigiUpdater.exe" "%TARGET_HELPER%" >nul
if errorlevel 1 (
    echo FATAL: Could not install DigiUpdater.exe. Removing the incomplete first install.
    del /q "%TARGET_APP%" 2>nul
    rmdir /s /q "%STAGING_DIR%"
    exit /b 1
)
rmdir /s /q "%STAGING_DIR%" 2>nul

powershell -NoProfile -ExecutionPolicy Bypass -Command "$desktop=[Environment]::GetFolderPath('Desktop'); $shell=New-Object -ComObject WScript.Shell; $shortcut=$shell.CreateShortcut((Join-Path $desktop 'Digi Search Engine.lnk')); $shortcut.TargetPath='%TARGET_APP%'; $shortcut.WorkingDirectory='%INSTALL_DIR%'; $shortcut.IconLocation='%TARGET_APP%,0'; $shortcut.Save()"
if errorlevel 1 (
    echo WARNING: Digi was installed, but the desktop shortcut could not be created.
) else (
    echo Desktop shortcut created.
)

echo.
echo FIRST INSTALL COMPLETE: "%INSTALL_DIR%"
echo Persistent user data remains separate under "%LOCALAPPDATA%\Digi".
echo This script does not modify existing Digi user data.
