@echo off
setlocal
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "SBC_TOOLTIP_FIX_SCRIPT=%~dp0verify.ps1"

"%PS%" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%SBC_TOOLTIP_FIX_SCRIPT%"

exit /b
