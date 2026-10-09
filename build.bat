@echo off
setlocal
cd /d "%~dp0"

echo Checking Windows installed applications for Digi...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$keys=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'); $found=Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and $_.DisplayName -like '*Digi*' } | ForEach-Object { if ($_.DisplayIcon) { ($_.DisplayIcon -replace ',.*$','').Trim([char]34) } elseif ($_.InstallLocation) { Join-Path $_.InstallLocation 'Digi Search Engine.exe' } } | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1; if ($found) { Write-Output 'DIGI_FOUND'; Write-Output $found; exit 1 }; exit 0"
if errorlevel 1 (
    echo.
    echo FATAL: An installed Digi executable was found.
    echo Build cancelled.
    pause
    exit /b 1
)
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
set "SOURCE_DIR=%FINAL_DIR%\Digi Source"
if not exist "%FINAL_DIR%" mkdir "%FINAL_DIR%"
if exist "%BUILD_CACHE%" rmdir /s /q "%BUILD_CACHE%"
if exist "%DIST_CACHE%" rmdir /s /q "%DIST_CACHE%"
if exist "%SPEC_CACHE%" rmdir /s /q "%SPEC_CACHE%"
mkdir "%BUILD_CACHE%" "%DIST_CACHE%" "%SPEC_CACHE%"

rem Bundle the stable launcher and runtime only; app/backend/frontend remain external.
py -m PyInstaller --noconfirm --clean --windowed --onefile --name "Digi Search Engine" --version-file "%VERSION_INFO_FILE%" --icon "%FACTORY_DIR%mbappe.ico" --hidden-import "win32com.client" --hidden-import "pythoncom" --hidden-import "sqlite3" --hidden-import "_sqlite3" --hidden-import "xml" --collect-submodules "xml" --collect-all "PySide6.QtWebEngineCore" --collect-all "PySide6.QtWebEngineWidgets" --collect-all "PySide6.QtWebChannel" --workpath "%BUILD_CACHE%" --distpath "%DIST_CACHE%" --specpath "%SPEC_CACHE%" "%FACTORY_DIR%digi_search_engine.py"
if errorlevel 1 (echo BUILD FAILED&pause&exit /b 1)
copy /y "%DIST_CACHE%\Digi Search Engine.exe" "%EXE_PATH%" >nul
if errorlevel 1 (echo FATAL: Could not copy the executable.&pause&exit /b 1)

rem Create the source tree only on first build; never overwrite existing editable sources.
if not exist "%SOURCE_DIR%\" (
    mkdir "%SOURCE_DIR%"
    xcopy "%FACTORY_DIR%app.py" "%SOURCE_DIR%\" /I /Y >nul
    if errorlevel 1 (echo FATAL: Could not copy app.py.&pause&exit /b 1)
    xcopy "%FACTORY_DIR%backend" "%SOURCE_DIR%\backend\" /E /I /Y >nul
    if errorlevel 1 (echo FATAL: Could not copy backend sources.&pause&exit /b 1)
    xcopy "%FACTORY_DIR%frontend" "%SOURCE_DIR%\frontend\" /E /I /Y >nul
    if errorlevel 1 (echo FATAL: Could not copy frontend sources.&pause&exit /b 1)
    xcopy "%FACTORY_DIR%updater" "%SOURCE_DIR%\updater\" /E /I /Y >nul
    if errorlevel 1 (echo FATAL: Could not copy updater sources.&pause&exit /b 1)
    copy /y "%FACTORY_DIR%requirements.txt" "%SOURCE_DIR%\requirements.txt" >nul
    >"%SOURCE_DIR%README.txt" echo Digi external application sources. Edit app.py, backend, frontend and updater here.
    >>"%SOURCE_DIR%README.txt" echo Restart Digi after Python changes. Frontend changes appear after reload or restart.
    >>"%SOURCE_DIR%README.txt" echo New dependencies or compiled/native components may require installation or rebuilding.
) else (
    echo Existing Digi Source folder found. Editable files will be preserved.
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$desktop=[Environment]::GetFolderPath('Desktop'); $shell=New-Object -ComObject WScript.Shell; $shortcut=$shell.CreateShortcut((Join-Path $desktop 'Digi Search Engine.lnk')); $shortcut.TargetPath='%EXE_PATH%'; $shortcut.WorkingDirectory='%FINAL_DIR%'; $shortcut.IconLocation='%EXE_PATH%,0'; $shortcut.Save()"
if errorlevel 1 (echo WARNING: Desktop shortcut could not be created.) else (echo DESKTOP SHORTCUT CREATED.)
echo BUILD COMPLETE: "%EXE_PATH%"
echo EXTERNAL SOURCES: "%SOURCE_DIR%"
pause
