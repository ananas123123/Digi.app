@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo Digi Word-to-PDF - EXE Builder
echo ==========================================
echo.

py -m pip install --upgrade pyinstaller
if errorlevel 1 goto :error

py -m pip install -r requirements.txt
if errorlevel 1 goto :error

if exist build rmdir /s /q build
if exist dist rmdir /s /q dist

py -m PyInstaller --noconfirm --clean --windowed --onedir --name "Digi Word to PDF" --collect-all pymupdf --collect-submodules win32com --hidden-import pythoncom --hidden-import pywintypes main.py
if errorlevel 1 goto :error

if not exist "dist\Digi Word to PDF\repository" mkdir "dist\Digi Word to PDF\repository"
if not exist "dist\Digi Word to PDF\repository\.gitkeep" type nul > "dist\Digi Word to PDF\repository\.gitkeep"

echo.
echo Build complete.
echo EXE: dist\Digi Word to PDF\Digi Word to PDF.exe
echo Put your files and folders inside the repository folder beside the EXE.
echo Folder structure will be preserved. Converted PDFs are created alongside each source.
echo Microsoft Word must be installed for Word conversion.
echo.
pause
exit /b 0

:error
echo.
echo BUILD FAILED. Read the error above.
pause
exit /b 1
