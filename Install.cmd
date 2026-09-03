@echo off
setlocal
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "SBC_TOOLTIP_FIX_SCRIPT=%~dp0install.ps1"

"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath $env:PS -Verb RunAs -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$env:SBC_TOOLTIP_FIX_SCRIPT)"

exit /b
