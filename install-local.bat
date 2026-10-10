@echo off
setlocal EnableExtensions
echo Digi now builds and installs directly into %%LOCALAPPDATA%%\Digi.
echo This script delegates to build.bat and does not use Programs\Digi.
call "%~dp0build.bat"
exit /b %errorlevel%
