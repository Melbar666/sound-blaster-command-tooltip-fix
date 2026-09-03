$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework

$Title = 'Sound Blaster Command - Tooltip Fix'
$TargetDir = 'C:\Program Files (x86)\Creative\Sound Blaster Command'
$Target = Join-Path $TargetDir 'Package\Hardcodet.Wpf.TaskbarNotification.dll'
$FallbackApp = Join-Path $TargetDir 'Creative.SBCommand.exe'
$Backup = $Target + '.sticky-tooltip-fix.original.bak'
$LegacyBackup = $Target + '.original-1.0.5.0.bak'
$Temp = $Target + '.sticky-tooltip-fix.tmp'

$ExpectedOriginalHash = '4A2438ECFCAD3E6E7BB942ACF2C40FBE2C0D72E4982DF303AB5828AF26CA753E'
$ExpectedPatchedHash  = '72CDC5A4A5841158915D6B8ED414758E39B6C5A9871274BB90B2F23EC7FA4117'
$PatchOffset = 0x13A8
$ExpectedOriginalByte = 0x02
$PatchedByte = 0x2A

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

function Remove-TempFile {
    if (Test-Path -LiteralPath $Temp) {
        Remove-Item -LiteralPath $Temp -Force -ErrorAction SilentlyContinue
    }
}

try {
    if (-not (Test-Path -LiteralPath $Target)) {
        Show-ErrorAndExit "Sound Blaster Command was not found at the expected location.`n`n$Target"
    }

    $targetHash = Get-Sha256 $Target

    if ($targetHash -eq $ExpectedPatchedHash) {
        if (Test-Path -LiteralPath $Backup) {
            $backupHash = Get-Sha256 $Backup
            if ($backupHash -ne $ExpectedOriginalHash) {
                Show-ErrorAndExit "The fix is installed, but the local backup is not the expected original file.`n`nNothing was changed."
            }
        } elseif ((Test-Path -LiteralPath $LegacyBackup) -and ((Get-Sha256 $LegacyBackup) -eq $ExpectedOriginalHash)) {
            Copy-Item -LiteralPath $LegacyBackup -Destination $Backup -ErrorAction Stop
            if ((Get-Sha256 $Backup) -ne $ExpectedOriginalHash) {
                Show-ErrorAndExit "The existing verified backup could not be migrated.`n`nNothing else was changed."
            }
        } else {
            Show-ErrorAndExit "The patched DLL is already installed, but no verified original backup was found.`n`nNothing was changed."
        }

        Show-Info "The tooltip fix is already installed and the original backup is verified.`n`nNo patching was necessary."
        exit 0
    }

    if ($targetHash -ne $ExpectedOriginalHash) {
        Show-ErrorAndExit "This Sound Blaster Command build is not supported by this version of the fix.`n`nNothing was changed.`n`nInstalled DLL SHA-256:`n$targetHash"
    }

    Stop-SoundBlasterCommand

    if (Test-Path -LiteralPath $Backup) {
        $backupHash = Get-Sha256 $Backup
        if ($backupHash -ne $ExpectedOriginalHash) {
            Restart-SoundBlasterCommand
            Show-ErrorAndExit "An existing backup file does not match the expected original DLL.`n`nNothing was changed."
        }
    } else {
        Copy-Item -LiteralPath $Target -Destination $Backup -ErrorAction Stop
        if ((Get-Sha256 $Backup) -ne $ExpectedOriginalHash) {
            Remove-Item -LiteralPath $Backup -Force -ErrorAction SilentlyContinue
            Restart-SoundBlasterCommand
            Show-ErrorAndExit "The original DLL backup could not be verified.`n`nNothing was changed."
        }
    }

    $bytes = [System.IO.File]::ReadAllBytes($Target)

    if ($bytes.Length -le $PatchOffset) {
        Restart-SoundBlasterCommand
        Show-ErrorAndExit "The verified DLL is unexpectedly shorter than the known supported build.`n`nNothing was changed."
    }

    if ($bytes[$PatchOffset] -ne $ExpectedOriginalByte) {
        Restart-SoundBlasterCommand
        Show-ErrorAndExit ("The byte at patch offset 0x{0:X} was not the expected value.`n`nNothing was changed." -f $PatchOffset)
    }

    $bytes[$PatchOffset] = $PatchedByte
    Remove-TempFile
    [System.IO.File]::WriteAllBytes($Temp, $bytes)

    if ((Get-Sha256 $Temp) -ne $ExpectedPatchedHash) {
        Remove-TempFile
        Restart-SoundBlasterCommand
        Show-ErrorAndExit "The locally constructed patch did not match the expected patched SHA-256.`n`nNothing was changed."
    }

    Copy-Item -LiteralPath $Temp -Destination $Target -Force -ErrorAction Stop
    Remove-TempFile

    if ((Get-Sha256 $Target) -ne $ExpectedPatchedHash) {
        Copy-Item -LiteralPath $Backup -Destination $Target -Force -ErrorAction SilentlyContinue
        Restart-SoundBlasterCommand
        Show-ErrorAndExit "Post-install verification failed.`n`nThe installer restored the original DLL."
    }

    Restart-SoundBlasterCommand

    Show-Info "Installed successfully.`n`nThe problematic Sound Blaster Command tray hover tooltip is now disabled.`n`nThe application, tray icon, menus, and settings remain available normally."
}
catch {
    Remove-TempFile

    try {
        if ((Test-Path -LiteralPath $Backup) -and (Test-Path -LiteralPath $Target)) {
            $currentHash = Get-Sha256 $Target
            if ($currentHash -ne $ExpectedOriginalHash -and $currentHash -ne $ExpectedPatchedHash) {
                if ((Get-Sha256 $Backup) -eq $ExpectedOriginalHash) {
                    Copy-Item -LiteralPath $Backup -Destination $Target -Force -ErrorAction SilentlyContinue
                }
            }
        }
    } catch {}

    try {
        Restart-SoundBlasterCommand
    } catch {}

    Show-ErrorAndExit ("Installation failed.`n`n" + $_.Exception.Message)
}
