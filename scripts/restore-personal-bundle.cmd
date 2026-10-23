@echo off
cd /d "%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore-personal-bundle.ps1" %*
if errorlevel 1 exit /b %errorlevel%

