param(
    [string]$ResultFile
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework

$Title = 'Sound Blaster Command - Remove Tooltip Fix'
$TargetDir = 'C:\Program Files (x86)\Creative\Sound Blaster Command'
$Target = Join-Path $TargetDir 'Package\Hardcodet.Wpf.TaskbarNotification.dll'
$FallbackApp = Join-Path $TargetDir 'Creative.SBCommand.exe'
$Backup = $Target + '.sticky-tooltip-fix.original.bak'

# Compatibility with pre-public builds of this fix that used the earlier backup name.
$LegacyBackup = $Target + '.original-1.0.5.0.bak'

$ExpectedOriginalHash = '4A2438ECFCAD3E6E7BB942ACF2C40FBE2C0D72E4982DF303AB5828AF26CA753E'
$ExpectedPatchedHash  = '72CDC5A4A5841158915D6B8ED414758E39B6C5A9871274BB90B2F23EC7FA4117'
$ShutdownGraceSeconds = 5
$NL = [Environment]::NewLine

$LogDir = Join-Path $env:TEMP 'SoundBlasterCommand-TooltipFix'
$LogPath = Join-Path $LogDir 'uninstall.log'
$DisplayLogPath = '%TEMP%\SoundBlasterCommand-TooltipFix\uninstall.log'

$script:WasRunning = $false
$script:RestartPath = $null

function Write-Log([string]$Message) {
    try {
        if (-not (Test-Path -LiteralPath $LogDir)) {
            New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction Stop | Out-Null
        }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        Add-Content -LiteralPath $LogPath -Value "$timestamp  $Message" -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Warning ("Diagnostic logging failed: " + $_.Exception.Message)
    }
}

function Complete-AndExit([int]$Code) {
    if ($ResultFile) {
        try {
            [System.IO.File]::WriteAllText(
                $ResultFile,
                [string]$Code,
                [System.Text.Encoding]::ASCII
            )
        }
        catch {
            Write-Warning ("Could not write launcher status file: " + $_.Exception.Message)
        }
    }

    exit $Code
}

function Show-Info([string]$Text) {
    [System.Windows.MessageBox]::Show($Text, $Title, 'OK', 'Information') | Out-Null
}

function Show-ErrorAndExit([string]$Text) {
    $flatText = $Text -replace "(\r\n|\n|\r)", ' | '
    Write-Log "ERROR: $flatText"

    $message = "$Text$NL$NL" + "Diagnostic log:$NL$DisplayLogPath"
    [System.Windows.MessageBox]::Show($message, $Title, 'OK', 'Error') | Out-Null
    Complete-AndExit 1
}

function Get-Sha256([string]$Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hashBytes = $sha.ComputeHash($stream)
        }
        finally {
            $sha.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }

    ([System.BitConverter]::ToString($hashBytes)).Replace('-', '')
}

function Stop-SoundBlasterCommand {
    $processes = @(Get-Process -Name 'Creative.SBCommand' -ErrorAction SilentlyContinue)
    if ($processes.Count -eq 0) {
        Write-Log 'Sound Blaster Command is not running.'
        return
    }

    $script:WasRunning = $true
    Write-Log ("Stopping Sound Blaster Command. Process count: {0}" -f $processes.Count)

    foreach ($process in $processes) {
        if (-not $script:RestartPath) {
            try {
                if ($process.Path -and (Test-Path -LiteralPath $process.Path)) {
                    $script:RestartPath = $process.Path
                    Write-Log 'Captured Sound Blaster Command restart path.'
                }
            }
            catch {
                Write-Log ("Could not read process path for PID {0}: {1}" -f $process.Id, $_.Exception.Message)
            }
        }

        try {
            $closeRequested = [bool]$process.CloseMainWindow()
            Write-Log ("Graceful close requested for PID {0}. CloseMainWindow={1}" -f $process.Id, $closeRequested)
        }
        catch {
            Write-Log ("Graceful close request failed for PID {0}: {1}" -f $process.Id, $_.Exception.Message)
        }
    }

    $deadline = [DateTime]::UtcNow.AddSeconds($ShutdownGraceSeconds)

    do {
        $remaining = @(Get-Process -Name 'Creative.SBCommand' -ErrorAction SilentlyContinue)
        if ($remaining.Count -eq 0) {
            Write-Log 'Sound Blaster Command exited gracefully.'
            return
        }

        Start-Sleep -Milliseconds 250
    }
    while ([DateTime]::UtcNow -lt $deadline)

    $remaining = @(Get-Process -Name 'Creative.SBCommand' -ErrorAction SilentlyContinue)
    if ($remaining.Count -gt 0) {
        $pids = ($remaining | ForEach-Object { $_.Id }) -join ','
        Write-Log ("Graceful shutdown timed out after {0} seconds. Force-stopping PID(s): {1}" -f $ShutdownGraceSeconds, $pids)

        $remaining | Stop-Process -Force -ErrorAction Stop
        Start-Sleep -Milliseconds 500
    }

    if (@(Get-Process -Name 'Creative.SBCommand' -ErrorAction SilentlyContinue).Count -gt 0) {
        throw 'Sound Blaster Command could not be stopped.'
    }

    Write-Log 'Sound Blaster Command stopped.'
}

function Restart-SoundBlasterCommand {
    if (-not $script:WasRunning) {
        Write-Log 'No application restart is required.'
        return $true
    }

    $path = $script:RestartPath
    if (-not $path -or -not (Test-Path -LiteralPath $path)) {
        if (Test-Path -LiteralPath $FallbackApp) {
            $path = $FallbackApp
            Write-Log 'Using the known Sound Blaster Command executable as restart fallback.'
        }
    }

    if (-not $path -or -not (Test-Path -LiteralPath $path)) {
        Write-Log 'WARNING: Sound Blaster Command could not be restarted because no executable path was found.'
        return $false
    }

    try {
        Start-Process -FilePath $path -ErrorAction Stop | Out-Null
        Write-Log 'Sound Blaster Command restarted.'
        return $true
    }
    catch {
        Write-Log ("WARNING: Sound Blaster Command restart failed: " + $_.Exception.Message)
        return $false
    }
}

Write-Log '=== Uninstall started ==='

try {
    if (-not (Test-Path -LiteralPath $Target)) {
        Show-ErrorAndExit 'Sound Blaster Command was not found at the expected location.'
    }

    $targetHash = Get-Sha256 $Target
    Write-Log ("Target SHA-256: {0}" -f $targetHash)

    if ($targetHash -eq $ExpectedOriginalHash) {
        Write-Log 'Result: original DLL already active.'
        Show-Info ("The original DLL is already active.$NL$NL" + 'There is nothing to uninstall.')
        Complete-AndExit 0
    }

    if ($targetHash -ne $ExpectedPatchedHash) {
        Show-ErrorAndExit ("The installed DLL matches neither the supported original nor this fix.$NL$NL" + "Nothing was changed.$NL$NL" + "Installed SHA-256:$NL$targetHash")
    }

    Write-Log 'Patched DLL hash verified.'

    $backupToUse = $null
    if (Test-Path -LiteralPath $Backup) {
        $backupToUse = $Backup
        Write-Log 'Using current backup filename.'
    }
    elseif (Test-Path -LiteralPath $LegacyBackup) {
        $backupToUse = $LegacyBackup
        Write-Log 'Using verified legacy backup filename.'
    }

    if (-not $backupToUse) {
        Show-ErrorAndExit ("The verified original backup is missing.$NL$NL" + 'Nothing was changed.')
    }

    $backupHash = Get-Sha256 $backupToUse
    Write-Log ("Backup SHA-256: {0}" -f $backupHash)

    if ($backupHash -ne $ExpectedOriginalHash) {
        Show-ErrorAndExit ("The local backup is not the expected original DLL.$NL$NL" + 'Nothing was changed.')
    }

    Write-Log 'Original backup hash verified.'
    Stop-SoundBlasterCommand

    Copy-Item -LiteralPath $backupToUse -Destination $Target -Force -ErrorAction Stop
    Write-Log 'Original DLL restored from verified backup.'

    $restoredHash = Get-Sha256 $Target
    Write-Log ("Restored SHA-256: {0}" -f $restoredHash)

    if ($restoredHash -ne $ExpectedOriginalHash) {
        [void](Restart-SoundBlasterCommand)
        Show-ErrorAndExit 'Rollback verification failed. The backup was not deleted.'
    }

    Write-Log 'Restored original DLL hash verified.'

    foreach ($candidate in @($Backup, $LegacyBackup)) {
        if (Test-Path -LiteralPath $candidate) {
            try {
                if ((Get-Sha256 $candidate) -eq $ExpectedOriginalHash) {
                    Remove-Item -LiteralPath $candidate -Force -ErrorAction Stop
                    Write-Log 'Removed verified local backup after successful restore.'
                }
                else {
                    Write-Log 'WARNING: A backup-named file was retained because its hash is not the expected original hash.'
                }
            }
            catch {
                Write-Log ("WARNING: Could not remove verified backup after successful restore: " + $_.Exception.Message)
            }
        }
    }

    $restartOk = Restart-SoundBlasterCommand

    if ($restartOk) {
        Write-Log 'Result: SUCCESS.'
        Show-Info ("Removed successfully.$NL$NL" + 'The original Sound Blaster Command DLL has been restored.')
    }
    else {
        Write-Log 'Result: SUCCESS WITH RESTART WARNING.'
        Show-Info ("Removed successfully.$NL$NL" + "The original DLL is restored, but Sound Blaster Command could not be restarted automatically. Start it manually.$NL$NL" + "Diagnostic log:$NL$DisplayLogPath")
    }

    Complete-AndExit 0
}
catch {
    $failureMessage = $_.Exception.Message
    Write-Log ("Unhandled uninstall exception: " + $failureMessage)
    [void](Restart-SoundBlasterCommand)
    Show-ErrorAndExit ("Uninstall failed.$NL$NL" + $failureMessage)
}
