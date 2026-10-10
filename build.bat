@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo Checking for an installed Digi copy...
set "INSTALLED_DIGI_DIR=%LOCALAPPDATA%\Programs\Digi"
if exist "%INSTALLED_DIGI_DIR%\Digi Search Engine.exe" (
    echo.
    echo FATAL: Installed Digi executable found:
    echo "%INSTALLED_DIGI_DIR%\Digi Search Engine.exe"
    echo Build cancelled to avoid interfering with an installed copy.
    pause
    exit /b 1
)
if exist "%INSTALLED_DIGI_DIR%\DigiUpdater.exe" (
    echo.
    echo FATAL: Installed Digi updater helper found:
    echo "%INSTALLED_DIGI_DIR%\DigiUpdater.exe"
    echo Build cancelled to avoid interfering with an installed copy.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$keys=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'); $found=Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -and $_.DisplayName -like '*Digi*' } | Select-Object -First 1; if ($found) { Write-Output 'DIGI_FOUND'; Write-Output $found.DisplayName; exit 1 }; exit 0"
set "FACTORY_DIR=%~dp0"
set "OUTPUT_DIR=%~dp0.."
set "VERSION_FILE=%FACTORY_DIR%version.txt"
set "VERSION_INFO_FILE=%FACTORY_DIR%version_info.txt"
set "PYTHON_EXE=%FACTORY_DIR%.venv\Scripts\python.exe"

if not exist "%VERSION_FILE%" (echo FATAL: version.txt missing&pause&exit /b 1)
if not exist "%VERSION_INFO_FILE%" (echo FATAL: version_info.txt missing&pause&exit /b 1)
set /p APP_VERSION=<"%VERSION_FILE%"
if not defined APP_VERSION (echo FATAL: version.txt is empty&pause&exit /b 1)

if not exist "%PYTHON_EXE%" (
    echo FATAL: Project virtual environment not found: "%PYTHON_EXE%"
    echo Run setup.bat first so the build uses the project's dependencies.
    pause
    exit /b 1
)

echo Installing/checking build dependencies in the project virtual environment...
"%PYTHON_EXE%" -m pip install --disable-pip-version-check -r "%FACTORY_DIR%requirements.txt"
if errorlevel 1 (echo Package installation failed.&pause&exit /b 1)

set "FINAL_DIR=%OUTPUT_DIR%\Digi SE %APP_VERSION%"
set "BUILD_CACHE=%FACTORY_DIR%Cache\build\test-exe-%APP_VERSION%"
set "DIST_CACHE=%FACTORY_DIR%Cache\dist\test-exe-%APP_VERSION%"
set "SPEC_CACHE=%FACTORY_DIR%Cache\spec\test-exe-%APP_VERSION%"
set "EXE_PATH=%FINAL_DIR%\Digi Search Engine.exe"

if not exist "%FINAL_DIR%" mkdir "%FINAL_DIR%"
if not exist "%BUILD_CACHE%" mkdir "%BUILD_CACHE%"
if not exist "%DIST_CACHE%" mkdir "%DIST_CACHE%"
if not exist "%SPEC_CACHE%" mkdir "%SPEC_CACHE%"

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

echo Building Digi with application code bundled inside the executable...
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
if errorlevel 1 (echo BUILD FAILED. Existing output was not intentionally deleted.&pause&exit /b 1)

if not exist "%DIST_CACHE%\Digi Search Engine.exe" (
    echo FATAL: PyInstaller reported success but the executable is missing:
    echo "%DIST_CACHE%\Digi Search Engine.exe"
    pause
    exit /b 1
)

rem Ensure the destination directory exists immediately before copying.
if not exist "%FINAL_DIR%\." mkdir "%FINAL_DIR%"
if errorlevel 1 (
    echo FATAL: Could not create the output directory:
    echo "%FINAL_DIR%"
    pause
    exit /b 1
)

echo Copying main executable...
echo Source: "%DIST_CACHE%\Digi Search Engine.exe"
echo Target: "%FINAL_DIR%\"
copy /y "%DIST_CACHE%\Digi Search Engine.exe" "%FINAL_DIR%\"
if errorlevel 1 (
    echo FATAL: Could not copy the executable to the output folder.
    echo Confirm the source and destination paths shown above.
    pause
    exit /b 1
)

set "UPDATER_BUILD_CACHE=%FACTORY_DIR%Cache\build\updater-helper-%APP_VERSION%"
set "UPDATER_DIST_CACHE=%FACTORY_DIR%Cache\dist\updater-helper-%APP_VERSION%"
set "UPDATER_SPEC_CACHE=%FACTORY_DIR%Cache\spec\updater-helper-%APP_VERSION%"
if not exist "%UPDATER_BUILD_CACHE%" mkdir "%UPDATER_BUILD_CACHE%"
if not exist "%UPDATER_DIST_CACHE%" mkdir "%UPDATER_DIST_CACHE%"
if not exist "%UPDATER_SPEC_CACHE%" mkdir "%UPDATER_SPEC_CACHE%"

echo Building Digi's separate update helper...
"%PYTHON_EXE%" -m PyInstaller --noconfirm --clean --windowed --onefile ^
  --name "DigiUpdater" ^
  --workpath "%UPDATER_BUILD_CACHE%" ^
  --distpath "%UPDATER_DIST_CACHE%" ^
  --specpath "%UPDATER_SPEC_CACHE%" ^
  "%FACTORY_DIR%updater\update_helper.py"
if errorlevel 1 (echo FATAL: DigiUpdater build failed.&pause&exit /b 1)

if not exist "%UPDATER_DIST_CACHE%\DigiUpdater.exe" (
    echo FATAL: PyInstaller reported success but DigiUpdater.exe is missing.
    pause
    exit /b 1
)
copy /y "%UPDATER_DIST_CACHE%\DigiUpdater.exe" "%FINAL_DIR%\DigiUpdater.exe" >nul
if errorlevel 1 (echo FATAL: Could not copy DigiUpdater.exe to the output folder.&pause&exit /b 1)

echo.
echo BUILD COMPLETE: "%EXE_PATH%"
echo Separate updater helper: "%FINAL_DIR%\DigiUpdater.exe"
echo Build outputs are not installed automatically.
echo For a guarded first-time local install, run install-local.bat.
echo Persistent user data remains under %%LOCALAPPDATA%%\Digi.
pause
,'').Trim([char]34) } elseif ($_.InstallLocation) { Join-Path $_.InstallLocation 'Digi Search Engine.exe' } } | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1; if ($found) { Write-Output 'DIGI_FOUND'; Write-Output $found; exit 1 }; exit 0"
if errorlevel 1 (
    echo.
    echo FATAL: A registered Digi installation was found.
    echo Build cancelled to avoid interfering with an installed copy.
    pause
    exit /b 1
)

set "FACTORY_DIR=%~dp0"
set "OUTPUT_DIR=%~dp0.."
set "VERSION_FILE=%FACTORY_DIR%version.txt"
set "VERSION_INFO_FILE=%FACTORY_DIR%version_info.txt"
set "PYTHON_EXE=%FACTORY_DIR%.venv\Scripts\python.exe"

if not exist "%VERSION_FILE%" (echo FATAL: version.txt missing&pause&exit /b 1)
if not exist "%VERSION_INFO_FILE%" (echo FATAL: version_info.txt missing&pause&exit /b 1)
set /p APP_VERSION=<"%VERSION_FILE%"
if not defined APP_VERSION (echo FATAL: version.txt is empty&pause&exit /b 1)

if not exist "%PYTHON_EXE%" (
    echo FATAL: Project virtual environment not found: "%PYTHON_EXE%"
    echo Run setup.bat first so the build uses the project's dependencies.
    pause
    exit /b 1
)

echo Installing/checking build dependencies in the project virtual environment...
"%PYTHON_EXE%" -m pip install --disable-pip-version-check -r "%FACTORY_DIR%requirements.txt"
if errorlevel 1 (echo Package installation failed.&pause&exit /b 1)

set "FINAL_DIR=%OUTPUT_DIR%\Digi SE %APP_VERSION%"
set "BUILD_CACHE=%FACTORY_DIR%Cache\build\test-exe-%APP_VERSION%"
set "DIST_CACHE=%FACTORY_DIR%Cache\dist\test-exe-%APP_VERSION%"
set "SPEC_CACHE=%FACTORY_DIR%Cache\spec\test-exe-%APP_VERSION%"
set "EXE_PATH=%FINAL_DIR%\Digi Search Engine.exe"

if not exist "%FINAL_DIR%" mkdir "%FINAL_DIR%"
if not exist "%BUILD_CACHE%" mkdir "%BUILD_CACHE%"
if not exist "%DIST_CACHE%" mkdir "%DIST_CACHE%"
if not exist "%SPEC_CACHE%" mkdir "%SPEC_CACHE%"

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

echo Building Digi with application code bundled inside the executable...
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
if errorlevel 1 (echo BUILD FAILED. Existing output was not intentionally deleted.&pause&exit /b 1)

if not exist "%DIST_CACHE%\Digi Search Engine.exe" (
    echo FATAL: PyInstaller reported success but the executable is missing:
    echo "%DIST_CACHE%\Digi Search Engine.exe"
    pause
    exit /b 1
)

rem Ensure the destination directory exists immediately before copying.
if not exist "%FINAL_DIR%\." mkdir "%FINAL_DIR%"
if errorlevel 1 (
    echo FATAL: Could not create the output directory:
    echo "%FINAL_DIR%"
    pause
    exit /b 1
)

echo Copying main executable...
echo Source: "%DIST_CACHE%\Digi Search Engine.exe"
echo Target: "%FINAL_DIR%\"
copy /y "%DIST_CACHE%\Digi Search Engine.exe" "%FINAL_DIR%\"
if errorlevel 1 (
    echo FATAL: Could not copy the executable to the output folder.
    echo Confirm the source and destination paths shown above.
    pause
    exit /b 1
)

set "UPDATER_BUILD_CACHE=%FACTORY_DIR%Cache\build\updater-helper-%APP_VERSION%"
set "UPDATER_DIST_CACHE=%FACTORY_DIR%Cache\dist\updater-helper-%APP_VERSION%"
set "UPDATER_SPEC_CACHE=%FACTORY_DIR%Cache\spec\updater-helper-%APP_VERSION%"
if not exist "%UPDATER_BUILD_CACHE%" mkdir "%UPDATER_BUILD_CACHE%"
if not exist "%UPDATER_DIST_CACHE%" mkdir "%UPDATER_DIST_CACHE%"
if not exist "%UPDATER_SPEC_CACHE%" mkdir "%UPDATER_SPEC_CACHE%"

echo Building Digi's separate update helper...
"%PYTHON_EXE%" -m PyInstaller --noconfirm --clean --windowed --onefile ^
  --name "DigiUpdater" ^
  --workpath "%UPDATER_BUILD_CACHE%" ^
  --distpath "%UPDATER_DIST_CACHE%" ^
  --specpath "%UPDATER_SPEC_CACHE%" ^
  "%FACTORY_DIR%updater\update_helper.py"
if errorlevel 1 (echo FATAL: DigiUpdater build failed.&pause&exit /b 1)

if not exist "%UPDATER_DIST_CACHE%\DigiUpdater.exe" (
    echo FATAL: PyInstaller reported success but DigiUpdater.exe is missing.
    pause
    exit /b 1
)
copy /y "%UPDATER_DIST_CACHE%\DigiUpdater.exe" "%FINAL_DIR%\DigiUpdater.exe" >nul
if errorlevel 1 (echo FATAL: Could not copy DigiUpdater.exe to the output folder.&pause&exit /b 1)

echo.
echo BUILD COMPLETE: "%EXE_PATH%"
echo Separate updater helper: "%FINAL_DIR%\DigiUpdater.exe"
echo Build outputs are not installed automatically.
echo For a guarded first-time local install, run install-local.bat.
echo Persistent user data remains under %%LOCALAPPDATA%%\Digi.
pause
