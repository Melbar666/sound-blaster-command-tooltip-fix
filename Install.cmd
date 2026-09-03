@echo off
setlocal
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "SBC_TOOLTIP_FIX_SCRIPT=%~dp0install.ps1"

"%PS%" -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; $status = Join-Path $env:TEMP ('SBC-TooltipFix-' + [Guid]::NewGuid().ToString('N') + '.status'); try { $childArgs = '-NoProfile -ExecutionPolicy Bypass -File "' + $env:SBC_TOOLTIP_FIX_SCRIPT + '" -ResultFile "' + $status + '"'; Start-Process -FilePath $env:PS -Verb RunAs -Wait -ArgumentList $childArgs; if (-not (Test-Path -LiteralPath $status)) { throw 'Elevated installer did not return a status code.' }; $raw = (Get-Content -LiteralPath $status -Raw).Trim(); $code = 0; if (-not [int]::TryParse($raw,[ref]$code)) { throw ('Invalid installer status: ' + $raw) }; exit $code } catch { Write-Error $_; exit 1 } finally { Remove-Item -LiteralPath $status -Force -ErrorAction SilentlyContinue }"

exit /b %ERRORLEVEL%
