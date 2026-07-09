@echo off
setlocal
chcp 65001 >nul

cd /d "%~dp0"

echo Windows zaman dilimi ID listesi aliniyor...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0zaman_dilimlerini_listele.ps1"

echo.
pause
