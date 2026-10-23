@echo off
cd /d "%~dp0"
node scripts\install-skill.mjs
if errorlevel 1 pause
