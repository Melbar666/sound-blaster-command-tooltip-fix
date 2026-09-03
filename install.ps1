param(
    [string]$ResultFile
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework

$Title = 'Sound Blaster Command - Tooltip Fix'
$TargetDir = 'C:\Program Files (x86)\Creative\Sound Blaster Command'
$Target = Join-Path $TargetDir 'Package\Hardcodet.Wpf.TaskbarNotification.dll'
$FallbackApp = Join-Path $TargetDir 'Creative.SBCommand.exe'
$Backup = $Target + '.sticky-tooltip-fix.original.bak'

# Compatibility with pre-public builds of this fix that used the earlier backup name.
$LegacyBackup = $Target + '.original-1.0.5.0.bak'

$Temp = $Target + '.sticky-tooltip-fix.tmp'
$ExpectedOriginalHash = '4A2438ECFCAD3E6E7BB942ACF2C40FBE2C0D72E4982DF303AB5828AF26CA753E'
$ExpectedPatchedHash  = '72CDC5A4A5841158915D6B8ED414758E39B6C5A9871274BB90B2F23EC7FA4117'
$PatchOffset = 0x13A8
$ExpectedOriginalByte = 0x02
$PatchedByte = 0x2A
$ShutdownGraceSeconds = 5
$NL = [Environment]::NewLine

$LogDir = Join-Path $env:TEMP 'SoundBlasterCommand-TooltipFix'
$LogPath = Join-Path $LogDir 'install.log'
$DisplayLogPath = '%TEMP%\SoundBlasterCommand-TooltipFix\install.log'

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

    $stillRunning = @(Get-Process -Name 'Creative.SBCommand' -ErrorAction SilentlyContinue)
    if ($stillRunning.Count -gt 0) {
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

function Remove-TempFile {
    if (Test-Path -LiteralPath $Temp) {
        try {
            Remove-Item -LiteralPath $Temp -Force -ErrorAction Stop
            Write-Log 'Removed temporary patch file.'
        }
        catch {
            Write-Log ("WARNING: Could not remove temporary patch file: " + $_.Exception.Message)
        }
    }
}

Write-Log '=== Install started ==='

try {
    if (-not (Test-Path -LiteralPath $Target)) {
        Show-ErrorAndExit ("Sound Blaster Command was not found at the expected location.$NL$NL$Target")
    }

    Write-Log 'Target DLL found.'
    $targetHash = Get-Sha256 $Target
    Write-Log ("Target SHA-256: {0}" -f $targetHash)

    if ($targetHash -eq $ExpectedPatchedHash) {
        if (Test-Path -LiteralPath $Backup) {
            $backupHash = Get-Sha256 $Backup
            Write-Log ("Existing backup SHA-256: {0}" -f $backupHash)

            if ($backupHash -ne $ExpectedOriginalHash) {
                Show-ErrorAndExit ("The fix is installed, but the local backup is not the expected original file.$NL$NL" + 'Nothing was changed.')
            }
        }
        elseif ((Test-Path -LiteralPath $LegacyBackup) -and ((Get-Sha256 $LegacyBackup) -eq $ExpectedOriginalHash)) {
            Write-Log 'Verified legacy backup found. Migrating it to the current backup name.'
            Copy-Item -LiteralPath $LegacyBackup -Destination $Backup -ErrorAction Stop

            if ((Get-Sha256 $Backup) -ne $ExpectedOriginalHash) {
                Show-ErrorAndExit ("The existing verified backup could not be migrated.$NL$NL" + 'Nothing else was changed.')
            }

            Write-Log 'Legacy backup migration verified.'
        }
        else {
            Show-ErrorAndExit ("The patched DLL is already installed, but no verified original backup was found.$NL$NL" + 'Nothing was changed.')
        }

        Write-Log 'Result: already installed and verified.'
        Show-Info ("The tooltip fix is already installed and the original backup is verified.$NL$NL" + 'No patching was necessary.')
        Complete-AndExit 0
    }

    if ($targetHash -ne $ExpectedOriginalHash) {
        Show-ErrorAndExit ("This Sound Blaster Command build is not supported by this version of the fix.$NL$NL" + "Nothing was changed.$NL$NL" + "Installed DLL SHA-256:$NL$targetHash")
    }

    Write-Log 'Original DLL hash verified.'
    Stop-SoundBlasterCommand

    if (Test-Path -LiteralPath $Backup) {
        $backupHash = Get-Sha256 $Backup
        Write-Log ("Existing backup SHA-256: {0}" -f $backupHash)

        if ($backupHash -ne $ExpectedOriginalHash) {
            [void](Restart-SoundBlasterCommand)
            Show-ErrorAndExit ("An existing backup file does not match the expected original DLL.$NL$NL" + 'Nothing was changed.')
        }

        Write-Log 'Existing original backup verified.'
    }
    else {
        Copy-Item -LiteralPath $Target -Destination $Backup -ErrorAction Stop
        Write-Log 'Original backup created.'

        if ((Get-Sha256 $Backup) -ne $ExpectedOriginalHash) {
            Remove-Item -LiteralPath $Backup -Force -ErrorAction SilentlyContinue
            [void](Restart-SoundBlasterCommand)
            Show-ErrorAndExit ("The original DLL backup could not be verified.$NL$NL" + 'Nothing was changed.')
        }

        Write-Log 'Original backup hash verified.'
    }

    $bytes = [System.IO.File]::ReadAllBytes($Target)

    if ($bytes.Length -le $PatchOffset) {
        [void](Restart-SoundBlasterCommand)
        Show-ErrorAndExit ("The verified DLL is unexpectedly shorter than the known supported build.$NL$NL" + 'Nothing was changed.')
    }

    if ($bytes[$PatchOffset] -ne $ExpectedOriginalByte) {
        [void](Restart-SoundBlasterCommand)
        Show-ErrorAndExit (("The byte at patch offset 0x{0:X} was not the expected value." -f $PatchOffset) + "$NL$NL" + 'Nothing was changed.')
    }

    Write-Log ("Patch byte verified at offset 0x{0:X}." -f $PatchOffset)
    $bytes[$PatchOffset] = $PatchedByte

    Remove-TempFile
    [System.IO.File]::WriteAllBytes($Temp, $bytes)
    Write-Log 'Temporary patched DLL constructed.'

    $tempHash = Get-Sha256 $Temp
    Write-Log ("Temporary patched SHA-256: {0}" -f $tempHash)

    if ($tempHash -ne $ExpectedPatchedHash) {
        Remove-TempFile
        [void](Restart-SoundBlasterCommand)
        Show-ErrorAndExit ("The locally constructed patch did not match the expected patched SHA-256.$NL$NL" + 'Nothing was changed.')
    }

    Write-Log 'Temporary patched DLL hash verified.'
    Copy-Item -LiteralPath $Temp -Destination $Target -Force -ErrorAction Stop
    Remove-TempFile

    $installedHash = Get-Sha256 $Target
    Write-Log ("Installed SHA-256: {0}" -f $installedHash)

    if ($installedHash -ne $ExpectedPatchedHash) {
        Write-Log 'Post-install verification failed. Attempting automatic rollback.'

        try {
            Copy-Item -LiteralPath $Backup -Destination $Target -Force -ErrorAction Stop

            if ((Get-Sha256 $Target) -ne $ExpectedOriginalHash) {
                throw 'The restored DLL did not match the expected original SHA-256.'
            }

            Write-Log 'Automatic rollback verified.'
        }
        catch {
            Write-Log ("CRITICAL: Automatic rollback failed: " + $_.Exception.Message)
            [void](Restart-SoundBlasterCommand)
            Show-ErrorAndExit ("Post-install verification failed and the automatic rollback could not be verified.$NL$NL" + 'Do not delete the local backup. See the diagnostic log for details.')
        }

        [void](Restart-SoundBlasterCommand)
        Show-ErrorAndExit ("Post-install verification failed.$NL$NL" + 'The installer restored the original DLL.')
    }

    Write-Log 'Installed patched DLL hash verified.'
    $restartOk = Restart-SoundBlasterCommand

    if ($restartOk) {
        Write-Log 'Result: SUCCESS.'
        Show-Info ("Installed successfully.$NL$NL" + "The problematic Sound Blaster Command tray hover tooltip is now disabled.$NL$NL" + 'The application, tray icon, menus, and settings remain available normally.')
    }
    else {
        Write-Log 'Result: SUCCESS WITH RESTART WARNING.'
        Show-Info ("Installed successfully.$NL$NL" + "The tooltip fix is active, but Sound Blaster Command could not be restarted automatically. Start it manually.$NL$NL" + "Diagnostic log:$NL$DisplayLogPath")
    }

    Complete-AndExit 0
}
catch {
    $failureMessage = $_.Exception.Message
    Remove-TempFile
    Write-Log ("Unhandled installation exception: " + $failureMessage)

    try {
        if ((Test-Path -LiteralPath $Backup) -and (Test-Path -LiteralPath $Target)) {
            $currentHash = Get-Sha256 $Target

            if ($currentHash -ne $ExpectedOriginalHash -and $currentHash -ne $ExpectedPatchedHash) {
                if ((Get-Sha256 $Backup) -eq $ExpectedOriginalHash) {
                    Write-Log 'Unexpected target hash detected after failure. Attempting verified rollback.'
                    Copy-Item -LiteralPath $Backup -Destination $Target -Force -ErrorAction Stop

                    if ((Get-Sha256 $Target) -eq $ExpectedOriginalHash) {
                        Write-Log 'Failure rollback verified.'
                    }
                    else {
                        Write-Log 'CRITICAL: Failure rollback did not restore the expected original hash.'
                    }
                }
            }
        }
    }
    catch {
        Write-Log ("CRITICAL: Failure rollback raised an exception: " + $_.Exception.Message)
    }

    [void](Restart-SoundBlasterCommand)
    Show-ErrorAndExit ("Installation failed.$NL$NL" + $failureMessage)
}
