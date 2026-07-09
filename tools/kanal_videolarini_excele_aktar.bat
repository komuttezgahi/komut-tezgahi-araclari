@echo off
setlocal
chcp 65001 >nul

cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0kanal_videolarini_excele_aktar.ps1" %*

echo.
pause
