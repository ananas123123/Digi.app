@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "FACTORY_DIR=%~dp0"
set "VERSION_FILE=%FACTORY_DIR%version.txt"
set "VERSION_INFO_FILE=%FACTORY_DIR%version_info.txt"
set "PYTHON_EXE=%FACTORY_DIR%.venv\Scripts\python.exe"
set "INSTALL_DIR=%LOCALAPPDATA%\Digi"
set "APP_TARGET=%INSTALL_DIR%\Digi Search Engine.exe"
set "HELPER_TARGET=%INSTALL_DIR%\DigiUpdater.exe"

echo Checking whether Digi is currently running...
powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Get-Process -Name 'Digi Search Engine' -ErrorAction SilentlyContinue) { exit 1 }; exit 0"
if errorlevel 1 (
    echo FATAL: Close Digi before rebuilding. The installed executable cannot be safely replaced while it is running.
    pause
    exit /b 1
)

if not exist "%VERSION_FILE%" (echo FATAL: version.txt missing&pause&exit /b 1)
if not exist "%VERSION_INFO_FILE%" (echo FATAL: version_info.txt missing&pause&exit /b 1)
set /p APP_VERSION=<"%VERSION_FILE%"
if not defined APP_VERSION (echo FATAL: version.txt is empty&pause&exit /b 1)

if not exist "%PYTHON_EXE%" (
    echo FATAL: Project virtual environment not found: "%PYTHON_EXE%"
    echo Run setup.bat first.
    pause
    exit /b 1
)

echo Installing/checking build dependencies...
"%PYTHON_EXE%" -m pip install --disable-pip-version-check -r "%FACTORY_DIR%requirements.txt"
if errorlevel 1 (echo FATAL: Dependency installation failed.&pause&exit /b 1)

set "BUILD_CACHE=%FACTORY_DIR%Cache\build\test-exe-%APP_VERSION%"
set "DIST_CACHE=%FACTORY_DIR%Cache\dist\test-exe-%APP_VERSION%"
set "SPEC_CACHE=%FACTORY_DIR%Cache\spec\test-exe-%APP_VERSION%"
set "UPDATER_BUILD_CACHE=%FACTORY_DIR%Cache\build\updater-helper-%APP_VERSION%"
set "UPDATER_DIST_CACHE=%FACTORY_DIR%Cache\dist\updater-helper-%APP_VERSION%"
set "UPDATER_SPEC_CACHE=%FACTORY_DIR%Cache\spec\updater-helper-%APP_VERSION%"

if not exist "%FACTORY_DIR%Cache\." mkdir "%FACTORY_DIR%Cache"
if not exist "%BUILD_CACHE%\" mkdir "%BUILD_CACHE%"
if not exist "%DIST_CACHE%\" mkdir "%DIST_CACHE%"
if not exist "%SPEC_CACHE%\" mkdir "%SPEC_CACHE%"
if not exist "%UPDATER_BUILD_CACHE%\" mkdir "%UPDATER_BUILD_CACHE%"
if not exist "%UPDATER_DIST_CACHE%\" mkdir "%UPDATER_DIST_CACHE%"
if not exist "%UPDATER_SPEC_CACHE%\" mkdir "%UPDATER_SPEC_CACHE%"

echo Checking application imports...
"%PYTHON_EXE%" "%FACTORY_DIR%tools\pyinstaller_imports.py" > "%FACTORY_DIR%Cache\import-analysis-output.txt"
if errorlevel 1 (
    echo FATAL: Could not analyse application imports.
    type "%FACTORY_DIR%Cache\import-analysis-output.txt"
    pause
    exit /b 1
)
findstr /r /c:"--hidden-import=" "%FACTORY_DIR%Cache\import-analysis-output.txt" >nul
if errorlevel 1 (
    echo FATAL: Import analysis produced no hidden imports.
    type "%FACTORY_DIR%Cache\import-analysis-output.txt"
    pause
    exit /b 1
)
echo Import analysis passed.

echo Building Digi application executable...
"%PYTHON_EXE%" -m PyInstaller --noconfirm --clean --windowed --onefile ^
  --name "Digi Search Engine" ^
  --version-file "%VERSION_INFO_FILE%" ^
  --icon "%FACTORY_DIR%mbappe.ico" ^
  --hidden-import "PySide6.QtCore" ^
  --hidden-import "PySide6.QtGui" ^
  --hidden-import "PySide6.QtWebChannel" ^
  --hidden-import "PySide6.QtWebEngineWidgets" ^
  --hidden-import "PySide6.QtWidgets" ^
  --hidden-import "base64" ^
  --hidden-import "ctypes" ^
  --hidden-import "datetime" ^
  --hidden-import "docx" ^
  --hidden-import "docx.enum.section" ^
  --hidden-import "docx.enum.text" ^
  --hidden-import "docx.shared" ^
  --hidden-import "filecmp" ^
  --hidden-import "fitz" ^
  --hidden-import "html" ^
  --hidden-import "io" ^
  --hidden-import "json" ^
  --hidden-import "os" ^
  --hidden-import "pathlib" ^
  --hidden-import "pythoncom" ^
  --hidden-import "rapidfuzz" ^
  --hidden-import "re" ^
  --hidden-import "shutil" ^
  --hidden-import "sqlite3" ^
  --hidden-import "subprocess" ^
  --hidden-import "sys" ^
  --hidden-import "tempfile" ^
  --hidden-import "time" ^
  --hidden-import "unittest" ^
  --hidden-import "unittest.mock" ^
  --hidden-import "urllib.parse" ^
  --hidden-import "urllib.request" ^
  --hidden-import "uuid" ^
  --hidden-import "win32com.client" ^
  --hidden-import "xml.etree.ElementTree" ^
  --hidden-import "zipfile" ^
  --add-data "%FACTORY_DIR%app.py;." ^
  --add-data "%FACTORY_DIR%backend\__init__.py;backend" ^
  --add-data "%FACTORY_DIR%backend\api.py;backend" ^
  --add-data "%FACTORY_DIR%backend\updater_download.py;backend" ^
  --add-data "%FACTORY_DIR%backend\config.py;backend" ^
  --add-data "%FACTORY_DIR%backend\conversion.py;backend" ^
  --add-data "%FACTORY_DIR%backend\database.py;backend" ^
  --add-data "%FACTORY_DIR%backend\files.py;backend" ^
  --add-data "%FACTORY_DIR%backend\notes.py;backend" ^
  --add-data "%FACTORY_DIR%backend\search.py;backend" ^
  --add-data "%FACTORY_DIR%backend\version_manager.py;backend" ^
  --add-data "%FACTORY_DIR%backend\updater_logging.py;backend" ^
  --add-data "%FACTORY_DIR%frontend\index.html;frontend" ^
  --add-data "%FACTORY_DIR%frontend\app.js;frontend" ^
  --add-data "%FACTORY_DIR%frontend\styles.css;frontend" ^
  --add-data "%FACTORY_DIR%updater\version_comparison.js;updater" ^
  --add-data "%FACTORY_DIR%updater\update_checker.js;updater" ^
  --collect-all "PySide6.QtWebEngineCore" ^
  --collect-all "PySide6.QtWebEngineWidgets" ^
  --collect-all "PySide6.QtWebChannel" ^
  --workpath "%BUILD_CACHE%" ^
  --distpath "%DIST_CACHE%" ^
  --specpath "%SPEC_CACHE%" ^
  "%FACTORY_DIR%digi_search_engine.py"
if errorlevel 1 (echo FATAL: Digi application build failed.&pause&exit /b 1)
if not exist "%DIST_CACHE%\Digi Search Engine.exe" (
    echo FATAL: Main executable was not produced.
    pause
    exit /b 1
)

echo Building separate DigiUpdater helper...
"%PYTHON_EXE%" -m PyInstaller --noconfirm --clean --windowed --onefile ^
  --name "DigiUpdater" ^
  --workpath "%UPDATER_BUILD_CACHE%" ^
  --distpath "%UPDATER_DIST_CACHE%" ^
  --specpath "%UPDATER_SPEC_CACHE%" ^
  "%FACTORY_DIR%updater\update_helper.py"
if errorlevel 1 (echo FATAL: DigiUpdater build failed.&pause&exit /b 1)
if not exist "%UPDATER_DIST_CACHE%\DigiUpdater.exe" (
    echo FATAL: DigiUpdater.exe was not produced.
    pause
    exit /b 1
)

echo Both builds passed. Staging executables before installation...
if not exist "%INSTALL_DIR%\." mkdir "%INSTALL_DIR%"
if errorlevel 1 (echo FATAL: Could not create "%INSTALL_DIR%".&pause&exit /b 1)
if not exist "%INSTALL_DIR%\Logs\." mkdir "%INSTALL_DIR%\Logs"
if errorlevel 1 (echo FATAL: Could not create the updater log folder.&pause&exit /b 1)

rem Create required user-data directories without deleting or replacing existing contents.
if not exist "%INSTALL_DIR%\Search Repository\." mkdir "%INSTALL_DIR%\Search Repository"
if errorlevel 1 (echo FATAL: Could not create Search Repository.&pause&exit /b 1)
if not exist "%INSTALL_DIR%\Search Repository\Digi Notes\." mkdir "%INSTALL_DIR%\Search Repository\Digi Notes"
if errorlevel 1 (echo FATAL: Could not create the Digi Notes folder.&pause&exit /b 1)
if not exist "%INSTALL_DIR%\Cache\." mkdir "%INSTALL_DIR%\Cache"
if errorlevel 1 (echo FATAL: Could not create Cache.&pause&exit /b 1)

set "STAGED_APP=%INSTALL_DIR%\.Digi Search Engine.exe.new"
set "STAGED_HELPER=%INSTALL_DIR%\.DigiUpdater.exe.new"
set "BUILD_BACKUP_ID=%APP_VERSION%-%RANDOM%-%RANDOM%"
set "BACKUP_APP=%INSTALL_DIR%\.Digi Search Engine.exe.build-backup-%BUILD_BACKUP_ID%"
set "BACKUP_HELPER=%INSTALL_DIR%\.DigiUpdater.exe.build-backup-%BUILD_BACKUP_ID%"
set "HAD_APP=0"
set "HAD_HELPER=0"

if exist "%BACKUP_APP%" (
    echo FATAL: Recovery file already exists: "%BACKUP_APP%"
    echo Inspect it before rebuilding; it will not be overwritten.
    pause
    exit /b 1
)
if exist "%BACKUP_HELPER%" (
    echo FATAL: Recovery file already exists: "%BACKUP_HELPER%"
    echo Inspect it before rebuilding; it will not be overwritten.
    pause
    exit /b 1
)

copy /y "%DIST_CACHE%\Digi Search Engine.exe" "%STAGED_APP%" >nul
if errorlevel 1 (echo FATAL: Could not stage the main executable. Installed files were not changed.&pause&exit /b 1)
copy /y "%UPDATER_DIST_CACHE%\DigiUpdater.exe" "%STAGED_HELPER%" >nul
if errorlevel 1 (
    del /q "%STAGED_APP%" 2>nul
    echo FATAL: Could not stage DigiUpdater.exe. Installed files were not changed.
    pause
    exit /b 1
)

rem Keep the old pair until both new files have been installed successfully.
if exist "%APP_TARGET%" (
    move /y "%APP_TARGET%" "%BACKUP_APP%" >nul
    if errorlevel 1 (
        del /q "%STAGED_APP%" "%STAGED_HELPER%" 2>nul
        echo FATAL: Could not preserve the previous application executable.
        pause
        exit /b 1
    )
    set "HAD_APP=1"
)
if exist "%HELPER_TARGET%" (
    move /y "%HELPER_TARGET%" "%BACKUP_HELPER%" >nul
    if errorlevel 1 (
        if "%HAD_APP%"=="1" move /y "%BACKUP_APP%" "%APP_TARGET%" >nul
        del /q "%STAGED_APP%" "%STAGED_HELPER%" 2>nul
        echo FATAL: Could not preserve the previous updater helper.
        pause
        exit /b 1
    )
    set "HAD_HELPER=1"
)

move /y "%STAGED_HELPER%" "%HELPER_TARGET%" >nul
if errorlevel 1 goto :rollback_install
move /y "%STAGED_APP%" "%APP_TARGET%" >nul
if errorlevel 1 goto :rollback_install

rem Both files are in place. Retain the previous pair as recovery copies.
echo Previous application/helper backups, if any, are retained with .build-backup suffixes.
goto :install_succeeded

:rollback_install
echo FATAL: New executables could not both be installed. Restoring the previous pair...
del /q "%APP_TARGET%" "%HELPER_TARGET%" 2>nul
if "%HAD_HELPER%"=="1" (
    move /y "%BACKUP_HELPER%" "%HELPER_TARGET%" >nul
    if errorlevel 1 echo CRITICAL: Could not restore the previous helper. Recovery copy: "%BACKUP_HELPER%"
)
if "%HAD_APP%"=="1" (
    move /y "%BACKUP_APP%" "%APP_TARGET%" >nul
    if errorlevel 1 echo CRITICAL: Could not restore the previous application. Recovery copy: "%BACKUP_APP%"
)
del /q "%STAGED_APP%" "%STAGED_HELPER%" 2>nul
echo Build installation failed. Check the messages above before retrying.
pause
exit /b 1

:install_succeeded
echo Refreshing Digi shortcuts across Desktop, Start menu, and known pinned-shortcut folders...
"%HELPER_TARGET%" --refresh-shortcuts
if errorlevel 1 (
    echo WARNING: Build installed, but one or more Digi shortcuts could not be refreshed.
    echo Run "%HELPER_TARGET%" --refresh-shortcuts after resolving the logged error.
) else (
    echo Digi shortcuts refreshed to the stable installed executable.
)

echo.
echo BUILD AND INSTALL COMPLETE.
echo Application: "%APP_TARGET%"
echo Update helper: "%HELPER_TARGET%"
echo Local updater log: "%INSTALL_DIR%\Logs\updater.log"
echo Existing Search Repository, Cache, notes, and other user data were not deleted.
pause
