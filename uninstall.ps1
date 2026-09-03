$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework

$Title = 'Sound Blaster Command - Remove Tooltip Fix'
$TargetDir = 'C:\Program Files (x86)\Creative\Sound Blaster Command'
$Target = Join-Path $TargetDir 'Package\Hardcodet.Wpf.TaskbarNotification.dll'
$FallbackApp = Join-Path $TargetDir 'Creative.SBCommand.exe'
$Backup = $Target + '.sticky-tooltip-fix.original.bak'
$LegacyBackup = $Target + '.original-1.0.5.0.bak'

$ExpectedOriginalHash = '4A2438ECFCAD3E6E7BB942ACF2C40FBE2C0D72E4982DF303AB5828AF26CA753E'
$ExpectedPatchedHash  = '72CDC5A4A5841158915D6B8ED414758E39B6C5A9871274BB90B2F23EC7FA4117'

$script:WasRunning = $false
$script:RestartPath = $null

function Show-Info([string]$Text) {
    [System.Windows.MessageBox]::Show($Text, $Title, 'OK', 'Information') | Out-Null
}

function Show-ErrorAndExit([string]$Text) {
    [System.Windows.MessageBox]::Show($Text, $Title, 'OK', 'Error') | Out-Null
    exit 1
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Stop-SoundBlasterCommand {
    $processes = @(Get-Process -Name 'Creative.SBCommand' -ErrorAction SilentlyContinue)
    if ($processes.Count -eq 0) {
        return
    }

    $script:WasRunning = $true

    foreach ($process in $processes) {
        if (-not $script:RestartPath) {
            try {
                if ($process.Path -and (Test-Path -LiteralPath $process.Path)) {
                    $script:RestartPath = $process.Path
                }
            } catch {}
        }

        try {
            [void]$process.CloseMainWindow()
        } catch {}
    }

    Start-Sleep -Milliseconds 800

    $remaining = @(Get-Process -Name 'Creative.SBCommand' -ErrorAction SilentlyContinue)
    if ($remaining.Count -gt 0) {
        $remaining | Stop-Process -Force -ErrorAction Stop
        Start-Sleep -Milliseconds 400
    }
}

function Restart-SoundBlasterCommand {
    if (-not $script:WasRunning) {
        return
    }

    $path = $script:RestartPath
    if (-not $path -or -not (Test-Path -LiteralPath $path)) {
        if (Test-Path -LiteralPath $FallbackApp) {
            $path = $FallbackApp
        }
    }

    if ($path -and (Test-Path -LiteralPath $path)) {
        Start-Process -FilePath $path | Out-Null
    }
}

try {
    if (-not (Test-Path -LiteralPath $Target)) {
        Show-ErrorAndExit "Sound Blaster Command was not found at the expected location."
    }

    $targetHash = Get-Sha256 $Target

    if ($targetHash -eq $ExpectedOriginalHash) {
        Show-Info "The original DLL is already active.`n`nThere is nothing to uninstall."
        exit 0
    }

    if ($targetHash -ne $ExpectedPatchedHash) {
        Show-ErrorAndExit "The installed DLL matches neither the supported original nor this fix.`n`nNothing was changed.`n`nInstalled SHA-256:`n$targetHash"
    }

    $backupToUse = $null
    if (Test-Path -LiteralPath $Backup) {
        $backupToUse = $Backup
    } elseif (Test-Path -LiteralPath $LegacyBackup) {
        $backupToUse = $LegacyBackup
    }

    if (-not $backupToUse) {
        Show-ErrorAndExit "The verified original backup is missing.`n`nNothing was changed."
    }

    if ((Get-Sha256 $backupToUse) -ne $ExpectedOriginalHash) {
        Show-ErrorAndExit "The local backup is not the expected original DLL.`n`nNothing was changed."
    }

    Stop-SoundBlasterCommand
    Copy-Item -LiteralPath $backupToUse -Destination $Target -Force -ErrorAction Stop

    if ((Get-Sha256 $Target) -ne $ExpectedOriginalHash) {
        Restart-SoundBlasterCommand
        Show-ErrorAndExit "Rollback verification failed."
    }

    foreach ($candidate in @($Backup, $LegacyBackup)) {
        if ((Test-Path -LiteralPath $candidate) -and ((Get-Sha256 $candidate) -eq $ExpectedOriginalHash)) {
            Remove-Item -LiteralPath $candidate -Force -ErrorAction SilentlyContinue
        }
    }

    Restart-SoundBlasterCommand

    Show-Info "Removed successfully.`n`nThe original Sound Blaster Command DLL has been restored."
}
catch {
    try {
        Restart-SoundBlasterCommand
    } catch {}

    Show-ErrorAndExit ("Uninstall failed.`n`n" + $_.Exception.Message)
}
