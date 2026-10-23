@echo off
cd /d "%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0package-personal-bundle.ps1" %*
if errorlevel 1 exit /b %errorlevel%

