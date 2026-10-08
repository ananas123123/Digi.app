@echo off
setlocal
cd /d "%~dp0"
set "FACTORY_DIR=%~dp0"
set "OUTPUT_DIR=%~dp0.."
set "VERSION_FILE=%FACTORY_DIR%version.txt"
set "VERSION_INFO_FILE=%FACTORY_DIR%version_info.txt"
if not exist "%VERSION_FILE%" (echo FATAL: version.txt missing&pause&exit /b 1)
set /p APP_VERSION=<"%VERSION_FILE%"
py -m pip install --disable-pip-version-check -r "%FACTORY_DIR%requirements.txt"
if errorlevel 1 (echo Package installation failed.&pause&exit /b 1)
set "FINAL_DIR=%OUTPUT_DIR%\Digi SE %APP_VERSION%"
set "BUILD_CACHE=%FACTORY_DIR%Cache\build"
set "DIST_CACHE=%FACTORY_DIR%Cache\dist"
set "SPEC_CACHE=%FACTORY_DIR%Cache\spec"
set "EXE_PATH=%FINAL_DIR%\Digi Search Engine.exe"
if not exist "%FINAL_DIR%" mkdir "%FINAL_DIR%"
if exist "%BUILD_CACHE%" rmdir /s /q "%BUILD_CACHE%"
if exist "%DIST_CACHE%" rmdir /s /q "%DIST_CACHE%"
if exist "%SPEC_CACHE%" rmdir /s /q "%SPEC_CACHE%"
mkdir "%BUILD_CACHE%" "%DIST_CACHE%" "%SPEC_CACHE%"
py -m PyInstaller --noconfirm --clean --windowed --onefile --name "Digi Search Engine" --version-file "%VERSION_INFO_FILE%" --icon "%FACTORY_DIR%mbappe.ico" --hidden-import "win32com.client" --hidden-import "pythoncom" --collect-all "PySide6.QtWebEngineCore" --collect-all "PySide6.QtWebEngineWidgets" --collect-all "PySide6.QtWebChannel" --add-data "%FACTORY_DIR%frontend;frontend" --add-data "%FACTORY_DIR%backend;backend" --workpath "%BUILD_CACHE%" --distpath "%DIST_CACHE%" --specpath "%SPEC_CACHE%" "%FACTORY_DIR%digi_search_engine.py"
if errorlevel 1 (echo BUILD FAILED&pause&exit /b 1)
if not exist "%FINAL_DIR%" mkdir "%FINAL_DIR%"
if exist "%FINAL_DIR%\version.txt" del /q "%FINAL_DIR%\version.txt"
copy /y "%DIST_CACHE%\Digi Search Engine.exe" "%EXE_PATH%" >nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "$desktop=[Environment]::GetFolderPath('Desktop'); $shell=New-Object -ComObject WScript.Shell; $shortcut=$shell.CreateShortcut((Join-Path $desktop 'Digi Search Engine.lnk')); $shortcut.TargetPath='%EXE_PATH%'; $shortcut.WorkingDirectory='%FINAL_DIR%'; $shortcut.IconLocation='%EXE_PATH%,0'; $shortcut.Save()"
if errorlevel 1 (echo WARNING: Desktop shortcut could not be created.) else (echo DESKTOP SHORTCUT CREATED.)
echo BUILD COMPLETE: "%EXE_PATH%"
pause
